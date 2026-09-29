/*
 * astral-pins - per-pin 12V-2x6 current monitor for the ASUS ROG Astral.
 *
 * The Astral carries an ITE IT8915FN that shunt-measures each of the six 12V
 * pins on the 12V-2x6 connector. It sits at 0x2b on one of the GPU's I2C
 * adapters; register 0x80 holds 24 bytes, four per pin, big-endian:
 *
 *     [mV hi][mV lo][mA hi][mA lo]   x6, highest pin first
 *
 * All 24 bytes are fetched in ONE I2C block transaction. That matters: reading
 * them a byte at a time (24 separate SMBus transactions) takes ~35 ms and the
 * GPU's I2C engine stalls the graphics pipeline while it works, which showed up
 * as periodic frame spikes in games. One block read takes ~4.5 ms.
 *
 * Given -o /dev/shm/astral-pins it writes one file per pin plus a summary:
 *
 *   /dev/shm/astral-pins        8.12 8.03 7.94 8.20 8.31 7.85  =48.4A
 *   /dev/shm/astral-pins.pin1   8.12
 *   ...
 *   /dev/shm/astral-pins.pin6   7.85 !!        <- this pin is over the limit
 *
 * One file per pin because MangoHud renders only the LAST line an `exec`
 * command prints, so a row can only ever carry one file's worth of text.
 *
 * /dev/shm rather than /run: Steam runs games inside a pressure-vessel
 * container with its own /run, so files written to /run are invisible to every
 * Steam game. /dev/shm is passed through and is still tmpfs.
 *
 * Pins are numbered 1-6 everywhere, matching how the connector is labelled.
 *
 * Over the warning level it runs --alarm-command, repeating every
 * --alarm-repeat seconds, and once more when the condition clears. It does NOT
 * power the machine off.
 *
 *   astral-pins --status              one reading to stdout, then exit
 *   astral-pins --probe               show every NVIDIA bus and what it answers
 *   astral-pins --daemon -o FILE      loop, writing FILE (this is the service)
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <time.h>
#include <sys/ioctl.h>
#include <linux/i2c.h>
#include <linux/i2c-dev.h>

#define CHIP_ADDR   0x2b
#define DATA_REG    0x80
#define NUM_PINS    6
#define BLOCK_LEN   (NUM_PINS * 4)

/* A pin reading is only believable if the rail sits in this window. */
#define VOLT_MIN    10.5
#define VOLT_MAX    13.5

/* How far the peak has to fall below the warning level before the alarm
   clears, so a pin sitting exactly on the line does not chatter. */
#define ALARM_HYSTERESIS 0.5

static int    opt_bus          = -1;      /* -1 = autodetect */
static double opt_interval     = 1.0;
static double opt_warn         = 9.0;
static const char *opt_out     = NULL;
static const char *opt_alarm   = NULL;
static double opt_alarm_repeat = 30.0;

struct pin { double volts, amps; };

/* ---------------------------------------------------------------- i2c ---- */

/* One I2C_SMBUS_I2C_BLOCK_DATA transaction: write the register, read n bytes.
   Cannot use I2C_RDWR here - the NVIDIA adapter ACKs a combined transfer but
   hands back garbage. It does implement the SMBus block read correctly. */
static int read_block(int fd, uint8_t reg, uint8_t *out, int n)
{
    union i2c_smbus_data data;
    struct i2c_smbus_ioctl_data args;
    int off = 0;

    while (off < n) {
        int want = n - off;
        if (want > I2C_SMBUS_BLOCK_MAX)
            want = I2C_SMBUS_BLOCK_MAX;

        data.block[0] = (uint8_t)want;
        args.read_write = I2C_SMBUS_READ;
        args.command    = (uint8_t)(reg + off);
        args.size       = I2C_SMBUS_I2C_BLOCK_DATA;
        args.data       = &data;

        if (ioctl(fd, I2C_SMBUS, &args) < 0)
            return -1;
        if (data.block[0] == 0) {
            errno = EIO;
            return -1;
        }
        int got = data.block[0] > want ? want : data.block[0];
        memcpy(out + off, &data.block[1], (size_t)got);
        off += got;
    }
    return 0;
}

static void decode(const uint8_t *raw, struct pin *pins)
{
    /* The chip reports the highest pin first, so walk it backwards. */
    for (int i = 0; i < NUM_PINS; i++) {
        const uint8_t *p = raw + i * 4;
        pins[(NUM_PINS - 1) - i].volts = ((p[0] << 8) | p[1]) / 1000.0;
        pins[(NUM_PINS - 1) - i].amps  = ((p[2] << 8) | p[3]) / 1000.0;
    }
}

static int looks_like_12v(const struct pin *pins)
{
    for (int i = 0; i < NUM_PINS; i++)
        if (pins[i].volts >= VOLT_MIN && pins[i].volts <= VOLT_MAX)
            return 1;
    return 0;
}

static int sample(int fd, struct pin *pins)
{
    uint8_t raw[BLOCK_LEN];
    if (read_block(fd, DATA_REG, raw, BLOCK_LEN) < 0)
        return -1;
    decode(raw, pins);
    return 0;
}

/* --------------------------------------------------------------- bus ----- */

static int is_nvidia_bus(int bus)
{
    char path[128], name[128];
    snprintf(path, sizeof path, "/sys/bus/i2c/devices/i2c-%d/name", bus);
    FILE *f = fopen(path, "r");
    if (!f)
        return 0;
    int ok = fgets(name, sizeof name, f) && strstr(name, "NVIDIA");
    fclose(f);
    return ok;
}

static int open_bus(int bus)
{
    char path[64];
    snprintf(path, sizeof path, "/dev/i2c-%d", bus);
    int fd = open(path, O_RDWR | O_CLOEXEC);
    if (fd < 0)
        return -1;
    if (ioctl(fd, I2C_SLAVE_FORCE, CHIP_ADDR) < 0) {
        close(fd);
        return -1;
    }
    return fd;
}

/* Try every NVIDIA adapter; keep the first that decodes as a live 12V rail. */
static int find_chip(int *bus_out)
{
    struct pin pins[NUM_PINS];

    for (int bus = 0; bus < 64; bus++) {
        if (!is_nvidia_bus(bus))
            continue;
        int fd = open_bus(bus);
        if (fd < 0)
            continue;
        if (sample(fd, pins) == 0 && looks_like_12v(pins)) {
            *bus_out = bus;
            return fd;
        }
        close(fd);
    }
    return -1;
}

/* -------------------------------------------------------------- output --- */

static double peak_amps(const struct pin *pins, int *which)
{
    double peak = 0;
    int idx = 0;
    for (int i = 0; i < NUM_PINS; i++)
        if (pins[i].amps > peak) { peak = pins[i].amps; idx = i; }
    if (which)
        *which = idx;
    return peak;
}

/* Full line for scripts and --status. */
static void format_summary(const struct pin *pins, char *buf, size_t len)
{
    double total = 0;
    char body[160];
    int n = 0;

    for (int i = 0; i < NUM_PINS; i++) {
        total += pins[i].amps;
        n += snprintf(body + n, sizeof body - (size_t)n, "%s%.2f",
                      i ? " " : "", pins[i].amps);
    }
    snprintf(buf, len, "%s%s  =%.1fA",
             peak_amps(pins, NULL) >= opt_warn ? "!! " : "", body, total);
}

/* One overlay row: just this pin, with the marker on the pin that is over. */
static void format_pin(const struct pin *pins, int i, char *buf, size_t len)
{
    snprintf(buf, len, "%.2f%s", pins[i].amps,
             pins[i].amps >= opt_warn ? " !!" : "");
}

static void write_one(const char *path, const char *line)
{
    char tmp[600];
    snprintf(tmp, sizeof tmp, "%s.new", path);

    int fd = open(tmp, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
    if (fd < 0)
        return;
    dprintf(fd, "%s\n", line);
    close(fd);
    /* rename so a reader never sees a half-written line */
    if (rename(tmp, path) != 0)
        unlink(tmp);
}

static void write_status(const char *base, const struct pin *pins)
{
    char line[256], path[512];

    format_summary(pins, line, sizeof line);
    write_one(base, line);

    for (int i = 0; i < NUM_PINS; i++) {
        format_pin(pins, i, line, sizeof line);
        snprintf(path, sizeof path, "%s.pin%d", base, i + 1);
        write_one(path, line);
    }
}

static void print_detail(const struct pin *pins)
{
    double total = 0;
    for (int i = 0; i < NUM_PINS; i++) {
        printf("  pin %d   %6.3f V   %6.3f A%s\n", i + 1, pins[i].volts,
               pins[i].amps, pins[i].amps >= opt_warn ? "   <-- OVER" : "");
        total += pins[i].amps;
    }
    printf("  total          %6.3f A   (%.0f W)\n", total, total * 12.0);
}

/* --------------------------------------------------------------- alarm --- */

/* Run the alarm command detached. The command gets the state, pin and current
   two ways, because either can be the awkward one to use:

     as arguments   $1 = on|off   $2 = pin (1-6)   $3 = amps
     as environment ASTRAL_STATE  ASTRAL_PIN       ASTRAL_AMPS

   The command string is run as `sh -c '<cmd> "$@"' ...`, NOT as `sh -c '<cmd>'`.
   Without the explicit "$@" a plain command like /usr/local/bin/astral-pins-alarm
   silently receives no arguments at all, and the alarm reports its pin as "?".

   Never waits - SIGCHLD is ignored, so children are reaped by init. */
static void run_alarm(const char *state, int pin, double amps)
{
    if (!opt_alarm)
        return;

    char pinbuf[16], ampbuf[32], cmd[1024];
    snprintf(pinbuf, sizeof pinbuf, "%d", pin + 1);
    snprintf(ampbuf, sizeof ampbuf, "%.2f", amps);
    snprintf(cmd, sizeof cmd, "%s \"$@\"", opt_alarm);

    pid_t p = fork();
    if (p != 0)
        return;                      /* parent (or fork failed) carries on */

    setenv("ASTRAL_STATE", state,  1);
    setenv("ASTRAL_PIN",   pinbuf, 1);
    setenv("ASTRAL_AMPS",  ampbuf, 1);

    execl("/bin/sh", "sh", "-c", cmd, "astral-pins",
          state, pinbuf, ampbuf, (char *)NULL);
    _exit(127);
}

/* ---------------------------------------------------------------- main --- */

static void usage(void)
{
    fputs("usage: astral-pins [--status | --probe | --daemon]\n"
          "  --status                one decoded reading, then exit\n"
          "  --probe                 try every NVIDIA I2C bus, show raw answers\n"
          "  --daemon                loop forever (astral-pins.service)\n"
          "  -o, --output FILE       status file, plus FILE.pin1 .. FILE.pin6\n"
          "  -b, --bus N             force an I2C bus instead of autodetecting\n"
          "  -i, --interval SEC      seconds between reads (default 1.0)\n"
          "  -w, --warn AMPS         per-pin warning level (default 9.0)\n"
          "  -a, --alarm-command CMD run on alarm, as: CMD on|off PIN AMPS\n"
          "      --alarm-repeat SEC  re-run it this often while over (default 30)\n"
          "      --test-alarm        fire the alarm command once and exit\n", stderr);
}

static int do_probe(void)
{
    uint8_t raw[BLOCK_LEN];
    struct pin pins[NUM_PINS];

    for (int bus = 0; bus < 64; bus++) {
        if (!is_nvidia_bus(bus))
            continue;
        printf("i2c-%d: ", bus);
        int fd = open_bus(bus);
        if (fd < 0) {
            printf("cannot open (%s)\n", strerror(errno));
            continue;
        }
        if (read_block(fd, DATA_REG, raw, BLOCK_LEN) < 0) {
            printf("no answer at 0x%02x (%s)\n", CHIP_ADDR, strerror(errno));
            close(fd);
            continue;
        }
        for (int i = 0; i < BLOCK_LEN; i++)
            printf("%02x", raw[i]);
        decode(raw, pins);
        printf("  -> %s\n", looks_like_12v(pins) ? "VALID 12V rail" : "not a 12V rail");
        if (looks_like_12v(pins))
            print_detail(pins);
        close(fd);
    }
    return 0;
}

int main(int argc, char **argv)
{
    enum { M_STATUS, M_PROBE, M_DAEMON, M_TESTALARM } mode = M_STATUS;

    for (int i = 1; i < argc; i++) {
        const char *a = argv[i];
        if (!strcmp(a, "--status"))            mode = M_STATUS;
        else if (!strcmp(a, "--probe"))        mode = M_PROBE;
        else if (!strcmp(a, "--daemon"))       mode = M_DAEMON;
        else if (!strcmp(a, "--test-alarm"))   mode = M_TESTALARM;
        else if ((!strcmp(a, "-o") || !strcmp(a, "--output")) && i + 1 < argc)
            opt_out = argv[++i];
        else if ((!strcmp(a, "-b") || !strcmp(a, "--bus")) && i + 1 < argc)
            opt_bus = atoi(argv[++i]);
        else if ((!strcmp(a, "-i") || !strcmp(a, "--interval")) && i + 1 < argc)
            opt_interval = atof(argv[++i]);
        else if ((!strcmp(a, "-w") || !strcmp(a, "--warn")) && i + 1 < argc)
            opt_warn = atof(argv[++i]);
        else if ((!strcmp(a, "-a") || !strcmp(a, "--alarm-command")) && i + 1 < argc)
            opt_alarm = argv[++i];
        else if (!strcmp(a, "--alarm-repeat") && i + 1 < argc)
            opt_alarm_repeat = atof(argv[++i]);
        else { usage(); return 2; }
    }

    signal(SIGCHLD, SIG_IGN);        /* alarm children reap themselves */

    if (mode == M_PROBE)
        return do_probe();

    if (mode == M_TESTALARM) {
        if (!opt_alarm) {
            fprintf(stderr, "astral-pins: --test-alarm needs --alarm-command\n");
            return 2;
        }
        printf("firing alarm command: %s\n", opt_alarm);
        run_alarm("on", 3, 9.42);
        sleep(1);                    /* let the child get going before we exit */
        return 0;
    }

    int bus = opt_bus, fd;
    if (opt_bus >= 0) {
        fd = open_bus(opt_bus);
        if (fd < 0) {
            fprintf(stderr, "astral-pins: cannot open i2c-%d: %s\n",
                    opt_bus, strerror(errno));
            return 1;
        }
    } else {
        fd = find_chip(&bus);
        if (fd < 0) {
            fprintf(stderr, "astral-pins: IT8915FN not found on any NVIDIA I2C "
                            "bus (is i2c-dev loaded? are you root?)\n");
            return 1;
        }
    }

    struct pin pins[NUM_PINS];
    char line[256];

    if (mode == M_STATUS) {
        if (sample(fd, pins) < 0) {
            fprintf(stderr, "astral-pins: read failed: %s\n", strerror(errno));
            return 1;
        }
        printf("IT8915FN on i2c-%d @ 0x%02x\n", bus, CHIP_ADDR);
        print_detail(pins);
        format_summary(pins, line, sizeof line);
        printf("  summary        %s\n", line);
        if (opt_out)
            write_status(opt_out, pins);
        return 0;
    }

    /* daemon */
    setvbuf(stdout, NULL, _IOLBF, 0);
    printf("astral-pins: IT8915FN on i2c-%d @ 0x%02x, every %.2fs, warn %.1fA%s%s\n",
           bus, CHIP_ADDR, opt_interval, opt_warn,
           opt_out ? ", writing " : "", opt_out ? opt_out : "");
    if (opt_alarm)
        printf("astral-pins: alarm command: %s (repeating every %.0fs)\n",
               opt_alarm, opt_alarm_repeat);

    struct timespec ts = {
        .tv_sec  = (time_t)opt_interval,
        .tv_nsec = (long)((opt_interval - (double)(time_t)opt_interval) * 1e9),
    };
    int alarm_on = 0, fails = 0;
    time_t last_fired = 0;

    for (;;) {
        if (sample(fd, pins) < 0) {
            if (++fails == 1 || fails % 60 == 0)
                fprintf(stderr, "astral-pins: read failed (%d in a row): %s\n",
                        fails, strerror(errno));
            /* the chip goes quiet while the GPU sleeps; keep trying */
        } else {
            fails = 0;
            if (opt_out)
                write_status(opt_out, pins);

            int which;
            double peak = peak_amps(pins, &which);
            time_t now = time(NULL);

            if (!alarm_on && peak >= opt_warn) {
                fprintf(stderr, "astral-pins: ALARM pin %d at %.2f A "
                                "(limit %.1f A)\n", which + 1, peak, opt_warn);
                run_alarm("on", which, peak);
                alarm_on = 1;
                last_fired = now;
            } else if (alarm_on && peak < opt_warn - ALARM_HYSTERESIS) {
                fprintf(stderr, "astral-pins: alarm cleared, peak now %.2f A\n",
                        peak);
                run_alarm("off", which, peak);
                alarm_on = 0;
            } else if (alarm_on && opt_alarm_repeat > 0 &&
                       difftime(now, last_fired) >= opt_alarm_repeat) {
                fprintf(stderr, "astral-pins: ALARM still on, pin %d at %.2f A\n",
                        which + 1, peak);
                run_alarm("on", which, peak);
                last_fired = now;
            }
        }
        nanosleep(&ts, NULL);
    }
}

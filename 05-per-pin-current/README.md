# 05 — 12V-2x6 per-pin current sensing (`astral-pins`)

All six per-pin currents from the RTX 5090 ROG Astral's own shunt sensor, live in
the overlay, with an audible alarm if any single pin goes over the limit. This is
the Linux equivalent of what GPU Tweak shows on Windows, and there was no existing
tool for it.

**Astral-specific.** The card has an ITE **IT8915FN** microcontroller on its I2C
bus that no other 5090 carries. On any other card this component does nothing
useful, and `astral-pins --probe` will tell you so.

## What it installs

| File | |
|---|---|
| `/usr/local/src/astral-pins/astral-pins.c` | the source — ~400 lines of C that exists nowhere else |
| `/usr/local/bin/astral-pins` | built from it by `install.sh` |
| `/usr/local/bin/astral-pins-alarm` | what the daemon runs when a pin goes over |
| `/etc/systemd/system/astral-pins.service` | the daemon, warn-only |
| `~/.config/MangoHud/bazzite-setup.d/35-pins.conf` | the overlay's six 12V-2x6 rows, one pin each under the frametime graph, joined into `MangoHud.conf`; see `02-mangohud-overlay` |

Needs `04-prerequisites` first, for `i2c-dev`.

## How it works

The chip sits at **`0x2b` on `i2c-7`**, which is `NVIDIA i2c adapter 1 at 1:00.0`.
Register `0x80` holds six `[mV hi][mV lo][mA hi][mA lo]` groups, big-endian,
highest pin first. The bus is **autodetected** at startup by trying every NVIDIA
adapter and keeping the first that decodes to a live 12 V rail, so it survives the
adapter numbers moving between driver versions.

All 24 bytes come back in **one** `I2C_SMBUS_I2C_BLOCK_DATA` transaction. That is
the whole reason this tool exists:

| method | per sample | |
|---|---|---|
| byte-at-a-time SMBus | 34.6 ms | what the previous tool did — invasive enough to hitch frame pacing |
| **one block read** | **4.5 ms** | this |
| combined `I2C_RDWR` | 5.0 ms | the adapter ACKs it and returns garbage — unusable |

7.7× cheaper, so it samples **once a second** and still disturbs the bus less than
the old tool did at once every five (0.45 % duty vs 0.7 %, each stall 8× shorter).

It publishes plain text to tmpfs and the overlay just reads files:

```
/dev/shm/astral-pins        8.12 8.03 7.94 8.20 8.31 7.85  =48.4A    for scripts
/dev/shm/astral-pins.pin1   8.120 A                                  one overlay row each
/dev/shm/astral-pins.pin6   7.850 A !!                               over the limit
```

In the overlay they are six chunky rows under the frametime graph, pin 1 at the
top and no labels, copied from the Windows Afterburner OSD:

```
7.260 A
6.940 A
 ...
9.210 A !!
```

**`/dev/shm`, not `/run`, and this matters.** Steam runs games inside a
pressure-vessel container with its **own `/run`**, so a file written to `/run` on
the host does not exist as far as any game is concerned — the overlay rows come
out blank in games while looking perfect on the desktop. `/dev/shm` passes
straight through and is still tmpfs, so no disk traffic. `/tmp` and `$HOME` are
shared too; `/run/user/1000` is **not**.

## Commands

```bash
sudo astral-pins --status       # one decoded reading, volts and amps per pin
sudo astral-pins --probe        # every NVIDIA bus and what it answers
cat /dev/shm/astral-pins        # what the overlay is showing
journalctl -u astral-pins -f    # warnings as they happen
sudo systemctl restart astral-pins
```

## The alarm

Crossing **9.0 A** on any pin does three things at once: `!!` appears after that
pin's value in the overlay, a line goes in the journal, and the service runs
`astral-pins-alarm`, which puts a *critical* desktop notification and **four alarm
tones** into your session. It repeats every 30 s while the condition lasts and
plays a single chime with an "all clear" when the current drops back.

Sound as well as notification because a full-screen game usually swallows
notifications; audio always gets through. The tone is `dialog-warning.oga` (0.5 s)
rather than `alarm-clock-elapsed.oga` — the latter is 6 s a go, and three of those
is 18 s out of every 30, which is unbearable rather than useful.

**Warning only. It will not power the machine off.** That is deliberate. 9.0 A
sits above the ~8.9 A a peak pin naturally reaches at the card's 600 W cap, so it
will not cry wolf, and well under the ~9.5 A sustained figure that is the
documented melting regime.

Test it without waiting for a fault:

```bash
sudo astral-pins --test-alarm --alarm-command /usr/local/bin/astral-pins-alarm
```

## Tuning

Everything is an argument in the unit file. Rather than editing it, drop an
override — the real config stays untouched and deleting one file is the whole
revert:

```bash
sudo mkdir -p /etc/systemd/system/astral-pins.service.d
sudo tee /etc/systemd/system/astral-pins.service.d/50-warn.conf <<'END'
[Service]
ExecStart=
ExecStart=/usr/local/bin/astral-pins --daemon --interval 1 --warn 6.0 \
          --output /dev/shm/astral-pins \
          --alarm-command /usr/local/bin/astral-pins-alarm --alarm-repeat 30
END
sudo systemctl daemon-reload && sudo systemctl restart astral-pins
journalctl -u astral-pins -n 5      # it prints the level it is running at
```

Undo: delete that file, `daemon-reload`, restart.

| Knob | Where | Now |
|---|---|---|
| alarm level | `--warn` | 9.0 A |
| seconds between reads | `--interval` | 1.0 |
| alarm re-fire interval | `--alarm-repeat` | 30 s (`0` = once only) |
| what the alarm runs | `--alarm-command` | `/usr/local/bin/astral-pins-alarm` |
| tone and repeat count | `SOUND_ALARM`, `ALARM_REPEATS` at the top of `astral-pins-alarm` | |

It clears at `--warn` minus 0.5 A, so a pin sitting exactly on the line cannot
chatter.

## Traps

**Never put `ProtectHome=yes` on this unit.** It hides `/home`, `/root` *and
`/run/user`* — and `/run/user/$uid` is where both the D-Bus session socket and the
PipeWire socket live. With it set, `notify-send` and `paplay` fail, but the daemon
still logs `ALARM pin N` and still marks the overlay, so from the outside it looks
like the alarm fired and the desktop ignored it. There is a comment in the unit
and a check in the script saying so out loud.

**The alarm command must be `sh -c '<cmd> "$@"'`, not `sh -c '<cmd>'`.** Without
the explicit `"$@"` the positional arguments go nowhere and the alarm reports its
pin as `?`. The state, pin and current are also passed as `ASTRAL_STATE`,
`ASTRAL_PIN` and `ASTRAL_AMPS` so either style works now.

**Every step of the alarm script logs its exit code, deliberately** — a silent
failure here is indistinguishable from there being nothing wrong.

**`/etc` is per-deployment.** The unit file lives in `/etc/systemd/system`, so
re-run this installer after any `rpm-ostree rollback` or `upgrade`.

**This daemon touches a GPU I2C bus once a second**, and the display DDC path uses
the same adapter family. If you are ever chasing an unexplained
frame-presentation stall, `sudo systemctl stop astral-pins` is a cheap thing to
rule in or out — no reboot needed.

## Reference reading

At 534 W the six pins carried 7.30 / 7.00 / 7.28 / 7.68 / 7.50 / **7.94** A —
peak only 6.6 % above average, a healthy balance. Cross-check against the card's
own telemetry: 44.0 A × 12.1 V = 532 W, and `nvidia-smi` said 532.77 W.

# 08 — GPU undervolt (LACT)

The undervolt itself, and the tool that applies it. LACT is the Linux equivalent of
Afterburner's voltage/frequency curve editor, and on this driver it exposes the
full set.

## What it installs

| File | |
|---|---|
| `/etc/lact/config.yaml` | **the undervolt** — profiles, the V/F curve, clock and power limits |
| `~/LACT-profile-UV1.json`, `~/LACT-profile-UV2.json` | exported profiles, for importing in the GUI |
| `~/.local/bin/gpu-voltage` | publishes the GPU core voltage, read from LACT, for the overlay |
| `~/.config/systemd/user/gpu-voltage.service` | runs the above |
| `~/.config/MangoHud/bazzite-setup.d/20-voltage.conf` | the overlay's VOLTAGE row; see `02-mangohud-overlay` |

Needs `lact` layered — `04-prerequisites`.

## The overlay's VOLTAGE row

It lives here rather than in `02` because it reads from `lactd`, which this
component runs. MangoHud reads NVIDIA cards through NVML, and this driver has no
voltage API — no voltage symbol in `libnvidia-ml.so.1` at all, and
`nvidia-smi -q -d VOLTAGE` prints an empty section — so MangoHud's own
`gpu_voltage` would be a permanent `0 mV`. LACT gets the figure through NvAPI, so
`gpu-voltage.service` asks it once a second and publishes to
`/dev/shm/gpu-voltage.mv`, which the overlay `cat`s. One stats query costs ~16 ms,
fine once a second and absurd at the overlay's refresh rate, and Steam's container
has no `lact` binary inside it.

Installing this component adds the row to `MangoHud.conf`. That does not activate
the undervolt.

## The profile

The live config carries a profile named **`UV`** with `max_core_clock: 2851` and a
full per-point voltage/frequency curve. The GUI shows it under **Overclocking**,
and `current_profile` at the top of `config.yaml` says which one is active. The
daemon logs the one it picked at startup:

```bash
journalctl -u lactd | grep "using profile"
```

Target for this card: **950 mV at 2850 MHz**. Undervolting also buys 12V-2x6
headroom — dropping from 600 W to ~480 W takes the peak pin from ~8.9 A to ~7.1 A.

For reference, the **stock** curve on this sample runs 2700 MHz @ 975 mV,
2917 MHz @ 1050 mV, topping out at 3135 MHz @ 1170 mV.

**Silicon-specific.** An undervolt that is stable on this card is not guaranteed
stable on another of the same model. On different hardware, treat the curve here as
a starting point and validate it, not as a setting to adopt.

## What LACT gives you

- **Power cap** — 400 W to 600 W
- **GPU clock offset** — per power state, −1000 to +1000 MHz
- **Memory clock offset** — −2000 to +6000 MHz
- **Max / min core clock** — i.e. locked clocks
- **Voltage boost** — 0 to 100
- **The V/F curve itself** — per-point frequency and voltage, so a proper curve
  undervolt rather than just an offset

Profiles mean you can keep a stock profile alongside a tuned one and switch. Every
setting is reversible — Revert in the GUI, or `lact cli` reset.

## Architecture, which matters when something looks wrong

A **root `lactd` daemon owns the GPU**; the GUI is just a client. So:

* Settings live in `/etc/lact/config.yaml`, not in your home directory.
* Editing that file does nothing until `sudo systemctl restart lactd`.
* `apply_settings_timer: 5` means the daemon re-asserts its settings every 5 s, so
  something else fighting it will lose.

```bash
lact gui                                              # the GUI
sudo systemctl restart lactd                          # after editing config.yaml
journalctl -u lactd -n 20
lact cli list-gpus
lact cli -g 10DE:2B85-1043:89E3-0000:01:00.0 stats    # live clocks and voltage
```

## Traps

**This is the component that has actually broken, twice, so read these.**

**`/etc` is per-deployment on rpm-ostree, and this file lives in `/etc`.** Each
deployment carries its own `/etc`, snapshotted when it was created. Roll back or
roll forward and `/etc/lact/config.yaml` is whatever that deployment had — which,
the first time this happened, was a 164-byte stub with `current_profile: null`.
The undervolt simply vanished after a reboot, with no error anywhere. `/var`
(and therefore `/home` and `/usr/local`) is shared and does **not** do this.

Recovering it means copying the good file out of the other deployment:

```bash
ls /ostree/deploy/default/deploy/*/etc/lact/config.yaml     # find the fat one
sudo cp -a /etc/lact/config.yaml /etc/lact/config.yaml.bak-rollback
sudo cp /ostree/deploy/default/deploy/<checksum>.0/etc/lact/config.yaml /etc/lact/config.yaml
sudo systemctl restart lactd
journalctl -u lactd | grep "using profile"                  # expect: using profile 'UV'
```

Which is exactly what this component now exists to make unnecessary: after any
`rpm-ostree rollback` or `upgrade`, re-run `./install.sh`.

**The `lact cli` GPU-selection trap.** `lact cli stats` with no `-g` silently
selects GPU 0 — the Radeon iGPU in the 9800X3D — and prints *its* voltage and
clocks with no warning at all. The numbers look plausible, which is how a wrong
voltage reading once shipped to the overlay. Always pass `-g`, and note it is a
flag on `lact cli`, **not** on `stats`, so it goes *before* the subcommand:

```bash
lact cli -g 10DE:2B85-1043:89E3-0000:01:00.0 stats   # right
lact cli stats -g 10DE:...                            # errors
lact cli stats                                        # WRONG GPU, no warning
```

**A profile can be defined and not active, and nothing says so.** `profiles:` in
`config.yaml` lists what exists; `current_profile:` says which one is in force, and
**`current_profile: null` means the card is at stock** no matter how good the curve
above it looks. That was the state when this directory was built — `UV` and `UV1`
both defined, neither active, the card at the full 600 W cap and 800 mV at idle.
The installer reports both facts separately for exactly this reason, and
deliberately does **not** activate a profile for you: changing GPU voltage and
clocks is not something an installer should do unasked.

```bash
lact cli profile set UV         # or pick it in the LACT GUI
grep current_profile /etc/lact/config.yaml
```

**A clock cap set here is real and easy to forget.** `max_core_clock: 2851` limits
the card whether or not you are thinking about the undervolt. If the card seems to
be leaving performance on the table, check this before blaming anything else.

**Watch for Xid errors after any change**: `journalctl -k | grep -i xid`. An
unstable undervolt shows up there, and zero Xids is how this one was cleared as a
cause of an unrelated stutter.

**The `lact cli` trap, which shipped a wrong voltage reading once.** `lact cli
stats` with no `-g` silently selects GPU 0 — the Radeon iGPU — and prints *its*
voltage and clocks with no warning. The numbers look perfectly plausible (~1170 mV
while the 5090 was at 980 mV), which is exactly why it got past review. Always
pass the GPU id, and note `-g` is a flag on `lact cli`, **not** on `stats`, so it
goes *before* the subcommand:

```bash
lact cli -g 10DE:2B85-1043:89E3-0000:01:00.0 stats
```

`~/.local/bin/gpu-voltage` has the id at the top as `GPU_ID`; that is the line to
change on other hardware. `lact cli list-gpus` prints the ids.

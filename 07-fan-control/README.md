# 07 — Fan control (CoolerControl, from the Windows FanControl config)

The Windows FanControl curves, decoded out of `userConfig.json` and rebuilt exactly
inside CoolerControl.

## What it installs

| File | |
|---|---|
| `~/.local/share/gaming-setup/apply-fan-curves.py` | rebuilds the whole CoolerControl setup |
| `coolercontrol-config.toml.reference` | a copy of the live `/etc/coolercontrol/config.toml`, **for reference only** |

**This is the one component that is not a file copy.** CoolerControl keeps its
profiles and channel assignments in its own database behind its daemon, so the way
to reproduce the setup is to talk to it — which is what the Python script does.
`config.toml` is here so you can read what the result looks like and diff against
it, not to be dropped into `/etc`.

Needs `coolercontrol` layered and `nct6775` loaded — both from `00-prerequisites`.

## The curves

| Curve | Source | Points |
|---|---|---|
| GPU | NVIDIA GPU temp | 60 °C → 26 %, 65 °C → 40 %, flat outside |
| CPU | k10temp **Tctl** | 70 °C → 20 %, 80 °C → 50 %, flat outside |
| Main Mix | — | **Max**(GPU, CPU) |

| Channel | Header | Profile |
|---|---|---|
| `fan1` | CHA_FAN1, Bottom Intake | Main Mix |
| `fan2` | CPU_FAN, Top Exhaust / radiator | Main Mix |
| `fan3` | CHA_FAN3, Rear 140 Exhaust | Main Mix |
| `fan6` | CHA_FAN2, Rear Exhaust | GPU (reads 0 rpm — nothing plugged in) |
| `fan7` | pump, ~6100 rpm | **left on BIOS control**, as on Windows |
| `fan4`, `fan5` | unused | |

FanControl clamps a curve flat outside its first and last point; CoolerControl does
the same, but the flat sections are written out explicitly in the script so the
intent survives anyone opening the GUI later.

Measured under load: Tctl 78.0 °C → PWM 110 (43 %; the curve asks 44 %), 79.8 °C →
PWM 125 (49 %; curve says 50 %). The Max mix behaved correctly — the CPU curve
overrode the GPU curve. Back to PWM 66 at idle.

## Install

```bash
./install.sh
```

which copies the script and runs it. Run it again any time — it is **idempotent**,
matching profiles by name, so it updates rather than duplicating. That is the
recovery path after a CoolerControl reinstall or a config reset.

GUI: **CoolerControl** in the app menu.

### If it comes back `HTTP 401`

The script logs in to the daemon's API with CoolerControl's stock credentials,
`CCAdmin` / `coolAdmin`. **Setting a password in the CoolerControl GUI breaks
that** — and it happened on this machine on 13 Sep 2026, which is why the
installer knows about it. The daemon keeps only a hash, in
`/etc/coolercontrol/.passwd`, so the old password cannot be read back out. Pass
the real one:

```bash
CC_PASSWORD='yourpassword' ./install.sh
# or
CC_PASSWORD='yourpassword' python3 ~/.local/share/gaming-setup/apply-fan-curves.py
```

A 401 does **not** mean the fans are unmanaged — the curves are in
CoolerControl's database and running regardless; only the rebuild path is
blocked. The installer checks for the three ported profiles in
`/etc/coolercontrol/config.toml` and says which of the two situations you are in.
If you have genuinely lost the password, the reset is to delete
`/etc/coolercontrol/.passwd` and restart `coolercontrold`.

## Tuning

Edit the curve tables at the top of `apply-fan-curves.py` and re-run it. Or use the
GUI — but then this directory is out of date, so copy the changed `config.toml`
back over `coolercontrol-config.toml.reference` when you do.

## Traps

**Without `nct6775` there are no motherboard fan sensors at all**, and
CoolerControl will show only the GPU and the AIO. That module is not autoloaded on
this board; `00-prerequisites` is what loads it. If the fan channels are missing,
check `sensors | grep nct6799` before suspecting CoolerControl.

**Channel names are board-specific.** `fan1`…`fan7` are this board's NCT6799D
channels. On other hardware, open the CoolerControl GUI and read the names off the
device before editing the script.

**`fan7` is the pump and is deliberately left alone**, on BIOS control, matching
the Windows setup. Do not hand it to a curve without knowing what the BIOS was
doing with it.

**`coolercontrold` must be running** for the script to do anything — it talks to
the daemon's API, not to the hardware.

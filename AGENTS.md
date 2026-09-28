# AGENTS.md — instructions for an agent setting this up on a new machine

You have been handed this directory and asked to reproduce a Linux gaming setup on
a machine that is not the one it was built on. Read this file first, then
`README.md`. Work top to bottom; do not skip the preflight.

Read this as the operating procedure, and each component's `README.md` as the
reference for that component. `reference/GAMING_SETUP_NOTES.md` is the long-form
history — why each decision was made, what was measured, what was tried and
rejected. Consult it when a component surprises you; do not read it front to back
to get started.

---

## The procedure

### 1. Preflight, before installing anything

```bash
./preflight.sh              # human-readable
./preflight.sh --brief      # only the differences
```

It is read-only. It compares the live machine against `machine-profile.conf` —
the recorded hardware — and prints, for every difference, **the exact file that
hardcodes the value and what to change it to**. Work through that list before
running any installer. `This machine matches the profile` means you can go
straight to step 3.

### 2. Adapt the hardware-specific values

Edit the files inside `NN-*/files/`, not the live system. The installers copy from
`files/` onwards, so an edit there is what gets installed and what stays recorded
for next time. Editing the live file instead means the change is lost the next time
anyone runs the installer.

The five values that actually move between machines:

| Value | File | Find it with |
|---|---|---|
| GPU PCI address | `02-*/files/home/.config/MangoHud/MangoHud.conf` → `pci_dev=` | `lspci -D \| grep -i vga` |
| GPU id for LACT | `02-*/files/home/.local/bin/gpu-voltage` → `GPU_ID` | `lact cli list-gpus` |
| monitor connectors and modes | `05-*/files/home/.local/bin/display-profile` → the `*_OUT` / `*_SIG` block near the top | `kscreen-doctor -o` |
| fan channel names | `07-*/files/home/.local/share/gaming-setup/apply-fan-curves.py` | the CoolerControl GUI |
| sensor module | `00-*/files/system/etc/modules-load.d/` | `sudo sensors-detect --auto` |

Then update `machine-profile.conf` to describe the new machine, so the next
preflight is meaningful.

### 3. Install

```bash
DRY_RUN=1 ./install-all.sh      # read this before the real run
./install-all.sh
```

Installers are idempotent — re-running is safe and prints `unchanged` for anything
already correct. They stop at the first genuine failure rather than carrying on and
leaving something half-built that looks finished.

`00-prerequisites` will tell you to layer packages and reboot. That is a real
interruption: layer them, reboot, then continue from `01`.

### 4. Verify

```bash
./reference/health-check.sh
```

This is the gate. It checks that things are **running**, not merely installed —
services active, `/dev/shm` feed files being written, the overlay's GPU actually
resolving. Do not report success on the basis of installers exiting 0; a component
can install perfectly and do nothing.

Then the parts a script cannot check, which need a human at the keyboard:

- launch a game, press `/`, confirm the overlay appears with the GPU rows populated
- press `Shift_L+F4` in game after any `MangoHud.conf` edit
- press Pause/Break, confirm the screens blank and come back
- click each display-profile launcher
- left-click the DLSS tray icon and confirm the icon changes

---

## Rules

**Do not activate the GPU undervolt.** `08-gpu-undervolt` installs LACT and the
profile; making that profile *current* changes real voltage and clocks on hardware
whose stability you cannot verify from a shell. Install it, report that
`current_profile` is null and what the command would be, and leave the decision to
the user. An undervolt that was stable on the original card is not necessarily
stable on another of the same model.

**Do not edit `~/.config/plasma-org.kde.plasma.desktop-appletsrc` while
plasmashell is running.** It holds its own in-memory copy and writes it back over
your edit later, silently, taking unrelated launchers with it. `09-taskbar`
deliberately prints the three commands rather than doing it. Stop the shell, edit,
start the shell.

**Do not add `ProtectHome=yes` to `astral-pins.service`.** It hides `/run/user`,
so the alarm's notification and sound both fail while the daemon still logs
`ALARM` — an alarm that looks like it worked and did not reach anyone.

**Do not call `org.kde.KGlobalAccel` over D-Bus with the wrong arity.** It crashes
`kwin_wayland` and takes every XWayland application with it. Introspect first.

**Do not restart `plasmalogin` while a session is logged in.**

**Do not re-enable `suspend`/`hibernate` targets** if they are masked. That is
deliberate on the original machine; `06-displays-sleep` is the replacement.

**Do not assume `qdbus6` exists.** Bazzite has `qdbus` and `qdbus-qt6` but not
`qdbus6`, which is the name most KDE documentation uses — so the pasted command
fails, and in a script with errors swallowed it does nothing while appearing to
work. Use the `qdbus_cmd` helper in `common/lib.sh`.

**Treat unallocated disk space as reserved.** On the original machine 628 GiB at
the end of the second NVMe is held for a Windows dual-boot and is not free space.
Check before touching any partition table.

**Verify, do not infer.** Two bugs in this directory's own checks were the same
mistake: a plausible-looking result that was never confirmed against hardware.
`cmd | grep -q` under `set -o pipefail` reports failure when grep exits early and
the writer takes SIGPIPE, and `grep -i xid` matches an Ethernet driver printing its
chip revision. Both declared a working machine broken. When a check disagrees with
the hardware, suspect the check.

---

## What needs a human, and cannot be automated

Say so plainly rather than working around these.

| Thing | Why |
|---|---|
| layering packages + reboot | `rpm-ostree install` needs a reboot to take effect |
| BIOS fan headers | which fan is plugged into which header is physical |
| the CoolerControl password | if one was set in its GUI, only a hash is stored. `CC_PASSWORD='...' ./install.sh` |
| validating the undervolt | needs sustained real load and someone watching for instability |
| Steam sign-in, and per-game Proton version | account credentials; and GE-Proton must be chosen per game |
| the Windows source configs | `machine-profile.conf` records where the Afterburner, FanControl, DisplaySwitch and DlssOverlay originals live, if anything needs re-deriving. Not needed for a reinstall. |
| arranging the panel | easiest by dragging icons, then recording it: see `09-taskbar` |
| the TV profile | `display-profile tv` has never been confirmed against the real TV |

---

## Dependencies between components

Only these; everything else is independent and can be installed alone.

```
00-prerequisites ──> everything (packages, kernel modules)
     └─ i2c-dev ──> 01-per-pin-current
     └─ lact    ──> 02 (the VOLTAGE row) and 08
01-per-pin-current ──> 02  (the 12V PINS rows read its /dev/shm files)
03-dlss-presets    ──> 02  (MANGOHUD=1 lives in 95-gaming.conf)
                   ──> 04  (the debug-overlay switch lives there too)
05-display-switching ──> 11 (window-info, for finding a window class)
```

If a component you depend on is absent, the dependent one degrades quietly rather
than failing loudly — the `12V PINS` rows go blank, the `VOLTAGE` row reads `--`.
That is the behaviour to expect, not a bug to chase.

## Hardware that is genuinely specific

| Component | Tied to |
|---|---|
| `01-per-pin-current` | **ROG Astral only.** The IT8915FN is not on other 5090s. Run `sudo astral-pins --probe`; if nothing answers, skip the component and delete the `12V PINS` rows from `MangoHud.conf`. |
| `08-gpu-undervolt` | the individual card, not the model |
| `05-display-switching` | connector names and monitor modes |
| `07-fan-control` | the board's sensor chip and channel names |
| `02-mangohud-overlay` | the GPU's PCI address and LACT id |
| `03`, `04`, `06`, `09`, `10`, `11` | nothing — these port as-is |

## Reporting back

State what is installed and **verified running**, what is installed but unverified
and why, and what you deliberately left for the user, including the undervolt. If
`health-check.sh` reports a FAIL you could not resolve, quote it rather than
summarising it. Do not describe a component as working because its installer
succeeded.

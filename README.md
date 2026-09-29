# bazzite-setup

Every hand-built piece of this machine's gaming setup, split one directory per
thing, each carrying the files it needs and the documentation to rebuild and tune
it. The point is portability: copy this directory to a fresh install, run the
installers in order, and you get the same machine back.

The long-form story — why each decision was made, what was measured, what was
tried and rejected — stays in [`reference/GAMING_SETUP_NOTES.md`](reference/GAMING_SETUP_NOTES.md).
The READMEs here are the operational half: what it is, how to install it, how to
change it, and what will bite you.

**Setting this up on a new machine, by hand or with an agent?** Start with
[`AGENTS.md`](AGENTS.md) — the procedure, the rules about what must not be
automated, and what genuinely needs a human. It opens with two policy sections
worth reading even if you are doing this by hand: **Bazzite** (immutable Fedora
Atomic — `dnf` is not the package manager, `/etc` is per-deployment) and **HDR**
(why colours come out washed out, and which of the advice online actually applies
here). Then `./preflight.sh`.

Built for: Bazzite 44 (Fedora Kinoite 44, KDE Plasma 6.6 Wayland), Ryzen 7 9800X3D,
RTX 5090 ROG Astral OC (`10de:2b85` / `1043:89e3`), SAPPHIRE NITRO+ B850M WIFI.
Several components are hardware-specific in ways the READMEs call out — the
per-pin monitor knows an ITE IT8915FN, the display profiles know your four
outputs by name. Those are the places to look first on different hardware.

## The components

Each component depends only on lower-numbered ones. `00`–`03` are **stage 1** — the
basics, with nothing layered and no reboot; everything from `04` on is stage 2.

| Directory | What it gives you | Hardware-specific? |
|---|---|---|
| [`00-gaming-env`](00-gaming-env/) | the environment every Steam game inherits — the Proton HDR switches, `MANGOHUD=1` — and `dlss`: SR / RR / MFG presets and DLL version | no |
| [`01-displays`](01-displays/) | `display-profile` — four monitor layouts, on the taskbar and desktop — and HDR per screen | **yes** — output names |
| [`02-mangohud-overlay`](02-mangohud-overlay/) | the Afterburner-matched in-game overlay, `/` to toggle, with the FPS limiter | GPU PCI address |
| [`03-dlss-debug-overlay`](03-dlss-debug-overlay/) | tray icon that toggles NVIDIA's DLSS indicator and shows its state | no |
| [`04-prerequisites`](04-prerequisites/) | layered packages and the two kernel modules the rest of stage 2 needs | board sensor chip |
| [`05-per-pin-current`](05-per-pin-current/) | all six 12V-2x6 pin currents off the Astral's own sensor, with an alarm, and their overlay rows | **yes** — Astral only |
| [`06-displays-sleep`](06-displays-sleep/) | Pause/Break blanks the displays | no |
| [`07-fan-control`](07-fan-control/) | the Windows FanControl curves, ported to CoolerControl | **yes** — channel names |
| [`08-gpu-undervolt`](08-gpu-undervolt/) | LACT, the undervolt profile itself, and the overlay's VOLTAGE row | **yes** — silicon-specific |
| [`09-taskbar`](09-taskbar/) | the panel launcher row, and the only safe way to edit it | no |
| [`10-nvtruehdr`](10-nvtruehdr/) | SDR→HDR Vulkan layer (lives in its own git repo) | no |
| [`11-game-window-fixes`](11-game-window-fixes/) | the KWin rule that stops Hunt dropping to the desktop | no |
| [`12-shell-environment`](12-shell-environment/) | bash aliases and a git-aware prompt, into `~/.bashrc.d/` | no |

| File | |
|---|---|
| [`AGENTS.md`](AGENTS.md) | the porting procedure and the rules. `CLAUDE.md` is a symlink to it |
| [`machine-profile.conf`](machine-profile.conf) | every hardware-specific value in one place: PCI addresses, LACT ids, connector names, fan channels, the sensor chip |
| [`preflight.sh`](preflight.sh) | compares this machine against that profile and names the file to edit for each difference. Read-only |
| [`stage1.sh`](stage1.sh) | the basics on a fresh install: HDR, display switching, overlay + FPS limiter, DLSS toggle |
| [`status.sh`](status.sh) | per component: installed? running? Read-only. `--porcelain` for one line each, or pass `NN` for one component |
| `.claude/commands/` | `/setup` walks the components one at a time; `/status` reports where you are. They ship with the clone |
| `common/lib.sh` | shared by every installer |
| `reference/` | full notes, the original brief, the layered-package list, `health-check.sh` |

## Moving to a new machine

```bash
git clone git@github.com:TwoToneEddy/bazzite-setup.git ~/bazzite-setup
cd ~/bazzite-setup
./preflight.sh                  # what differs, and which file hardcodes it
#   ... edit the files it names, inside NN-*/files/ ...
./install-all.sh
./status.sh                     # where am I up to, component by component
./reference/health-check.sh     # confirm things are RUNNING, not just installed
```

**Or just the basics first.** `./stage1.sh` installs stage 1 — HDR, display
switching, the MangoHud overlay with its FPS limiter, and the DLSS indicator
toggle — with nothing layered and no reboot. The 12V-2x6 and VOLTAGE overlay rows
arrive with `05` and `08` in stage 2.

**Or let an agent walk you through it.** `CLAUDE.md` and the `/setup` command are
in the repo, so they arrive with the clone:

```bash
cd ~/bazzite-setup && claude
/setup            # one component at a time, confirming before each
/status           # just tell me where I am
```

`/setup` reads `AGENTS.md` first, runs the preflight, shows you the component list
with its current state, then goes one at a time: explain, adapt, dry run, install,
verify, hand back anything a script cannot do. It will not activate the undervolt,
edit the Plasma panel config live, or reboot.

Only five values genuinely move between machines — the GPU's PCI address, its LACT
id, the monitor connectors, the fan channel names and the board's sensor module.
`preflight.sh` finds all five and `AGENTS.md` tabulates where each one lives.
Components `00`, `03`, `06`, `09`, `10`, `11` and `12` port with no changes at all.

One component lives elsewhere on purpose: **nvtruehdr** is its own repository at
<https://github.com/TwoToneEddy/nvtruehdr>, and `10-nvtruehdr/install.sh` clones
and builds it.

## Installing

Components are numbered in dependency order, so `./install-all.sh` is always
right. `04-prerequisites` has to come before `05`, `07` and `08`, which need its
packages and modules; otherwise install just the pieces you want.

```bash
cd bazzite-setup
./install-all.sh                  # everything, in order
./install-all.sh 02 05            # or just the components you name
DRY_RUN=1 ./install-all.sh        # print what would happen, touch nothing
cd 02-mangohud-overlay && ./install.sh    # or one on its own
```

Each installer is **idempotent** — it says `unchanged` for anything already in
place and only writes what differs. Nothing deletes a file it did not install.
Where a component has to replace something pre-existing that matters, it keeps a
one-time `.bak-bazzite-setup` copy first.

Every installer needs `sudo` only if it has a `files/system` tree; the table
above and each README say so.

## How a component is laid out

```
NN-name/
  README.md        what it is, install, tuning, traps
  install.sh       idempotent installer
  files/
    home/...       installed under $HOME, paths mirrored
    system/...     installed under /, paths mirrored, needs sudo
```

So `files/home/.config/environment.d/95-gaming.conf` lands at
`~/.config/environment.d/95-gaming.conf`, and
`files/system/etc/systemd/system/astral-pins.service` at
`/etc/systemd/system/astral-pins.service`. Adding a file to a component is just
putting it at the right place in that tree — `install.sh` walks it, nothing
lists filenames twice.

One file is the exception: `MangoHud.conf` is assembled from pieces that several
components install into `~/.config/MangoHud/bazzite-setup.d/`, so each overlay row
belongs to the component that feeds it. See `02-mangohud-overlay`.

## Refreshing this directory from the live system

These files are copies, not symlinks, so a change made live (editing
`95-gaming.conf` in place, say) does not appear here until you copy it back. A
change to the live `MangoHud.conf` belongs in the piece it came from, under
`~/.config/MangoHud/bazzite-setup.d/` and then in `NN-*/files/`.
`~/.local/bin/gaming-config-snapshot` collects the same set into a flat mirror
if you want a second opinion on what has drifted; to see what has:

```bash
cd bazzite-setup
for f in $(find */files/home -type f); do
    live="$HOME/${f#*/files/home/}"
    cmp -s "$f" "$live" || echo "differs: $live"
done
```

## Version control

All of it is safe to commit — nothing here holds a secret. `git init && git add
-A` in this directory is the whole story. Two things deliberately **not** in
here: anything under `~/.local/share/Steam` (session tokens) and the full Plasma
panel config (huge, churns constantly, and Plasma rewrites it — only the
`launchers=` line matters, and that is in `09-taskbar/panel-launchers.txt`).

## One thing that is easy to forget

This is an **rpm-ostree** system, and **each deployment carries its own `/etc`**,
snapshotted when the deployment was created. `/var` — which is where `/home` and
`/usr/local` really live — is shared between all of them. So a `files/system`
file that lands in `/etc` is present only on the deployment you installed it on.
Roll back or roll forward and it is gone, silently, while everything under
`files/home` follows you. That is how a LACT undervolt profile disappeared once.
After any `rpm-ostree rollback` or `upgrade`, re-run the installers that have a
`files/system/etc` tree: `04`, `05` and `08`.

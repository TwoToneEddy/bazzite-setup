# AGENTS.md — instructions for an agent setting this up on a new machine

You have been handed this directory and asked to reproduce a Linux gaming setup on
a machine that is not the one it was built on. Read this file first, then
`README.md`. Work top to bottom; do not skip the preflight.

Two sections below are policy rather than procedure, and both cover ways a
capable agent reliably goes wrong here. Read them before you install or change
anything:

* **[Bazzite policy](#bazzite-policy--read-before-installing-anything)** — this is
  an immutable Fedora Atomic system. `dnf install` is not how software gets
  installed, `/usr` is read-only, and `/etc` is per-deployment.
* **[HDR policy](#hdr-policy--washed-out-colours-are-the-default-failure-not-a-bug-you-found)** —
  washed-out colours are the default failure mode, there are four conditions that
  must all hold, and most of the advice circulating online does not apply to this
  configuration.

If the user would rather be walked through it, the `/setup` command in
`.claude/commands/` is this procedure as a wizard: one component at a time, with a
status check and a confirmation between each. `/status` just reports where the
machine is up to.

Read this as the operating procedure, and each component's `README.md` as the
reference for that component. `reference/GAMING_SETUP_NOTES.md` is the long-form
history — why each decision was made, what was measured, what was tried and
rejected. Consult it when a component surprises you; do not read it front to back
to get started.

---

## Bazzite policy — read before installing anything

**Bazzite is an immutable Fedora Atomic distribution (rpm-ostree).** `/usr` is
read-only and the whole OS is an image that gets replaced on update. An agent that
reaches for `dnf install` will make a mess, and a naive one will layer packages it
did not need to.

**`dnf` is not the package manager here.** `sudo dnf install x` either fails or
does something you did not intend. Neither is `yum`. Do not write to `/usr` by any
route; a file placed there is gone at the next update.

Pick a tool in this order, and only fall down the list when the one above cannot
do the job:

| Want | Use | Note |
|---|---|---|
| a GUI application | `flatpak install` | Chrome and Discord here are flatpaks |
| a CLI tool | `brew install`, or a `distrobox`/`toolbox` container | Bazzite ships Homebrew; neither touches the host image |
| a one-off build | `toolbox enter` | where `gcc` lives, if the host has none |
| something that must be part of the OS | `rpm-ostree install` | **last resort** |

**`rpm-ostree install` is a real commitment, not an install.** It layers the
package onto a new deployment, which means a **reboot** before it exists, a slower
rebase on every future update, and a thing that can block an update outright if it
conflicts. Three packages are layered here and each earns it by needing kernel or
system access a container cannot give: `coolercontrol`, `lact`, `liquidctl`
(`gamescope-session-steam` is deliberately not layered). Do not add a fourth to save typing `flatpak`.

**Never layer a package without telling the user it means a reboot**, and never
reboot on your own initiative. `04-prerequisites/install.sh` deliberately only
prints the command for this reason.

**Bazzite already ships most of what a gaming setup wants** — MangoHud, GOverlay,
gamescope, Steam, Proton, `vkbasalt`, `mesa-vulkan`. Check before installing:

```bash
rpm -q <pkg>              # in the image, or layered
command -v <tool>
rpm-ostree status         # what is layered, and on which deployment
```

**What is writable, and what follows you between deployments:**

| Path | |
|---|---|
| `/usr` | **read-only.** Never write here |
| `/etc` | writable, but **per-deployment** — each deployment has its own copy, snapshotted when it was created. Roll back or forward and your change is gone, silently |
| `/var` (so `/home`, and `/usr/local` via a symlink) | writable and **shared** by all deployments |

That `/etc` behaviour is not theoretical: it is how a LACT undervolt profile
disappeared after a reboot here, leaving a 164-byte stub with
`current_profile: null` and no error anywhere. After any `rpm-ostree rollback` or
`upgrade`, re-run the installers that write to `/etc` — `04`, `05` and `08`.

**`uupd.timer` updates the system automatically** at 04:00, with
`Persistent=true`, so it catches up on missed runs. If you are testing anything
driver- or deployment-dependent, disable it first and **tell the user you have**,
because an overnight update will silently invalidate the test:

```bash
sudo systemctl disable --now uupd.timer      # and re-enable when done
```

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
| GPU PCI address | `02-*/files/home/.config/MangoHud/bazzite-setup.d/10-overlay.conf` → `pci_dev=` | `lspci -D \| grep -i vga` |
| GPU id for LACT | `08-*/files/home/.local/bin/gpu-voltage` → `GPU_ID` | `lact cli list-gpus` |
| monitor connectors and modes | `01-*/files/home/.local/bin/display-profile` → the `*_OUT` / `*_SIG` block near the top | `kscreen-doctor -o` |
| fan channel names | `07-*/files/home/.local/share/gaming-setup/apply-fan-curves.py` | the CoolerControl GUI |
| sensor module | `04-*/files/system/etc/modules-load.d/` | `sudo sensors-detect --auto` |

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

The components are numbered so that each depends only on lower numbers. `00`–`03`
are **stage 1** — RHI (`00-rhi`, cloned from `git@github.com:TwoToneEddy/RHI.git`),
HDR, display switching, the overlay with its FPS limiter, the DLSS indicator
toggle — and need no layered package; `./stage1.sh` installs just those.
Everything from `04` on is stage 2.

`04-prerequisites` will tell you to layer packages and reboot. That is a real
interruption: layer them, reboot, then run `./install-all.sh` again.

### 4. Verify

```bash
./status.sh                     # per component: installed, and running?
./reference/health-check.sh     # the machine as a whole, in more detail
```

`status.sh` is the one to use while working through components — it reports each as
`ok`, `partial` (installed but something is not running) or `absent` (not installed,
which is a correct answer for one deliberately skipped). `--porcelain` gives one
line per component if you are driving it from a script.

This is the gate. It checks that things are **running**, not merely installed —
services active, `/dev/shm` feed files being written, the overlay's GPU actually
resolving. Do not report success on the basis of installers exiting 0; a component
can install perfectly and do nothing.

Then the parts a script cannot check, which need a human at the keyboard:

- launch a game, press `/`, confirm the overlay appears with the GPU rows populated
- press `Shift_L+F4` in game after anything reassembles `MangoHud.conf`
- press Pause/Break, confirm the screens blank and come back
- click each display-profile launcher
- left-click the DLSS tray icon and confirm the icon changes

---

## HDR policy — washed-out colours are the default failure, not a bug you found

HDR is the single most common way a Linux gaming setup looks worse than the Windows
one it replaced, and the symptom is always the same: **washed-out, flat colours**
with HDR apparently "on". People give up over this and go back to Windows. The
cause is almost never the monitor.

**What is actually happening.** The screen is in HDR mode, the game is handing the
compositor an SDR image, and the compositor is stretching SDR into an HDR container.
So you get HDR's lower contrast handling with none of its range. On this setup the
specific trap is XWayland: **a Proton game on XWayland cannot do HDR**, the
compositor tone-maps its SDR output into the HDR screen, and the game reports the
monitor as having no HDR support at all. That is exactly what Hunt did here.

**The four things that must all be true**, in the order worth checking:

1. **The output is in HDR mode in KWin.** Per-output, not global. Recorded state
   here: `DP-1` (the AOC) and `HDMI-A-1` (the TV) have `highDynamicRange: true` and
   `wideColorGamut: true`; `HDMI-A-2` (the Dell) is **false**. So a game moved to
   the Dell loses HDR and nothing announces it. HDR on the TV is
   configured but not yet confirmed on the real TV. System Settings → Display →
   per screen, or read `~/.config/kwinoutputconfig.json`.
2. **The game presents through Wayland, not XWayland.** `PROTON_ENABLE_WAYLAND=1`
   **and** `PROTON_ENABLE_HDR=1` — both, in `00-gaming-env`' `95-gaming.conf`.
   `PROTON_ENABLE_HDR` sets `DXVK_HDR=1` internally.
3. **Proton GE or EM, per game.** Stock Valve Proton ignores both variables
   entirely. Steam → game → Properties → Compatibility. This is the step that is
   most often missed, because the environment looks correct.
4. **SDR brightness and gamut wideness are sane.** `sdrBrightness` and
   `sdrGamutWideness` in KWin decide how SDR content is mapped while the screen is
   in HDR mode. Here: 450 nits / wideness 1 on `DP-1`. Set badly, *everything* looks
   washed out — including the desktop, which is a useful thing to check, because a
   washed-out desktop means the problem is not the game.

**Then check the game.** `dlss overlay on` and the MangoHud overlay tell you what
the GPU is doing, but not whether the swapchain is HDR. Note that **some games
have no HDR setting at all** (CS2 is the usual example) and some detect HDR badly
and will tell you the monitor is not compatible when it is. A game refusing to see
HDR is a data point about the game, not proof the system is broken.

**Many games' own HDR is poor even when it works.** That is what `10-nvtruehdr`
exists for — an SDR→HDR Vulkan layer, and the better path for a title with no HDR
or a bad implementation. RenoDX and Luma Framework are the same idea from the mod
side; `~/RHI` is the installer for those here, cloned and built by `00-rhi`.

### Third-party reports, recorded but NOT verified here

These come from a user report, not from this machine. Treat them as leads, and
**check the version before acting on any of them** — a fix or a regression may have
landed since.

- **gamescope HDR regression.** A report of washed-out colours in all HDR games on
  KDE with gamescope 3.16.16–3.16.18, with 3.16.15 named as the last good version,
  and disagreement about whether the fault is gamescope's or KDE's
  (ValveSoftware/gamescope issue #2018). This machine runs
  **3.16.19-128-g7282613+**, which is *newer than any version in that report*, and
  gamescope here is part of the Bazzite image rather than a layered package — so
  downgrading it is not a `dnf downgrade`, it is a deployment-level change. Do not
  attempt it to chase a bug nobody has reproduced here.
- **`ENABLE_HDR_WSI=1`.** Widely repeated as the NVIDIA HDR launch option, but it
  is the switch for the **`vk_hdr_layer`** Vulkan layer, and that layer is **not
  installed here** — `/usr/share/vulkan/implicit_layer.d/` and
  `~/.local/share/vulkan/implicit_layer.d/` contain nvtruehdr, fossilize and the
  Steam overlay, and no HDR WSI layer. Setting the variable with no layer to
  consume it does nothing. If HDR is failing on a *native Wayland* path, this is not
  the fix; if you install `vk_hdr_layer`, it becomes relevant.
- **KDE over GNOME for HDR**, and **KDE tone-mapping off**. Consistent with how
  this machine is set up; KDE is what it runs.

### Rules

**Do not change HDR settings to "try things".** Each of the four conditions above
is observable; read the state first and change one thing at a time. A blind sweep
of environment variables is how a working setup becomes a broken one with no record
of what moved.

**Do not add `ENABLE_HDR_WSI=1`, or any other variable from a forum post, to
`95-gaming.conf` without saying so.** That file is the environment every Proton
game inherits. An unexplained variable in it outlives whoever added it.

**`PROTON_ENABLE_WAYLAND=1` has a known cost here**: it is why Hunt jumps to the
desktop on launch; click the game window to get back into it.
Turning Wayland off cures the jump and loses HDR. That trade-off was made
deliberately — do not quietly reverse it.

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

Only these; everything else is independent and can be installed alone. Every arrow
points from a lower number to a higher one, so installing in number order always
finds what each component needs.

```
00-gaming-env ──> 02  (MANGOHUD=1 lives in 95-gaming.conf)
              ──> 03  (the debug-overlay switch lives there too)
02-mangohud-overlay ──> 05, 08  (they add their rows to its MangoHud.conf)
04-prerequisites ──> 05, 07, 08  (packages, kernel modules)
     └─ i2c-dev ──> 05-per-pin-current
     └─ lact    ──> 08-gpu-undervolt, and with it the overlay's VOLTAGE row
```

**The overlay is assembled, not copied.** MangoHud reads one file, but its rows
belong to different components: `02` installs the base overlay, `05` the 12V-2x6
rows, `08` the LACT row (profile + voltage), each as a piece in `~/.config/MangoHud/bazzite-setup.d/`.
Every one of those installers joins the pieces into `MangoHud.conf`. So a row exists
only while its component is installed, and an edit to the live `MangoHud.conf` is
lost at the next reassembly — edit the piece in `NN-*/files/` instead.

If a component you depend on is absent, the dependent one degrades quietly rather
than failing loudly — the overlay has no 12V-2x6 or VOLTAGE rows; if their
component is installed but its feed is not running, the rows go blank.
That is the behaviour to expect, not a bug to chase.

## Hardware that is genuinely specific

| Component | Tied to |
|---|---|
| `05-per-pin-current` | **ROG Astral only.** The IT8915FN is not on other 5090s. Run `sudo astral-pins --probe`; if nothing answers, skip the component — its overlay rows go with it. |
| `08-gpu-undervolt` | the individual card, not the model; and the GPU's LACT id |
| `01-displays` | connector names and monitor modes |
| `07-fan-control` | the board's sensor chip and channel names |
| `02-mangohud-overlay` | the GPU's PCI address |
| `00-gaming-env`, `00-rhi`, `03`, `06`, `09`, `10`, `12`, `14` | nothing — these port as-is |

## Reporting back

State what is installed and **verified running**, what is installed but unverified
and why, and what you deliberately left for the user, including the undervolt. If
`health-check.sh` reports a FAIL you could not resolve, quote it rather than
summarising it. Do not describe a component as working because its installer
succeeded.

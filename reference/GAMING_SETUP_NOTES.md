# Gaming setup — notes

Built from `Claude_Instructions.txt` over three sessions: Sat 12 Sep 2026
evening, and Sun 13 Sep 2026 morning and afternoon.

Machine: Bazzite 44 (Kinoite, KDE Plasma 6.6.4 Wayland), Ryzen 7 9800X3D,
RTX 5090 ROG Astral OC (`1043:89e3`), SAPPHIRE NITRO+ B850M WIFI.

**Everything asked for is done and tested.** Three things are deliberately left
to you: the undervolt values, a live TV Mode test, and whether to try the
gamescope Game Mode session (installed, waiting on a reboot).

If you are re-applying this on a fresh install, start at **`~/bazzite-setup/`**
rather than here. That directory splits everything below into one folder per
component — per-pin current sensing, the overlay, DLSS presets, the DLSS debug
overlay toggle, display switching, fan control, the undervolt, the taskbar — each
carrying the files it needs, an idempotent `install.sh` and a README covering
installation, tuning and the traps. `./install-all.sh` does the lot.
This document stays the long-form story: why each decision was made, what was
measured, what was tried and rejected. The old sequence is still at
[Rebuilding this from scratch](#rebuilding-this-from-scratch) near the end.

---

## Everything, and how it was tested

| # | Item | Status |
|---|------|--------|
| 1 | NVIDIA drivers up to date | **595.71.05 → 610.57.04**, kernel 6.19.14 → 7.2.3 |
| 2 | DLSS version + preset for SR / RR / MFG | `dlss` command + DLSS Updater |
| 3 | DLSS overlay toggle | `dlss overlay on\|off` |
| 4 | Afterburner-style overlay on `/` | MangoHud, matched item-for-item to the Windows OSD |
| 5 | ROG Astral, all 6 currents | all six live in the overlay (`astral-pins`) |
| 6 | Monitor at full 280 Hz | verified, re-pinned on every profile switch |
| 7 | Fan control from the Windows FanControl config | CoolerControl |
| 8 | GPU undervolt tool | LACT |
| 9 | Pause/Break sleeps the displays | KDE global shortcut |
| 10 | Display switching | `display-profile` + 4 launchers |
| 11 | Chrome + Discord | installed and launched |

Second round:

| # | Item | Status |
|---|------|--------|
| 12 | Per-pin sensing redone, on the OSD | `astral-pins`, one block read, all six on screen |
| 13 | Overlay matched to Windows Afterburner | item-for-item from your `MSIAfterburner.cfg` |
| 14 | DLSS overlay toggle on the taskbar, state-reflecting | tray icon, your Windows icons |
| 15 | Display switching on the taskbar | three launchers |
| 16 | Discord on the taskbar | done |
| 17 | SteamOS-style launcher | Big Picture now, Game Mode session after a reboot |
| 18 | Both monitors at the login screen | cause found and fixed |
| 19 | Hunt jumping to the desktop | KWin rule; class regex is a best guess |
| 20 | Performance trim | 6.1 s off boot, ~220 MB back |
| 21 | Documentation | this file |
| 22 | NvTrueHDR for Linux (27 Sep 2026) | `nvtruehdr` — own SDR→HDR Vulkan layer; see [below](#nvtruehdr--rtx-hdr-style-sdrhdr-27-sep-2026) |

Nothing here is "it should work" — each was checked against the hardware:

- **`/` toggle** — `vkcube` under MangoHud on XWayland, a real `KEY_SLASH`
  injected at the kernel level while the window held focus, screenshots either
  side. Hides, and comes back on the second press. A deliberately bogus keybind
  was tried first to prove MangoHud rejects bad keys loudly; `slash` is accepted.
- **280 Hz** — `vkcube` in FIFO reported exactly 280 FPS / 3.6 ms.
- **Display profiles** — switched to Desk Work and back, geometry, priority and
  mode confirmed each time against the Windows layouts.
- **Pause key** — real `KEY_PAUSE` injected; DPMS went `on → off`.
- **`dlss`** — every subcommand run; resulting environment confirmed on the
  *live* Steam process via `/proc/<pid>/environ`.
- **Fan curves** — CPU driven to 80 °C under load; duty tracked the ported curve
  to within a percent (see below).
- **12V-2x6 currents** — cross-checked against nvidia-smi: 44.0 A × 12.1 V =
  532 W vs the 532.77 W the card reported. The block-read rewrite was checked
  byte-for-byte against the old read path on the same chip, timed over 10 runs
  each, and the warning marker forced by running with `--warn 0.1`. Currents
  tracked GPU load: 1.6 A idle → 5.1 A with four `vkcube` instances → 2.1 A.
- **Overlay layout** — every variant screenshotted with `vkcube` + `spectacle`
  and read back. That is how the `cpu_stats` coupling, the two-GPU listing, the
  one-line overflow and the dead `0 mV` voltage row were all found.
- **Chrome / Discord** — both launched and rendered.

---

## The commands

Three desktop icons — **Desk Gaming**, **Desk Work**, **TV Mode** — using your
own Windows `.ico` artwork, plus the same three in the app menu. Or from a shell:

```
display-profile gaming | work | tv | dell | status
dlss status                                   # what's set right now
dlss sr K       dlss sr latest    dlss sr off # Super Resolution preset (A-O)
dlss rr latest                                # Ray Reconstruction preset
dlss mfg 4x     dlss mfg auto     dlss mfg off# Frame Gen / Multi Frame Gen
dlss overlay on | off                         # NVIDIA's DLSS / DLSS-G indicator
dlss dlls                                     # opens DLSS Updater (DLL versions)
dlss launch-options                           # same settings for ONE game, to paste into Steam
dlss reset                                    # back to app-controlled
```

In game: **`/`** toggles the overlay. `Shift_L+F1` cycles the frame limiter,
`Shift_L+F2` logs to `~/mangohud-logs`, `Shift_L+F4` reloads the config.
GOverlay is installed if you would rather edit the overlay in a GUI.

DLSS settings are global, applied to every Proton game. **Fully quit Steam and
start it again** for a change to reach your games.

---

## Fan control — CoolerControl

The Windows FanControl config was decoded and rebuilt exactly:

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

Measured under load: Tctl 78.0 °C → PWM 110 (43 %; the curve asks for 44 %),
79.8 °C → PWM 125 (49 %; curve says 50 %). The Max mix behaved correctly — the
CPU curve overrode the GPU curve. Back to PWM 66 at idle.

`nct6775` was not loading at all before, which is why no motherboard fan sensors
existed on this machine. It now loads at boot via
`/etc/modules-load.d/nct6775.conf`.

To rebuild this from scratch (after a CoolerControl reset, say):
`python3 ~/.local/share/gaming-setup/apply-fan-curves.py` — it is idempotent.
GUI: **CoolerControl** in the app menu.

---

## 12V-2x6 per-pin currents — astral-pins

Replaced `vhpwr-guard` on 2026-09-13. That tool worked, but it could only read
the chip a byte at a time — 24 separate SMBus transactions, ~35 ms on the GPU's
own I2C bus per sample — which is invasive enough to hitch frame pacing. It had
to be throttled to one sample every 5 s to stay out of the way, and the overlay
only got a summary line rather than the six figures.

**`/usr/local/bin/astral-pins`** (C, source kept at
`/usr/local/src/astral-pins/astral-pins.c`) reads all 24 bytes in **one**
`I2C_SMBUS_I2C_BLOCK_DATA` transaction. Measured on this card:

| method | time per sample | notes |
|---|---|---|
| byte-at-a-time SMBus | 34.6 ms | what vhpwr-guard used |
| **one block read** | **4.5 ms** | what astral-pins uses |
| combined I2C_RDWR | 5.0 ms | adapter ACKs it but returns garbage — unusable |

That is 7.7× cheaper, so it can sample **once a second** and still disturb the
bus far less than the old 5 s polling did (0.45 % duty vs 0.7 %, and each
individual stall is 8× shorter).

The chip is an ITE **IT8915FN on i2c-7 @ 0x2b**. Register 0x80 holds six
`[mV hi][mV lo][mA hi][mA lo]` groups, big-endian, highest pin first. The bus is
autodetected at startup by trying every NVIDIA adapter and keeping the first one
that decodes to a live 12 V rail.

**In the overlay:** two rows under `12V PINS`, pins 0–2 then pins 3–5. Two rows
because MangoHud renders only the last line an `exec` prints, and six figures on
one line overrun the overlay and collide with their own label. `!!` appears on
the end of the first row if any pin passes 9.0 A.

The daemon writes three tmpfs files, so the overlay side is just a file read:

```
/dev/shm/astral-pins        8.12 8.03 7.94 8.20 8.31 7.85  =48.4A   for scripts
/dev/shm/astral-pins.pin1   8.12                                    overlay row
...
/dev/shm/astral-pins.pin6   7.85 !!                                 over the limit
```

**`/dev/shm`, not `/run` — this matters.** Steam runs games inside a
pressure-vessel container that has its **own `/run`**, so a file written to
`/run/` on the host does not exist as far as any Steam game is concerned, and
the overlay rows come out blank in games while looking perfect on the desktop.
`/dev/shm` is passed straight through (checked from inside the container, in
both directions) and is still tmpfs, so there is no disk traffic. `/tmp` and
`$HOME` are shared too; `/run/user/1000` is **not**.

```bash
sudo astral-pins --status      # one decoded reading, volts and amps per pin
cat /dev/shm/astral-pins       # what the overlay is showing
sudo astral-pins --probe       # every NVIDIA bus and what it answers
journalctl -u astral-pins -f   # warnings
systemctl restart astral-pins
```

### The alarm

Crossing 9.0 A on any pin does three things at once: the marker appears on that
pin's overlay row, a line goes in the journal, and the service runs
**`/usr/local/bin/astral-pins-alarm`**, which puts a *critical* desktop
notification and **three alarm tones** into your session. It repeats every 30 s
while the condition lasts, and plays a single chime with an "all clear"
notification when the current drops back.

The tone is `dialog-warning.oga` (0.5 s) four times over, not
`alarm-clock-elapsed.oga`, which is 6 s a go — three of those is 18 s out of
every 30, which is unbearable rather than useful.

Sound rather than notification alone because a full-screen game usually swallows
notifications; audio always gets through.

The alarm script runs as root but has to reach your desktop, so it looks up
whoever holds the seat0 session with `loginctl` and drops to them with the right
`XDG_RUNTIME_DIR` and D-Bus address. It does not hardcode uid 1000.

#### Two traps, both of which make the alarm look like it worked

**Never put `ProtectHome=yes` on astral-pins.service.** It hides `/home`, `/root`
*and `/run/user`* — and `/run/user/$uid` is where both the D-Bus session socket
and the PipeWire/Pulse socket live. With it set, `notify-send` and `paplay` fail
with "Permission denied" and "Connection refused", but the daemon still logs
`ALARM pin N` and still marks the overlay, so from the outside it looks like the
alarm fired and the desktop just ignored it. There is a comment in the unit file
and a check in the script that says so out loud now.

**The alarm command has to be run as `sh -c '<cmd> "$@"'`, not `sh -c '<cmd>'`.**
Without the explicit `"$@"` the positional arguments go nowhere and the alarm
reports its pin as `?`. The state, pin and current are now also passed as
`ASTRAL_STATE`, `ASTRAL_PIN` and `ASTRAL_AMPS` so either style works.

Every step of the script reports its exit code to the journal, deliberately — a
silent failure here is indistinguishable from there being nothing wrong:

```
astral-pins: ALARM pin 6 at 6.54 A (limit 6.0 A)
astral-pins-alarm: alarm notification rc=0 (pin 6, 6.54 A)
astral-pins-alarm: alarm sound rc=0 (4x)
```

Proven in a real session on 2026-09-13: the level was dropped to 6.0 A so the
alarm would fire during ordinary gaming, it fired on pin 6, the notification and
the tones both landed, and it was put back to 9.0 A afterwards.

```bash
# fire the alarm on demand, to check sound and notifications still work
sudo astral-pins --test-alarm --alarm-command /usr/local/bin/astral-pins-alarm

# or lower the level temporarily and let a real load trip it
sudo mkdir -p /etc/systemd/system/astral-pins.service.d
printf '[Service]\nExecStart=\nExecStart=/usr/local/bin/astral-pins --daemon \\\n  --interval 1 --warn 6.0 --output /dev/shm/astral-pins \\\n  --alarm-command /usr/local/bin/astral-pins-alarm --alarm-repeat 30\n' \
  | sudo tee /etc/systemd/system/astral-pins.service.d/50-test-warn.conf
sudo systemctl daemon-reload && sudo systemctl restart astral-pins
# ...and to undo it, delete that file and daemon-reload + restart again.
```

Tunables, all in `/etc/systemd/system/astral-pins.service`:
`--warn` the level, `--alarm-repeat` how often it re-fires (0 = once only),
`--alarm-command` what it runs. It clears at `--warn` minus 0.5 A so a pin
sitting exactly on the line cannot chatter.

**Warning only — it will not power the machine off.** vhpwr-guard's shutdown
path is gone on purpose; a warning was all that was wanted. The 9.0 A level sits
above the ~8.9 A a peak pin naturally reaches at the card's 600 W cap, so it will
not cry wolf during normal gaming, and well under the ~9.5 A sustained figure
that is the documented melting regime.

Your pin balance is healthy. At 534 W the six pins carried
7.30 / 7.00 / 7.28 / 7.68 / 7.50 / **7.94** A — peak only 6.6 % above average.
Sanity check against the card's own telemetry: 44.0 A × 12.1 V = 532 W, and
nvidia-smi said 532.77 W.

Files removed with the old tool: `/usr/local/bin/vhpwr-guard.py`,
`/etc/systemd/system/vhpwr-guard.service`, `/run/vhpwr-guard.osd`.

---

## Performance overlay — MangoHud, matched to the Windows Afterburner OSD

Rebuilt on 2026-09-13 to show exactly what MSI Afterburner shows on the Windows
install, no more. The source of truth is the `[Source *]` sections with
`ShowInOSD=1` in

```
/run/media/lee/9AD6814BD6812919/Program Files (x86)/MSI Afterburner/Profiles/MSIAfterburner.cfg
```

(not the `MSIAfterburner.cfg` in the install root — that one is stock and has an
empty `[Monitoring]` section). Thirteen items are on there:

GPU temperature, GPU usage, GPU memory usage, GPU core clock, GPU power, GPU
voltage, CPU temperature, CPU power, RAM usage, Framerate, Frametime, Framerate
1 % Low, Framerate 0.1 % Low. Frametime is the only one with `OSDItemType=1`,
meaning text plus a graph; the rest are text.

Three things are worth knowing about the translation:

* **CPU usage cannot be hidden.** Afterburner has it off. MangoHud draws usage,
  temperature and power on one row and drops the whole row if `cpu_stats` is
  off — verified by screenshot, turning it off took CPU temp and power with it.
  So the percentage stays.
* **GPU voltage comes from LACT, not MangoHud.** MangoHud reads NVIDIA cards
  through NVML, and driver 610.57.04 has no voltage API — no voltage symbol in
  `libnvidia-ml.so.1` at all, and `nvidia-smi -q -d VOLTAGE` prints an empty
  section. MangoHud's own `gpu_voltage` would be a permanent `0 mV` row, so it
  stays off. LACT gets the figure through NvAPI instead, so
  `gpu-voltage.service` (a user service, `~/.local/bin/gpu-voltage`) runs
  `lact cli stats` once a second and publishes the answer to
  `/dev/shm/gpu-voltage.mv`, which the overlay `cat`s as a `VOLTAGE` row — the
  same pattern as the peaks and the 12V-2x6 pins, and for the same two reasons:
  one stats query costs ~16 ms (fine once a second, not at MangoHud's refresh
  rate), and Steam's pressure-vessel container has no `lact` binary inside it.
* **GPU memory clock** is `gpu_mem_clock`, added by request. It needs `vram`
  enabled or MangoHud drops it silently, and it shares the VRAM row rather than
  getting a labelled row of its own. It agrees with LACT — 405 MHz idle and
  810 MHz under light load on both, checked side by side.

**The `lact cli` trap, which cost a wrong reading once already.** `lact cli
stats` with no `-g` silently selects GPU 0 — the Radeon iGPU in the 9800X3D —
and prints *its* voltage and clocks without warning. The numbers look perfectly
plausible (~1170 mV) while having nothing to do with the 5090, which is how the
voltage row shipped wrong. Always pass
`-g 10DE:2B85-1043:89E3-0000:01:00.0`, and note it is a flag on `lact cli`, not
on `stats`, so it goes *before* the subcommand: `lact cli -g <id> stats`.
* **Only the 5090 is listed**, via `pci_dev=0000:01:00.0`. Index 0 is the Radeon
  iGPU in the 9800X3D, and Afterburner hides its first GPU the same way (`GPU1
  temperature` has `ShowInOSD=0`). Selected by PCI address rather than
  `gpu_list=1` because the index depends on enumeration order, which is not
  guaranteed to match inside Steam's container. If the selector ever points at
  nothing, MangoHud silently drops the GPU and VRAM rows and keeps everything
  else — so a missing GPU row means that line, not a broken overlay.

**Position** is the `position=` line: `top-left`, `top-center`, `top-right`,
`middle-left`, `middle-right`, `bottom-left`, `bottom-center`, `bottom-right`.
Shift_L+F11 cycles it in-game. The order blocks appear in the config file is the
order they appear on screen, so moving the 12V-2x6 block above the GPU section
puts the pin currents at the top — verified by screenshot.

Colours come from Afterburner's "modern" layout (`OSDLayout = 1`): GPU group
`008040`, CPU group `0080C0`, framerate group `C08080`, values white.

The one addition Afterburner has no equivalent for is the `12V PINS` block.
GPU memory clock is the other non-Afterburner row.

Previous config kept at `~/.config/MangoHud/MangoHud.conf.bak-preAfterburner`.
Per-frame auto-logging (`autostart_log`) is back off; Shift_L+F2 still logs on
demand.

---

## GPU undervolt — the tool is LACT

**LACT** (`lact` in the app menu, or `lact gui`). The `lactd` daemon runs at
boot. It identifies the card as *ASUS RTX 5090 ASTRAL OC* on driver 610.57.04.

Under **Overclocking** you get the full set, which is everything Afterburner
gives you on Windows:

- **Power cap** — 400 W to 600 W
- **GPU clock offset** — per power state, -1000 to +1000 MHz
- **Memory clock offset** — -2000 to +6000 MHz
- **Max / min core clock** — i.e. locked clocks
- **Voltage boost** — 0 to 100
- **The V/F curve itself** — per-point frequency and voltage, so you can do a
  proper curve undervolt rather than just an offset

For reference, the stock curve on your sample runs
2700 MHz @ 975 mV, 2917 MHz @ 1050 mV, and tops out at 3135 MHz @ 1170 mV.

LACT has profiles, so you can keep a stock profile alongside a tuned one and
switch between them. Anything you set is reversible — Revert in the GUI, or
`lact cli` reset. **Nothing has been changed; the card is at stock.**

Undervolting also buys 12V-2x6 headroom: dropping from 600 W to ~480 W takes the
peak pin from ~8.9 A to ~7.1 A.

---

## The taskbar

Seven launchers were added to the Icons-Only Task Manager, left to right after
the menu button:

| Icon | What it does |
|---|---|
| Steam | as before |
| **Big Picture (in desktop)** | `bazzite-steam-bpm` — the console-style interface as a window on this desktop, no logout. Named to distinguish it from the *session* called "Steam Big Picture" at the login screen, which is the real gamescope one. |
| Lutris | as before |
| **Discord** | the flatpak |
| Chrome | as before |
| **Desk Gaming / Desk Work / TV Mode / Dell Only** | the four `display-profile` layouts |
| Konsole, Files, Bazaar, yafti | as before |

Launchers live in `~/.local/share/applications/`. The list itself is the
`launchers=` line under `[Containments][4][Applets][7][Configuration][General]`
in `~/.config/plasma-org.kde.plasma.desktop-appletsrc`.

**Editing that line needs plasmashell restarted to take effect**
(`systemctl --user restart plasma-plasmashell.service`). Writing it through
Plasma's live scripting API and calling `reloadConfig()` updates the file but
does *not* repopulate the applet, and trying to force it by removing and
re-adding entries left the panel showing a single blank placeholder. Both were
tried. Edit the file, restart the shell.

### The DLSS overlay toggle is a tray icon, and ONLY a tray icon

Windows' `Toggle-DlssOverlay.ps1` flips a registry value and then repoints its
own shortcut at `dlss-on.ico` / `dlss-off.ico`, so the icon always shows the
current state. **That trick does not work on Plasma.** The task manager caches a
launcher's icon and only re-reads the `.desktop` file when plasmashell restarts,
so a pinned launcher sits there showing the wrong state until the next login —
confirmed by screenshot, twice.

So the state indicator is a **system tray icon** instead:
`~/.local/bin/dlss-overlay-tray`, a small PySide6 StatusNotifierItem started from
`~/.config/autostart/dlss-overlay-tray.desktop`.

* **Left click** toggles the overlay.
* **Right click** gives explicit on/off and a "Show DLSS settings" window.
* The icon changes **instantly**, and also follows changes made elsewhere — run
  `dlss overlay on` in a terminal and the tray icon updates, because it watches
  `95-gaming.conf` with a `QFileSystemWatcher`.

The icons are the actual Windows ones, converted out of the two `.ico` files in
`ConfigUtils/scripts/DlssOverlay/icons/` into
`~/.local/share/icons/hicolor/*/apps/dlss-overlay-{on,off}.png` at all eight
sizes the `.ico` contained.

It costs about 80 MB of RAM, which is the price of a live indicator; nothing
else on the system can redraw a panel icon on demand.

`~/.local/bin/dlss-overlay-toggle` also exists and does the same job from the
command line or the application menu. It still rewrites its own `.desktop` icon,
Windows-style, which is correct but only visible after a relogin.

**Do not pin `dlss-overlay-toggle.desktop` to the panel.** For a while it was
pinned *and* the tray icon was running, and the two disagreed: clicking either
one changed the state, but only the tray icon redrew, so whichever you had not
used showed the wrong thing. One control, in the tray.

That happened because an edit to `launchers=` was made while plasmashell was
running, and plasmashell wrote its own in-memory copy back over the file later —
taking the removal with it, and a couple of unrelated launchers as well. **Stop
plasmashell before editing that file**, not just afterwards:

```bash
systemctl --user stop plasma-plasmashell.service
# edit launchers= now
systemctl --user start plasma-plasmashell.service
```

> Careful: bare **`dlss overlay` TOGGLES**. The read-only one is
> `dlss overlay status`. That caught me out once mid-session.

---

## Game Mode (the SteamOS-style session)

Two levels of this, and you now have both.

**Big Picture, right now, no reboot** — the *Big Picture (in desktop)* launcher
on the taskbar. This is Steam's console interface running as a window on the desktop.
It uses `bazzite-steam-bpm` rather than Steam's own in-client button, because
switching to BPM from inside the client is
[known to be sluggish on Bazzite](https://github.com/ublue-os/bazzite/issues/1675).

**The real Game Mode session, after a reboot.** `gamescope-session-steam` has
been layered with rpm-ostree and is **staged for next boot**:

```
Added:
  gamescope-session-0~20260911git.72da801-1.fc44
  gamescope-session-steam-0~20260803git.55e541a-1.fc44
```

After you reboot, the login screen gets a session picker with a second entry
alongside Plasma. **It is called "Steam Big Picture", not "Game Mode"** — that
is the `Name=` in the session file the package ships, and it is easy to walk
past if you are looking for the words "Game Mode". Verified present:

```
$ grep -h ^Name= /usr/share/wayland-sessions/*.desktop
Name=Plasma
Name=Steam Big Picture
```

Picking it gives the full SteamOS experience:
gamescope compositing the whole session, Steam in Big Picture as the shell,
per-game TDP and refresh controls. Your desktop session is untouched and stays
the default — this only adds a choice.

To remove it again: `sudo rpm-ostree uninstall gamescope-session-steam` and
reboot. To back out the whole staged deployment before you ever boot it:
`sudo rpm-ostree cleanup -p`.

---

## Passwordless login — tried, then reverted on purpose

Autologin was set up and then **taken back out**, because it costs you the
session picker: with autologin on, boot goes straight into Plasma and never
shows the login screen, and the login screen is the only place **Game Mode**
appears. Having the choice at every boot was worth more than skipping a password
prompt.

Nothing is left behind. `/etc/plasmalogin.conf.d/10-autologin.conf` is deleted
and `/etc/plasmalogin.conf` was never edited — every key in its `[Autologin]`
section is still commented out as shipped.

If you ever want it back, and are happy to log out to reach Game Mode:

```bash
sudo tee /etc/plasmalogin.conf.d/10-autologin.conf <<'EOF'
[Autologin]
User=lee
Session=plasma.desktop
Relogin=false
EOF
sudo systemctl reboot
```

Keep `Relogin=false`: with it off, logging out still drops you back at the login
screen, which is the only way to reach the session picker.

Two things learned while doing it, worth keeping:

* **Do not restart `plasmalogin.service` to test autologin while you are logged
  in.** It immediately starts a second Plasma session on VT1 while your real one
  sits invisible on VT2. Nothing is lost — the second session cannot start a
  compositor and gives up — and `sudo chvt 2` brings you back, but it is
  alarming. Autologin only ever needs to work at boot; reboot to test it.
* **Autologin breaks KWallet unlocking**, which is worth knowing if you ever turn
  it on. PAM normally unlocks the wallet with the password you type; with no
  password typed the journal says `pam_kwallet5: open_session called without
  kwallet5_key`, and you get a prompt the first time something wants a stored
  secret. The companion change is to set the wallet password to empty in
  KWalletManager.

---

## Two things that were bugging you

### Both monitors light up at the login screen, then drop to one

Not a bug, and not your session's doing. The login screen is **plasmalogin**,
which runs as its own user (`plasmalogin`, home `/var/lib/plasmalogin`) with its
own display configuration. Yours said one monitor; the greeter's said three:

```
GREETER   HDMI-A-2 enabled=True   DP-4 enabled=True   HDMI-A-3 enabled=True
SESSION   HDMI-A-2 enabled=False  DP-4 enabled=True   HDMI-A-3 enabled=False
```

So everything connected lit up for the login prompt, and the moment your session
started, KWin applied your layout and switched the other two off.

**Fixed** by copying the `setups` block out of your
`~/.config/kwinoutputconfig.json` into
`/var/lib/plasmalogin/.config/kwinoutputconfig.json`. The two files list outputs
in the same order, which the script asserts before trusting it. Original saved
as `kwinoutputconfig.json.bak-allon` next to it.

This takes effect at the next boot, so it is not verified yet. If a monitor is
ever unplugged, KWin will not find a matching setup and falls back to enabling
everything, so this cannot lock you out of a login screen.

If you change your desk layout later, re-run the same copy or just delete the
greeter's file to go back to "everything on".

### Hunt drops to the desktop on launch

Almost certainly a side-effect of `PROTON_ENABLE_WAYLAND=1`, which is there for
HDR. The game presents through Wayland directly now instead of XWayland, and its
window is mapped before it is activated, so KWin keeps focus on whatever was in
front — the desktop.

A KWin rule now covers it, in `~/.config/kwinrulesrc`:

```ini
[hunt-focus]
wmclass=(?i).*(hunt.?showdown|huntgame|steam_app_594650).*
wmclassmatch=3          # regex
fsplevel=0              # focus stealing prevention: None
fpplevel=4              # focus protection: Extreme
```

`fsplevel=0` lets the game grab focus the instant it maps; `fpplevel=4` stops
anything pulling focus back off it while it is still starting.

The class regex is a **guess covering the three plausible names**, because the
window class could not be read without the game running. If it still misbehaves,
launch Hunt, run **`window-info`**, and read the exact `resourceClass` off the
Windows tab of the debug console that opens — then narrow the rule to it.

`window-info` opens KWin's own debug console because under Wayland there is no
`xprop` equivalent. Reporting from a KWin script was tried first and does not
work: `print()` output is dropped unless the `kwin_scripting` debug category is
enabled, and `callDBus` out to the notification service is not permitted for
scripts loaded that way.

---

## What was trimmed, and what was left alone

You asked for a system that just works without carrying weight it does not need.

**Removed:**

| Change | Why | Gain |
|---|---|---|
| `NetworkManager-wait-online.service` disabled | Holds `graphical.target` until the network is up. A desktop does not need to wait. | **6.1 s off every boot** — it was the single slowest unit |
| `displaylink.service` disabled | No DisplayLink hardware on this machine (`lsusb` finds none) | one less daemon, ~12 MB |
| Plasma virtual keyboard off | No touchscreen. `InputMethod=` blanked in `kwinrc` under `[Wayland]`. | **~210 MB** |

Boot before the change: 38.7 s total — 16.8 s firmware, 3.2 s bootloader, 2.5 s
kernel, 6.4 s initrd, 9.7 s userspace. Most of that is firmware, which is a
motherboard setting, not something Linux controls. Userspace should now be
around 3.6 s.

The virtual keyboard change **takes effect at the next login**. KWin respawns it
for the rest of the current session no matter what, and the only way to verify
live would be to restart the compositor, which kills the session.

**Deliberately left alone:**

* **`cardwired`** — 130 MB, and the most tempting thing on the list. It is
  Bazzite's GPU manager, using eBPF LSM hooks to hide GPUs from applications.
  Currently in `Hybrid` mode with nothing blocked, so it looks inert — but it is
  plausibly what keeps games on the 5090 rather than the Radeon in the 9800X3D,
  and a wrong GPU in a game is a far worse outcome than 130 MB of idle RAM.
  `cardwire list` shows the state. Disable with
  `sudo systemctl disable --now cardwired` if you ever want the memory back.
* **CPU governor** — `amd-pstate-epp` driver, `powersave` governor, EPP
  `balance_performance`. This reads alarming and is not: with `amd-pstate-epp`,
  `powersave` is the normal active mode and boosts properly. Setting EPP to
  `performance` is the tweak if you want clocks to ramp more eagerly:
  `echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference`.
  Not applied, because the gain is small and unmeasured, and it costs idle power
  and heat all the time.
* **Baloo file indexer** — running, but it has indexed 12 files in total and
  sits idle. Nothing to gain. `balooctl6 disable` if you want it gone.
* **auditd, greenboot, firewalld** — security and the ostree rollback safety
  net. Not worth trading for nothing.

Zero failed units. zram is 15.2 GB with zstd, which is right.

---

## The games drive — /mnt/games

The "2nd SSD" NTFS partition (`nvme0n1p4`, 628 GB, 68% full) now mounts itself at
boot instead of being left to udisks:

```
UUID=182EFF0A2EFEDFA4 /var/mnt/games ntfs3 uid=1000,gid=1000,umask=022,noatime,nofail,x-systemd.device-timeout=10s 0 0
```

Reachable as **`/mnt/games`** — on an ostree system `/mnt` is a symlink to
`/var/mnt`, so fstab has to name the canonical path or systemd complains about a
non-canonical target. Both paths work for you.

Three reasons not to leave it on the old `/run/media/lee/2nd SSD`:

* udisks mounts it only when something asks, which is **not guaranteed to be
  before Steam autostarts** at login — a shortcut into it would just fail.
* that path has a **space** in it, which is a permanent nuisance in Steam launch
  options and scripts.
* it was mounted `fuseblk`, i.e. the ntfs-3g FUSE driver. The in-kernel `ntfs3`
  driver is faster, measured on this drive with caches dropped between runs:

| driver | sequential read |
|---|---|
| **ntfs3** (in-kernel) | **4.0 GB/s** |
| ntfs-3g (fuseblk) | 2.5 GB/s |

`nofail` plus a 10 s device timeout means a missing or dirty drive can never stop
the machine booting. Verified by stopping and starting `var-mnt-games.mount`,
which is the unit systemd generates from that fstab line and the same path boot
takes; it is `WantedBy=local-fs.target`.

Files come out owned by `lee:lee`, mode 755, so executables are directly
runnable. Old `/etc/fstab` saved next to it as `fstab.bak-<timestamp>`.

**If Windows leaves it dirty, it will mount read-only or not at all.** Windows
Fast Startup hibernates rather than shuts down, and NTFS then carries a dirty
flag that `ntfs3` refuses to write over. This machine's Windows partition has a
`hiberfil.sys`, so Fast Startup is very likely on. Turning it off in Windows is
the fix. As a one-off recovery, booting Windows and shutting down properly clears
the flag.

### What is on it

| Path under `/mnt/games/Games/` | Needs |
|---|---|
| `RESIDENT EVIL 4/re4.exe` | Proton |
| `Resonance.A.Plague.Tale.Legacy/.../game/Resonance.exe` | Proton |
| `The Blood of Dawnwalker/Dawnwalker/Binaries/Win64/Dawnwalker.exe` | Proton (UE5) |
| `BB Launcher (Linux) - shadPS4 ...` | **native Linux**, no Proton |
| `Cemu_2.2` + `wiiUGames` (drive root) | Cemu has a native Linux build |

**Resident Evil 4 is RE Engine, same as Pragmata.** If ray tracing is greyed out
there too, it is the same Wine-detection lockout — add
`%command% /WineDetectionEnabled:False` to its launch options.

### Saves do not carry over from Windows

Two separate reasons, both worth being clear about:

* **Steam Cloud does not apply.** It only covers games in your Steam library that
  support it. A non-Steam shortcut gets nothing from Cloud, regardless of whether
  the game supports it when bought on Steam.
* **The save paths are different places.** On Windows these write to
  `C:\Users\lee\Documents\...` or `AppData` on the Windows partition. Under
  Proton, Documents and AppData live *inside that game's prefix*, at
  `~/.local/share/Steam/steamapps/compatdata/<id>/pfx/drive_c/users/steamuser/`.
  Nothing connects the two, so each game starts fresh.

To bridge it, either copy the Windows saves in once, or symlink the prefix's save
folder at the Windows one. A symlink needs the Windows partition mounted at boot
as well, and Fast Startup off, or the game will fail to save.

**One exception, already shared.** `savedata/1/CUSA00207/SPRJ0005` at the drive
root is Bloodborne's PS4 save data (`CUSA00207`). If the Linux shadPS4 build on
that drive points at the same user folder, those saves are common to both OSes.
Cemu is the same if pointed at one `mlc01`.

### Not free space

`nvme1n1p5` is a **136 GB ext4 partition, 60% full, holding an old Linux install**
(`/bin`, `/etc`, `/home`). Left untouched and unmounted. Noted here because 53 GB
free on a forgotten partition is exactly the sort of thing that gets reclaimed by
accident.

---

## ReShade and RenoDX

Installed with **`reshade`** (`~/.local/bin/reshade`), a thin wrapper around
kevinlekiller's `~/reshade-linux.sh`. The wrapper exists to stop two mistakes
that both fail silently.

**1. Add-on support must be on.** The upstream script defaults to
`RESHADE_ADDON_SUPPORT=0`, which fetches the *limited add-on functionality*
build. That build loads ReShade perfectly, compiles every shader, and quietly
skips third-party add-ons like RenoDX, logging only:

```
WARN | Skipped loading add-on from '...renodx-ue-extended.addon64'
       because this build of ReShade has only limited add-on functionality.
```

Worse, `~/.local/share/reshade` is **one shared copy symlinked into every game**,
and the script switches it *back* to the limited build if run without the
variable. One forgetful run silently breaks RenoDX everywhere. The wrapper always
sets it; override deliberately with `RESHADE_ADDON_SUPPORT=0 reshade`.

The two builds are told apart by size: **5,592,064** bytes is the add-on build,
5,255,448 the limited one. The add-on build fetched here is MD5-identical to the
ReShade installed from Windows that already loads RenoDX.

**2. Unreal Engine games need the SHIPPING exe's folder.** The script asks for
"the folder path where the main executable is" and takes what you give it. An
Unreal game's root holds a small launcher shim — `MortalShell2.exe` is 311 KB —
while the renderer is `MortalShell2/Binaries/Win64/MortalShell2-Win64-Shipping.exe`
at 196 MB. A proxy DLL is resolved relative to the *executing* binary, so ReShade
installed in the root gets loaded by the shim, does nothing, and writes no log at
all. The script has no Unreal awareness whatsoever — grep it for `Binaries`,
`Win64`, `Shipping` or `Unreal` and there are zero matches. The wrapper prints a
reminder every run.

**Diagnosing it:** the absence of `ReShade.log` means ReShade never loaded — wrong
directory. A log that exists tells you the rest. That one file identified both
failures here in seconds, after much longer spent inspecting processes.

### Current state

| Game | ReShade | Notes |
|---|---|---|
| Mortal Shell II | symlinked to the shared add-on build | `dxgi.dll` points at `reshade/latest`, so future updates follow with no game-folder edits |
| A Plague Tale (Resonance) | its own copy, from Windows | unaffected by the shared install |
| The Blood of Dawnwalker | its own copy, from Windows | unaffected |

Only symlinked games follow the shared build. Per-game copies, like the two
installed from Windows, are independent — which is the way to keep one game on a
different build from another.

**Anticheat:** the add-on build can look like cheating software. Single-player
only. Never point it at Hunt.

**Keep `PROTON_ENABLE_WAYLAND=1`** for RenoDX titles. It is what carries RenoDX's
HDR output to the display; without it the compositor tone-maps the result back
down to SDR and the whole exercise is wasted.

---

## nvtruehdr — RTX HDR style SDR→HDR (27 Sep 2026)

NvTrueHDR for Linux. Enable it per game from a command, tune it in a text file,
and changes show in the running game within a frame. No overlay involved.

**Real RTX HDR does not exist on Linux yet.** Driver 610.57.04's NGX library
knows the `TrueHDR` feature and looks for `libnvidia-ngx-truehdr.so`, but NVIDIA
does not ship that model for Linux. A probe against the driver returned
`TrueHDR.Available = 0`. So `nvtruehdr` is its own implementation: a Vulkan
layer that swaps the game's swapchain for an HDR10 one and runs an inverse tone
mapper (peak, middle grey, contrast, saturation, four quality levels = debanding
strength, HUD squares) at present time.

```bash
nvtruehdr                                  # like NvTrueHDR.exe: drag the .exe in, pick an action
nvtruehdr "Game.exe" high                  # low | medium | high | veryhigh | hud | disable
nvtruehdr set "Game.exe" middle_grey 60    # live, while the game runs
nvtruehdr set "Game.exe" split_screen 0.5  # left half plain SDR, for comparing
nvtruehdr status | doctor | list | edit
```

Or `NVTRUEHDR=1 %command%` in Steam launch options instead of a profile.
Settings: `~/.config/nvtruehdr/nvtruehdr.conf` (`[global]` + one `[Game.exe]`
section per game). Source, README and build: `~/nvtruehdr/`.

**Tested on this machine:**
* `vkcube` (native Vulkan), a D3D11 program (DXVK) and a D3D12 program
  (VKD3D-Proton), the last two through GE-Proton 11-6 inside Steam Linux
  Runtime 4, the same path a Steam game takes.
* Frame dumps checked against the reference curve: median error 0.3–0.5%.
  SDR white → 452 nits and 18% grey → 50.8 nits with peak 450 / middle grey 50.
* Live reload: settings changed mid-run and showed up in the next dumped frame,
  inside the Proton container too.
* Debanding: on a dark sky gradient, rows with a visible step went from 33
  (Low) to 5 (VeryHigh).
* Cost at 2560×1440: 0.02–0.04 ms a frame, depending on quality.

**Things to know:**
* Needs native Wayland presentation. `PROTON_ENABLE_WAYLAND=1` is already
  session-wide. On XWayland the layer logs "surface offers no HDR format" and
  leaves the game alone.
* Games that output HDR themselves are left alone. The layer only takes over
  an SDR swapchain.
* **MangoHud load order was changed.** MangoHud 0.8.4 has no HDR support. Below
  nvtruehdr it would draw SDR values into the HDR10 image and its text would be
  blinding. Symlinks in `~/.config/vulkan/implicit_layer.d/` (searched first)
  load it above nvtruehdr, so the overlay is drawn on the game's SDR image and
  converted with it. Verified inside Steam's container. `install.sh --uninstall`
  removes the symlinks.
* The HUD squares sit top-right (`hud_position`) because MangoHud is top-left.
* On the AOC (450-nit peak, KDE SDR brightness 450) the gain is mostly contrast.
  Mid-tones sit lower than on the SDR desktop and highlights reach 450. Raise
  `middle_grey` (e.g. 70–80) for a brighter picture. The Philips OLED TV has
  more headroom.
* OpenGL games are not covered.
* **Never enable it for Hunt.** It is a Vulkan layer outside the Windows
  process, so EAC shouldn't see it, but the same rule as ReShade applies.

---

## Non-Steam games

Nothing here is set up for you, because there is nothing installed to set it up
for. This is the route when you want one.

**The important part:** the gaming environment in
`~/.config/environment.d/95-gaming.conf` — MangoHud, the DLSS overrides, HDR,
Wayland — is applied to **your whole session**, not just Steam. Anything you
launch inherits it, including Lutris, Heroic and a bare `wine` command. That was
a deliberate choice after Steam's autostart entry turned out to bypass the
launcher wrapper.

**Adding a non-Steam game to Steam** (simplest, keeps Proton, MangoHud, the
overlay and controller support):

```bash
steamos-add-to-steam /path/to/Game.exe      # Bazzite ships this
```

Then in Steam: Properties → Compatibility → tick "Force the use of a specific
Steam Play tool" → pick **GE-Proton11-6** if the game wants HDR or a DLSS
override, otherwise leave it on stock Proton so Valve's pre-built shader caches
still apply.

**Lutris** (already installed and on the taskbar) is the better route for
GOG/Epic/standalone installers, since it handles the prefix, DXVK and winetricks
for you. It picks up `95-gaming.conf` automatically.

**Heroic** for Epic and GOG storefronts specifically — install from Bazaar.

Things to know for any of them:

* **MangoHud** attaches automatically (`MANGOHUD=1` is session-wide). `/` toggles
  it, same as in Steam games.
* **The 12V-2x6 rows work anywhere** — the files are in `/dev/shm`, which is not
  namespaced away outside Steam's container either.
* **DLSS overrides** only apply where DXVK-NVAPI is in play, i.e. a Proton or
  DXVK-based prefix. A native Linux game ignores them.
* **HDR** needs `PROTON_ENABLE_WAYLAND=1` plus `PROTON_ENABLE_HDR=1` and a
  Proton **GE or EM** build. Stock Proton and plain wine do not implement them.
* **Anticheat** is the usual wall. Check ProtonDB or areweanticheatyet.com before
  buying.
* If a launcher needs its own window rule for the focus problem above, copy the
  `[hunt-focus]` block in `~/.config/kwinrulesrc` and change the `wmclass` line.

---

## Still open

### TV Mode — 4K120

`display-profile tv` is written but has never been run for real, because it
blanks the main monitor. When it was checked the Philips was only advertising
**4K60** (and 1440p120) — no 4K120 anywhere in its EDID, which is an
HDMI 2.0-class link and almost certainly means it was in standby.

With the TV powered on and on the right input:

```
kscreen-doctor -o | grep -A3 HDMI-A-2      # look for 3840x2160@120
display-profile tv
display-profile gaming                      # back
```

If 4K120 still is not offered with the TV awake, it is the TV's per-port
high-bandwidth setting (Philips calls it **HDMI Ultra HD → Optimal**), not
anything Linux is doing.

### Nothing - Hunt is on DLSS 310.9 and the install is untouched

*This entry used to say Hunt was stuck on 3.7.10 and ask whether you wanted to
rewrite DLLs inside an EasyAntiCheat game. That question is settled and the
answer was "neither".*

Switching Hunt to **GE-Proton11-6** made `PROTON_DLSS_UPGRADE=1` live. It does
nothing on stock Proton — the variable is not even mentioned in Proton
Experimental's launcher script — which is why it looked inert at first. GE
downloads the newer DLLs itself and injects them at launch:

```
~/.cache/protonfixes/upscalers/dlss_v310.9.1.0     super resolution
                               dlss_d_v310.9.1.0   ray reconstruction
                               dlss_g_v310.9.1.0   frame generation
```

Every DLL in the game folder is byte-identical to its original backup, checked
with `cmp`, so **the install on disk is stock 3.7.10 and EasyAntiCheat never
sees a changed file**. The 310.9 in the debug overlay comes from GE at runtime,
with preset M from the NVAPI override in `95-gaming.conf`.

`PROTON_DLSS_UPGRADE` takes a **version**, not just on/off: `1` means newest
available, `310.9.1.0` pins that exact one. Useful if a future DLSS release ever
regresses something.

**Loose end:** about 335 MB of dead backup DLLs are still sitting in the game
folder from the DLSS Updater experiment — `*.dlsss` files it made, and
`*.310-version` copies parked while debugging. Nothing loads them. Left in place
because deleting files inside an anticheat game's directory is your call:

```bash
cd "$HOME/.local/share/Steam/steamapps/common/Hunt Showdown 1896"
find . \( -name "*.dlsss" -o -name "*.310-version" \) -delete
```

### Undervolt values

Yours to tune in LACT, as agreed.

---

## Changes worth knowing about

- **Pause was bound to "Lock Session."** To give Pause to the displays, Lock
  Session went back to its default **Meta+L**. It had no other binding.
- **The gaming environment lives in `~/.config/environment.d/95-gaming.conf`**
  (MangoHud, `PROTON_DLSS_UPGRADE=1`, and whatever `dlss` has set).
  `~/.config/gaming-env.conf` is a symlink to it. systemd exports it to the
  whole session, which matters because **KDE autostarts Steam at login** via
  `~/.config/autostart/steam.desktop` — that path goes through no launcher we
  control, so a desktop-file override alone silently missed it. Both the
  autostart entry and the app-menu entry now also call
  `~/.local/bin/steam-gaming`, which re-applies the file, as a second layer.
- **MangoHud's frame limiter is 280 fps.** That is the port of the RTSS limiter
  your Windows display profiles switched on; each profile rewrites it to match
  the screen it just selected. `display-profile gaming --no-limiter` skips it,
  and `Shift_L+F1` cycles it in game.
- **Terra repo is enabled** — where coolercontrol and lact come from.
- On 12 Sep a malformed D-Bus call while binding the Pause shortcut **crashed
  KWin**, which killed Steam and stopped the Hunt download for ~12 minutes. It
  was restarted and the download completed. Nothing was lost.

---

## Every knob, in one place

What you are most likely to want to change, and exactly where.

### 12V-2x6 alarm level

The one you asked about. It lives in the `--warn` argument in
`/etc/systemd/system/astral-pins.service`. Currently **9.0 A**.

Rather than editing that file, drop in an override — the real config stays
untouched underneath and deleting one file is the whole revert:

```bash
sudo mkdir -p /etc/systemd/system/astral-pins.service.d
sudo tee /etc/systemd/system/astral-pins.service.d/50-warn.conf <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/local/bin/astral-pins --daemon --interval 1 --warn 6.0 \
          --output /dev/shm/astral-pins \
          --alarm-command /usr/local/bin/astral-pins-alarm --alarm-repeat 30
EOF
sudo systemctl daemon-reload && sudo systemctl restart astral-pins
journalctl -u astral-pins -n 5     # prints the level it is running at
```

Undo: `sudo rm /etc/systemd/system/astral-pins.service.d/50-warn.conf`, then
`daemon-reload` and restart.

Other arguments on the same line: `--interval` seconds between reads (1.0),
`--alarm-repeat` how often the alarm re-fires while over (30, `0` = once only),
`--alarm-command` what it runs. It clears at `--warn` minus 0.5 A.

The alarm tone and how many times it plays are at the top of
`/usr/local/bin/astral-pins-alarm` (`SOUND_ALARM`, `ALARM_REPEATS`).

### Everything else

| What | Where | Notes |
|---|---|---|
| Overlay position | `position=` in `~/.config/MangoHud/MangoHud.conf` | `top-left`, `top-center`, `top-right`, `middle-left`, `middle-right`, `bottom-left`, `bottom-center`, `bottom-right`. **Shift+F11 cycles it in-game** with no editing. |
| Order of overlay blocks | order they appear in `MangoHud.conf` | Moving a block in the file moves it on screen. Verified. |
| Which overlay items show | `MangoHud.conf` | Currently matched item-for-item to your Windows Afterburner config. Each line is one item. |
| Overlay font / colours | `font_size`, `*_color` in `MangoHud.conf` | Colours are Afterburner's "modern" layout values. |
| FPS cap | `fps_limit=` in `MangoHud.conf` | **Shift+F1 cycles** the list in-game. 276 is first, to leave G-Sync headroom under 280 Hz. |
| Overlay hotkey | `toggle_hud=slash` | |
| Frametime logging | `autostart_log=` in `MangoHud.conf` | `0` = off. **Shift+F2 logs on demand** to `~/mangohud-logs`. |
| DLSS preset / version / overlay | `dlss` command, or the tray icon | `dlss sr M`, `dlss overlay on`, `dlss status`. Writes `~/.config/environment.d/95-gaming.conf`. **Restart Steam after any change.** |
| DLSS DLL version | `PROTON_DLSS_UPGRADE=` in `95-gaming.conf` | `1` = newest, or pin e.g. `310.9.1.0`. Needs Proton GE/EM. |
| HDR on/off | `PROTON_ENABLE_HDR` / `PROTON_ENABLE_WAYLAND` in `95-gaming.conf` | Both needed. Turning Wayland off should also cure the Hunt focus jump, at the cost of HDR. Full checklist for HDR that is not working, and why most of the advice online does not apply here: `~/bazzite-setup/AGENTS.md`, "HDR policy". |
| HDR per screen | `~/.config/kwinoutputconfig.json`, or System Settings → Display | Per output, not global. Currently **on for `DP-4` only** — the TV and the Dell both have `highDynamicRange: false`, so a game moved to either loses HDR with nothing said. |
| Display layouts | `~/.local/bin/display-profile` | `display-profile gaming\|work\|tv\|dell\|status`. Refresh rates and outputs are near the top of the file. |
| Login screen layout | `/var/lib/plasmalogin/.config/kwinoutputconfig.json` | Copy of your session's `setups` block. Delete it to get "all monitors on" back. |
| Fan curves | `~/.local/share/gaming-setup/apply-fan-curves.py` | Idempotent — edit the curve tables and re-run. GUI: CoolerControl. |
| GPU undervolt / power cap | LACT | Nothing set; card is at stock. |
| Hunt focus rule | `~/.config/kwinrulesrc` | See above. |
| Which Proton a game uses | Steam → game → Properties → Compatibility | GE-Proton11-6 for HDR/DLSS overrides; stock Proton otherwise, to keep Valve's shader caches. |
| Taskbar launchers | `launchers=` in `~/.config/plasma-org.kde.plasma.desktop-appletsrc` | Restart plasmashell after editing. |

---

## Rebuilding this from scratch

If you ever reinstall, this is the order that works. Most of it is copying files
back; the rest is noted.

1. **Layered packages** — everything else assumes these:
   ```bash
   sudo rpm-ostree install coolercontrol lact liquidctl gamescope-session-steam
   sudo systemctl reboot
   ```
2. **Kernel modules** for the board sensors:
   `/etc/modules-load.d/nct6775.conf` and `/etc/modules-load.d/i2c-dev.conf`.
3. **astral-pins** — build and install, then enable:
   ```bash
   gcc -O2 -Wall -Wextra -o astral-pins /usr/local/src/astral-pins/astral-pins.c
   sudo install -m 0755 astral-pins /usr/local/bin/
   sudo systemctl enable --now astral-pins
   ```
   with `/usr/local/bin/astral-pins-alarm` and
   `/etc/systemd/system/astral-pins.service` in place.
4. **User files** — restore the list under [Files](#files) below.
5. **Fan curves** — `python3 ~/.local/share/gaming-setup/apply-fan-curves.py`.
6. **Icons** — re-convert the two Windows `.ico` files (the snippet is in the
   taskbar section) and run `gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor`.
7. **Service cache and shell** — `kbuildsycoca6 --noincremental` then
   `systemctl --user restart plasma-plasmashell.service`.
8. **Steam** — set GE-Proton11-6 on Hunt (Properties → Compatibility), then fully
   quit and restart Steam so `95-gaming.conf` reaches it.
9. **Trims** — `sudo systemctl disable NetworkManager-wait-online.service displaylink.service`.
10. **Log out and back in** so `environment.d` and the virtual-keyboard setting
    take effect.

The one thing that is *not* just a file copy is the CoolerControl setup, because
it lives in CoolerControl's own database — which is what `apply-fan-curves.py`
exists for.

---

## Version control — what is worth tracking

Yes, and most of it is small text files. Nothing here contains a secret, so a
private repo (or even a public one) is fine. **Do not** track the Steam config
or anything under `~/.local/share/Steam` — it holds session tokens.

Worth tracking, roughly in order of how annoying they would be to recreate:

| File | Why |
|---|---|
| `~/GAMING_SETUP_NOTES.md` | this document |
| `~/Claude_Instructions.txt` | what was asked for |
| `/usr/local/src/astral-pins/astral-pins.c` | ~400 lines of C that exists nowhere else |
| `/usr/local/bin/astral-pins-alarm` | |
| `/etc/systemd/system/astral-pins.service` | |
| `~/.local/bin/` — `dlss`, `display-profile`, `displays-sleep`, `steam-gaming`, `dlss-overlay-tray`, `dlss-overlay-toggle`, `window-info` | all hand-written |
| `~/.local/share/gaming-setup/apply-fan-curves.py` | the ported FanControl curves |
| `~/.config/MangoHud/MangoHud.conf` | the Afterburner match |
| `~/.config/environment.d/95-gaming.conf` | the whole gaming environment |
| `~/.config/kwinrulesrc` | the Hunt focus rule |
| `~/.config/kwinoutputconfig.json` | display layout |
| `~/.local/share/applications/*.desktop`, `~/Desktop/*.desktop` | launchers |
| `~/.local/share/icons/hicolor/*/apps/{dlss-overlay,display-profile}-*.png` | converted icons — binary, but tiny |
| `/etc/modules-load.d/{nct6775,i2c-dev}.conf` | two lines each |
| `~/nvtruehdr/` | **its own git repo** — <https://github.com/TwoToneEddy/nvtruehdr>, branch `main`; build output is ignored |
| `~/.config/nvtruehdr/nvtruehdr.conf` | nvtruehdr settings and game profiles; `gaming-config-snapshot` picks it up |

Not worth tracking: `plasma-org.kde.plasma.desktop-appletsrc` (huge, churns on
every panel interaction, and Plasma rewrites it constantly — keep the
`launchers=` line in a note instead), anything in `~/.cache`, and the Steam
config.

**Everything below is already split into `~/bazzite-setup/`**, one directory per
component, with the files, an installer and a README each. That is the thing to
commit:

It is already a git repository, with a remote:

```bash
cd ~/bazzite-setup && git push -u origin master  # git@github.com:TwoToneEddy/bazzite-setup.git
```

**A flat collector script also exists** at `~/.local/bin/gaming-config-snapshot`.
It copies every file above into a directory, preserving paths, so you can commit
the result:

```bash
gaming-config-snapshot ~/gaming-config     # gather
cd ~/gaming-config && git init && git add -A && git commit -m "gaming setup"
```

Re-run it any time to refresh the copies, then commit the diff. It only reads;
it never writes back. Restoring is a deliberate manual copy, on purpose — a
one-command restore that puts files into `/etc` and `/usr/local` unattended is
the kind of thing that goes wrong quietly.

---

## Files

```
~/.local/bin/display-profile              display layouts (port of Switch-Display.ps1)
~/.local/bin/displays-sleep               Pause/Break -> DPMS off
~/.local/bin/dlss                         DLSS SR/RR/MFG presets + debug overlay
~/.local/bin/dlss-overlay-tray            tray icon: live DLSS overlay state + toggle
~/.local/bin/dlss-overlay-toggle          same toggle from the CLI / app menu
~/.local/bin/window-info                  opens KWin's debug console (window classes)
~/.local/bin/gaming-config-snapshot       gathers all of this for version control
~/.local/bin/steam-gaming                 Steam launcher that applies gaming-env.conf
~/.local/bin/nvtruehdr                    RTX HDR style SDR->HDR: per-game profiles (source ~/nvtruehdr)
~/.local/lib/nvtruehdr/lib{64,32}/        the nvtruehdr Vulkan layer
~/.local/share/vulkan/implicit_layer.d/nvtruehdr_{64,32}.json   its manifests
~/.config/nvtruehdr/nvtruehdr.conf        nvtruehdr settings (read live)
~/.config/vulkan/implicit_layer.d/MangoHud.*.json               symlinks: MangoHud loads above nvtruehdr
~/.config/environment.d/95-gaming.conf    MangoHud + DLSS env, exported session-wide
~/.config/gaming-env.conf                 symlink to the above
~/.config/autostart/steam.desktop         autostarted Steam, via the wrapper
~/.config/autostart/dlss-overlay-tray.desktop   starts the tray icon at login
~/.config/MangoHud/MangoHud.conf          overlay, matched to Windows Afterburner
~/.config/kwinrulesrc                     Hunt focus rule
~/.config/kwinoutputconfig.json           display layout for your session
~/Desktop/*.desktop                       display-mode icons + DLSS Updater
~/.local/share/gaming-setup/apply-fan-curves.py   rebuilds the CoolerControl setup
~/.local/share/applications/              display-profile-{gaming,work,tv,dell}.desktop,
                                          dlss-overlay-toggle.desktop,
                                          steam-bigpicture.desktop, displays-sleep.desktop
~/.local/share/icons/hicolor/*/apps/display-profile-*.png
                                          your Windows .ico files at 256px;
                                          display-profile-dell.png drawn to match them
~/.local/share/icons/hicolor/*/apps/dlss-overlay-{on,off}.png
                                          the DlssOverlay .ico files, all 8 sizes
/usr/local/bin/astral-pins                12V-2x6 per-pin monitor
/usr/local/bin/astral-pins-alarm          what it runs when a pin goes over
/usr/local/src/astral-pins/astral-pins.c  its source
/etc/systemd/system/astral-pins.service   the monitor, warn-only
/etc/modules-load.d/nct6775.conf          Super I/O sensor chip at boot
/etc/modules-load.d/i2c-dev.conf          needed to reach the Astral's sensor
/etc/coolercontrol/config.toml            fan profiles and channel assignments
/var/lib/plasmalogin/.config/kwinoutputconfig.json   login screen display layout
~/mangohud-logs/                          where Shift_L+F2 writes logs
```

Backups left in place, in case something needs reverting:

```
~/.config/MangoHud/MangoHud.conf.bak-preAfterburner
~/.config/kwinrulesrc.bak
~/.local/share/Steam/config/config.vdf.bak-preGE
/var/lib/plasmalogin/.config/kwinoutputconfig.json.bak-allon
```

---

## Health check

```bash
nvidia-smi --query-gpu=driver_version --format=csv,noheader   # 610.57.04
systemctl is-active coolercontrold lactd astral-pins          # active x3
journalctl -u astral-pins -n 3 | grep -o 'warn [0-9.]*A'      # warn 9.0A
cat /dev/shm/astral-pins                                      # six currents + total
display-profile status                                        # DP-4 ON 2560x1440@280
dlss status                                                   # preset M, overlay state
pgrep -f dlss-overlay-tray >/dev/null && echo "tray ok"
sensors | grep -A8 nct6799
systemd-analyze | tail -1                                     # userspace ~3.6s
systemctl --failed                                            # 0 loaded units
```

Fire the 12V alarm on demand, to prove sound and notifications still reach the
desktop:

```bash
sudo astral-pins --test-alarm --alarm-command /usr/local/bin/astral-pins-alarm
```

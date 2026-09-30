# 01 — Display switching (`display-profile`)

Four monitor layouts, one command, on the taskbar and the desktop. Port of the
Windows `DisplaySwitch` scripts (`Switch-Display.ps1`), using your own `.ico`
artwork.

## What it installs

| File | |
|---|---|
| `~/.local/bin/display-profile` | the command |
| `~/.local/share/applications/display-profile-{gaming,work,tv,dell}.desktop` | four launchers |
| `~/Desktop/display-profile-*.desktop` | the same four, on the desktop (executable, so Plasma trusts them) |
| taskbar | the four are appended to the Icons-Only Task Manager if not already pinned — plasmashell is stopped for the edit and started again, see `09-taskbar` for why |
| `~/.local/share/icons/hicolor/*/apps/display-profile-*.png` | the Windows icons; `dell` was drawn to match |
| `~/.config/kwinoutputconfig.json` | the saved layout for your session |
| `~/.local/bin/window-info` | opens KWin's debug console — how you find a window's class |
| `/var/lib/plasmalogin/.config/kwinoutputconfig.json` | the **login screen's** layout |

## Commands

```bash
display-profile gaming        # the 280 Hz panel alone
display-profile work          # desk multi-monitor layout
display-profile tv            # the TV
display-profile dell          # the Dell alone
display-profile status        # what is on, at what mode
display-profile gaming --no-limiter   # skip re-pinning the refresh rate
```

## Each profile sets the FPS limiter

Switching profile sets MangoHud's `fps_limit=` for the primary screen, from the
`*_CAP` constants at the top of `display-profile`: 250 for the AOC, 116 for the
TV, 59 for the Dell. The list is always `<cap>,0`, so Shift_L+F1 toggles between
the cap and unlimited. Reassembling `MangoHud.conf` (the `02`, `05` and `08`
installers) puts back the default of 250 until you next switch profile. The new
cap only reaches games started afterwards. A game that is already running keeps
its old cap until you press Shift_L+F4 in it.

## Hardware-specific

**This is the component most tied to this machine.** Output names
(`DP-4`, `HDMI-A-2`, …), resolutions and refresh rates are constants near the top
of `display-profile`. On different hardware, or after swapping a cable to another
port, that is the block to edit. `kscreen-doctor -o` prints what is actually
connected and what modes each output has — its output maps directly onto those
constants.

It drives `kscreen-doctor`, i.e. KWin's own output management, so the result is
what the Display Configuration panel would have done, and it persists.

## HDR is per screen, and lives here

KWin turns HDR on per output, and `kwinoutputconfig.json` is where that is
recorded: `highDynamicRange` and `wideColorGamut` are on for the AOC (`DP-4`) and
the TV (`HDMI-A-2`), off for the Dell. A game on the Dell gets no HDR, and nothing
says so. The rest of what HDR needs is in `00-gaming-env` and in the HDR policy in
[`../AGENTS.md`](../AGENTS.md#hdr-policy--washed-out-colours-are-the-default-failure-not-a-bug-you-found).

## Refresh rate is re-pinned on every switch

Switching outputs on this machine sometimes leaves the 280 Hz panel at a lower
mode, so each profile explicitly sets the mode after enabling the screen rather
than trusting whatever KWin picks. That is what `--no-limiter` skips if you ever
want the raw switch. Verified: `vkcube` in FIFO reported exactly 280 FPS / 3.6 ms.

## The login screen is a separate config

`plasmalogin` has its own KWin instance and its own
`kwinoutputconfig.json`, under `/var/lib/plasmalogin/.config/`. This is why **both
monitors used to light up at the login screen and then drop to one after
unlocking** — the greeter had no saved layout, so it turned everything on, and your
session then applied yours. The fix is the copy of your session's `setups` block
installed here.

Delete that file to get "all monitors on at the login screen" back.

## Traps

**`display-profile tv` has never been run for real**, and as things stand it
cannot give you 4K120. Checked on 28 Sep 2026: the Philips 48OLED707 on `HDMI-A-2`
advertises **no 3840x2160@120 mode at all**. Its best modes on that port are
`3840x2160@60` and `2560x1440@120`, so the profile is set to 4K60 and the "TV Mode
4K120" idea is blocked on the link, not on this script.

If 4K120 matters, it is an HDMI 2.1 bandwidth question before it is a software one:
the cable, the port on the TV (often only one or two are full-bandwidth), and the
TV's own "Enhanced/UHD Deep Colour" setting for that input, which is off by default
on these panels and silently caps the port at HDMI 2.0. Change those, then re-check:

```bash
kscreen-doctor -o | sed 's/\x1b\[[0-9;]*m//g' | grep -A3 HDMI-A-2   # 3840x2160@120?
display-profile tv
display-profile gaming                                              # back
```

Note the `sed` — `kscreen-doctor` colours its output, so a plain `grep` for a mode
string can miss it. That caught `preflight.sh` out once.

**`/var/lib/plasmalogin` is root-owned and mode 0700**, so a plain `test -e` on the
greeter's config is false even when the file is there. The installer uses `sudo`
for it.

**Do not restart `plasmalogin` while logged in.**

**The taskbar launchers are `09-taskbar`'s business**, not this component's — these
four `.desktop` files are installed here, but getting them onto the panel means
editing `launchers=`, which has its own procedure and its own way of going wrong.

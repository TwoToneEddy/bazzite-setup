# 00 — Gaming environment (`dlss`)

The environment every Steam game inherits — `MANGOHUD=1` and the Proton
HDR switches live in the same file — which is why it is component `00`: the
overlay, the DLSS tray and HDR all depend on it.

**DLSS presets are not set here.** RHI does that. This component used to write
SR / RR presets and a frame-generation override through DXVK-NVAPI; that was
removed in favour of RHI. What is left of `dlss` is the debug indicator the tray
toggles, and a status readout.

**DLL versions still come from here**, through `PROTON_DLSS_UPGRADE=1`. Without
it Hunt runs the 3.7.10 it ships, which has no preset K, L or M, so RHI's preset
override silently falls back to E.

## What it installs

| File | |
|---|---|
| `~/.local/bin/dlss` | status, and the DLSS debug indicator |
| `~/.config/environment.d/95-gaming.conf` | what it writes; the whole gaming environment |
| `~/.local/bin/steam-gaming` | Steam wrapper that applies the above |
| `~/.config/autostart/steam.desktop` | autostarts Steam through the wrapper |

## Commands

```bash
dlss status                # what is set right now
dlss overlay on | off      # NVIDIA's DLSS indicator (see 03)
```

## How it works

`dlss overlay on|off` writes NGX's own registry values (`ShowDlssIndicator`,
`DLSSG_IndicatorText` under `HKLM\SOFTWARE\NVIDIA Corporation\Global\NGXCore`)
straight into every Proton prefix's `system.reg`, the same switch Windows uses.
NGX reads them when a game starts DLSS, so the change applies at the next launch
with **no Steam restart**. A game open at the time is skipped, because Wine
writes its registry back over the edit on exit. Toggle again after closing it.
The chosen state is kept in `~/.config/dlss-overlay`.

It used to go through `DXVK_NVAPI_SET_NGX_DEBUG_OPTIONS` in `95-gaming.conf`,
which needed Steam fully restarted to take effect. **Do not put that variable
back**: DXVK-NVAPI writes it into the registry at every launch, overriding the
toggle.

**`steam-gaming` exports `DXVK_NVAPI_SET_NGX_DEBUG_OPTIONS` set but empty**, and
that is deliberate. GE-Proton's `proton` script does
`env.setdefault("DXVK_NVAPI_SET_NGX_DEBUG_OPTIONS", "DLSSIndicator=0,DLSSGIndicator=0,")`
unless `PROTON_DLSS_HUD` is set, so with the variable absent every launch writes
*off* over the registry and the toggle can never turn the indicator on. An empty
value stops the default and DXVK-NVAPI writes nothing. Verified on GE-Proton11-7.

**New games** are picked up automatically: every toggle rescans `compatdata` in
all libraries listed in `libraryfolders.vdf`. A game's prefix only exists after
its first launch, and a prefix without the values counts as *off* - so a game
first launched while the indicator is on needs one toggle after that to follow it.

**If the indicator ignores the toggle**, check the environment Steam actually
has - `tr '\0' '\n' < /proc/$(pgrep -x steam)/environ | grep NGX_DEBUG` should
print the variable with nothing after `=`. A non-empty value is a stale copy
from an older session (systemd's user manager and dbus-broker survive logout, and
Plasma re-imports their environment at login), or Steam was started by something
other than `steam-gaming`, such as the app-menu entry. A reboot clears the former.

`95-gaming.conf` is a `systemd` `environment.d` file, so it is also exported into
your whole session at login — but Steam gets it through the wrapper, which reads
the file at launch, so a change needs no relogin.

Also in that file, and worth knowing:

| Variable | |
|---|---|
| `MANGOHUD=1` | puts the overlay (`02`) on every game |
| `PROTON_DLSS_UPGRADE=1` | GE-Proton injects the newest DLSS DLLs at launch, without touching the game folder. Pin a version instead: `310.9.1.0` |
| `PROTON_ENABLE_WAYLAND=1` | HDR only reaches a Proton game if it presents through Wayland directly. On XWayland the compositor tone-maps the game's SDR output into the HDR screen instead, which is why Hunt reported the monitor had no HDR support |
| `PROTON_ENABLE_HDR=1` | sets `DXVK_HDR=1` internally. Both are needed |

## Install

```bash
./install.sh            # no sudo
```

## Traps

**Fully quit Steam and start it again** after any change. Not "restart the game" —
Steam passes its own environment to everything it launches, so a running Steam
keeps handing out the old values. `dlss status` reads the file, not the live
process; to check what a *running* game actually got, read
`/proc/<pid>/environ`.

**These variables need Proton GE or EM.** Stock Valve Proton ignores
`PROTON_ENABLE_HDR`, `PROTON_ENABLE_WAYLAND` and `PROTON_DLSS_UPGRADE` entirely.
Set the Proton version per game in Steam → Properties → Compatibility. The
trade-off: GE builds do not share Valve's precompiled shader caches, so first
launches take longer.

**GE-Proton is not installed by anything here**, and Steam does not ship it, so on
a fresh machine it is simply missing from the Compatibility dropdown. Install it
into your home directory (no layering, no reboot):

```bash
mkdir -p ~/.local/share/Steam/compatibilitytools.d
cd ~/.local/share/Steam/compatibilitytools.d
B=https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-6
curl -fLO $B/GE-Proton11-6-x86_64.tar.gz
curl -fLO $B/GE-Proton11-6-x86_64.sha512sum
sha512sum -c GE-Proton11-6-x86_64.sha512sum && tar -xzf GE-Proton11-6-x86_64.tar.gz
rm GE-Proton11-6-x86_64.*
```

Then fully quit and restart Steam. Release assets carry an `-x86_64` suffix from
11-4 onwards; the unsuffixed URL 404s. ProtonUp-Qt
(`flatpak install flathub net.davidotek.pupgui2`) does the same from a GUI.

A game left on Proton Experimental runs on **XWayland**, so it gets no HDR, and
a game that resizes its own window can end up offset: Onimusha showed up as
`3839x2160+960+540` on the TV, a 1080p window centred and then grown to 4K.

**Bare `dlss overlay` TOGGLES.** The read-only one is `dlss overlay status`. That
has caught me out.

**`PROTON_ENABLE_WAYLAND=1` is also the cause of Hunt's jump to the desktop on
launch** — click the game window to get back in. Turning it off cures that at the cost of
HDR.

**Do not add HDR variables here from a forum post.** The two in this file are the
two that do something on this configuration. `ENABLE_HDR_WSI=1`, the one most often
suggested for NVIDIA, drives the `vk_hdr_layer`, which is not installed here, so it
does nothing. The full checklist for HDR that is not working is in
[`../AGENTS.md`](../AGENTS.md#hdr-policy--washed-out-colours-are-the-default-failure-not-a-bug-you-found).

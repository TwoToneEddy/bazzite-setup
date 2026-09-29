# 00 — Gaming environment and DLSS presets (`dlss`)

Set the DLSS Super Resolution, Ray Reconstruction and Multi Frame Generation
preset, and the DLSS DLL version, for every Proton game at once — or for one game
at a time. This is the Linux equivalent of the NVIDIA App's DLSS override page.

It is also the environment every Steam game inherits — `MANGOHUD=1` and the Proton
HDR switches live in the same file — which is why it is component `00`: the
overlay, the DLSS tray and HDR all depend on it.

## What it installs

| File | |
|---|---|
| `~/.local/bin/dlss` | the command |
| `~/.config/environment.d/95-gaming.conf` | what it writes; the whole gaming environment |
| `~/.local/bin/steam-gaming` | Steam wrapper that applies the above |
| `~/.config/autostart/steam.desktop` | autostarts Steam through the wrapper |

## Commands

```bash
dlss status                                   # what is set right now
dlss sr K        dlss sr latest   dlss sr off  # Super Resolution preset (A-O)
dlss rr latest                                 # Ray Reconstruction preset
dlss mfg 4x      dlss mfg auto    dlss mfg off # Frame Gen / Multi Frame Gen
dlss overlay on | off                          # NVIDIA's DLSS indicator (see 03)
dlss dlls                                      # opens DLSS Updater, for DLL versions
dlss launch-options                            # the same settings for ONE game,
                                               #   to paste into Steam
dlss reset                                     # back to app-controlled
```

## How it works

It writes `DXVK_NVAPI_DRS_*` variables between `# BEGIN DLSS` and `# END DLSS` in
`95-gaming.conf`. DXVK-NVAPI reads them and presents them to the game as if they
were driver settings set by the NVIDIA control panel, which is how the override
reaches a game that has no such option of its own.

`95-gaming.conf` is a `systemd` `environment.d` file, so it is also exported into
your whole session at login — but Steam gets it through the wrapper, which reads
the file at launch, so a change needs no relogin.

Also in that file, and worth knowing:

| Variable | |
|---|---|
| `MANGOHUD=1` | puts the overlay (`02`) on every game |
| `PROTON_DLSS_UPGRADE=1` | lets Proton pull in newer DLSS DLLs for titles shipping an older one. Pin a version instead: `310.9.1.0` |
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

**The settings are global by design.** `dlss launch-options` prints the same
settings as a per-game launch-option string if you want one title to differ.

**`PROTON_ENABLE_WAYLAND=1` is also the cause of Hunt's jump to the desktop on
launch** (see `11-game-window-fixes`). Turning it off cures that at the cost of
HDR.

**Do not add HDR variables here from a forum post.** The two in this file are the
two that do something on this configuration. `ENABLE_HDR_WSI=1`, the one most often
suggested for NVIDIA, drives the `vk_hdr_layer`, which is not installed here, so it
does nothing. The full checklist for HDR that is not working is in
[`../AGENTS.md`](../AGENTS.md#hdr-policy--washed-out-colours-are-the-default-failure-not-a-bug-you-found).

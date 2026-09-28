# 03 — DLSS version and presets (`dlss`)

Set the DLSS Super Resolution, Ray Reconstruction and Multi Frame Generation
preset, and the DLSS DLL version, for every Proton game at once — or for one game
at a time. This is the Linux equivalent of the NVIDIA App's DLSS override page.

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
dlss overlay on | off                          # NVIDIA's DLSS indicator (see 04)
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

**Bare `dlss overlay` TOGGLES.** The read-only one is `dlss overlay status`. That
has caught me out.

**The settings are global by design.** `dlss launch-options` prints the same
settings as a per-game launch-option string if you want one title to differ.

**`PROTON_ENABLE_WAYLAND=1` is also the cause of Hunt's jump to the desktop on
launch** (see `11-game-window-fixes`). Turning it off cures that at the cost of
HDR.

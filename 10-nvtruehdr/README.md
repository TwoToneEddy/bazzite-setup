# 10 — nvtruehdr (RTX HDR style SDR→HDR)

An SDR→HDR Vulkan layer, written for this machine because **NVIDIA ships no Linux
TrueHDR model**. It gives SDR games the RTX HDR treatment on an HDR display, with
per-game profiles.

## This one lives in its own git repo

**<https://github.com/TwoToneEddy/nvtruehdr>**

The source is `~/nvtruehdr`, a clone of that repository on branch `main`, with
build output ignored. It is deliberately **not** duplicated into this directory —
copying a git repo in as loose files is how you end up with two diverging
versions and no way to tell which is newer.

On a new machine, clone it:

```bash
git clone https://github.com/TwoToneEddy/nvtruehdr.git ~/nvtruehdr
cd ~/nvtruehdr && ./install.sh
```

`./install.sh` in *this* directory offers to do the clone for you and then points
you at the repo's own build. Use the HTTPS URL above unless you have SSH keys on
the machine — the original clone uses `git@github.com:TwoToneEddy/nvtruehdr.git`,
which needs a key and fails with "Permission denied (publickey)" on a fresh
install.

What is here is the **settings**, which are not in that repo:

| File | |
|---|---|
| `~/.config/nvtruehdr/nvtruehdr.conf` | settings and per-game profiles, read live |

## What it installs on the system

Built and installed from `~/nvtruehdr` by its own build script:

```
~/.local/bin/nvtruehdr                                the command, per-game profiles
~/.local/lib/nvtruehdr/lib{64,32}/                    the Vulkan layer
~/.local/share/vulkan/implicit_layer.d/nvtruehdr_{64,32}.json    its manifests
~/.config/vulkan/implicit_layer.d/MangoHud.*.json     symlinks so MangoHud loads
                                                        ABOVE nvtruehdr
```

That last one matters: **layer order is not incidental.** MangoHud has to sit above
nvtruehdr in the chain, or the overlay gets tone-mapped along with the game and the
text comes out wrong. The symlinks are what pin the order.

## Install

```bash
./install.sh                              # settings, and clones the repo if absent
cd ~/nvtruehdr && ./install.sh            # builds and installs the layer
```

To update it later:

```bash
cd ~/nvtruehdr && git pull && ./install.sh
```

## Tuning

`~/.config/nvtruehdr/nvtruehdr.conf` is read live — no rebuild, no relogin.
Per-game profiles are sections in that file; `nvtruehdr --help` lists the
commands.

## When HDR does not work at all

Before suspecting this layer, work through the four conditions in
[`../AGENTS.md`](../AGENTS.md#hdr-policy--washed-out-colours-are-the-default-failure-not-a-bug-you-found):
the output in HDR mode in KWin, the game on Wayland rather than XWayland, Proton
GE/EM selected for that game, and sane SDR brightness. Washed-out colours mean SDR
content being stretched into an HDR container, which nvtruehdr cannot fix because it
is upstream of the problem.

Quick orientation:

```bash
# which outputs are in HDR mode - per output, not global
grep -oE '"(connectorName|highDynamicRange|wideColorGamut|sdrBrightness)": [^,]*' \
    ~/.config/kwinoutputconfig.json

# what a running game actually inherited, which is not always what the file says
pid=$(pgrep -n -f '\.exe'); tr '\0' '\n' < /proc/$pid/environ | grep -iE 'HDR|WAYLAND'
```

Verified state here: HDR is on for `DP-4` only. The TV (`HDMI-A-2`) and the Dell
(`HDMI-A-3`) both have `highDynamicRange: false`, so a game moved to either loses
HDR silently.

**`ENABLE_HDR_WSI=1` is not the fix on this machine**, despite how often it is
suggested. It switches on the `vk_hdr_layer`, which is not installed here — the
only HDR-related Vulkan layer present is nvtruehdr's own. With no layer to consume
it, the variable does nothing.

## Traps

**HDR only reaches a Proton game through Wayland directly.** Both
`PROTON_ENABLE_WAYLAND=1` and `PROTON_ENABLE_HDR=1` are needed, and both are in
`03-dlss-presets`' `95-gaming.conf`. On XWayland the compositor tone-maps the
game's SDR output into the HDR screen instead, and the game reports the monitor as
having no HDR support at all.

**Both need Proton GE or EM.** Stock Valve Proton ignores them.

**Do not track `~/nvtruehdr` from here.** Commit it to
<https://github.com/TwoToneEddy/nvtruehdr> instead. If you ever find loose copies
of the source inside `bazzite-setup`, that is the mistake this note exists to
prevent — delete them and clone.

**The repo builds a 32-bit and a 64-bit layer.** A game that runs as 32-bit picks
up the wrong one, or none, if only `lib64` was built, and the symptom is HDR
silently not engaging rather than an error. The repo's own `install.sh` handles
both.

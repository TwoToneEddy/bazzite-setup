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

## Traps

**HDR only reaches a Proton game through Wayland directly.** Both
`PROTON_ENABLE_WAYLAND=1` and `PROTON_ENABLE_HDR=1` are needed, and both are in
`03-dlss-presets`' `95-gaming.conf`. On XWayland the compositor tone-maps the
game's SDR output into the HDR screen instead, and the game reports the monitor as
having no HDR support at all.

**Both need Proton GE or EM.** Stock Valve Proton ignores them.

**Do not track `~/nvtruehdr` from here.** Commit it to
<https://github.com/TwoToneEddy/nvtruehdr> instead. If you ever find loose copies
of the source inside `gamingConfig`, that is the mistake this note exists to
prevent — delete them and clone.

**The repo builds a 32-bit and a 64-bit layer.** A game that runs as 32-bit picks
up the wrong one, or none, if only `lib64` was built, and the symptom is HDR
silently not engaging rather than an error. The repo's own `install.sh` handles
both.

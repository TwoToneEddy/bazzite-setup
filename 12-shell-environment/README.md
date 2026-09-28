# 12 — Shell environment (aliases and the git prompt)

Bash aliases and a git-aware prompt, carried over from the previous machine.

## What it installs

| File | |
|---|---|
| `~/.bashrc.d/50-bazzite-setup.sh` | the whole lot — prompt, then aliases by group |

**Nothing is appended to `~/.bashrc`.** Fedora's stock `.bashrc` already sources
every file in `~/.bashrc.d/`, so a single file dropped in there is the whole
install — and uninstalling is deleting one file rather than unpicking edits from a
file everything else also writes to. The installer checks that your `.bashrc`
really does source the directory, because a `.bashrc` carried over from another
distribution often does not.

It guards on an interactive shell (`case $- in *i*)`) so a script that happens to
source your bashrc does not inherit aliases that shadow real commands.

## The prompt

```
lee@bazzite:bazzite-setup (main) $
```

`user@host:dir (branch) $`, with **the branch green when the working tree is clean
and red when it is dirty**.

The `PS1` line as supplied references `$ps1_green`, `$ps1_white`, `$ps1_blue`,
`parse_git_branch` and `parse_git_branch_color` without defining any of them, so
all five are defined in this file. Without them you get an uncoloured prompt and
`bash: parse_git_branch: command not found` printed before every single prompt.

Two details worth keeping if you edit it:

- **`\[` and `\]` around every escape sequence.** Not decoration — without them
  bash counts the escape bytes as visible width, and a long command line wraps
  over itself.
- **`parse_git_branch_color` runs `git status --porcelain` on every prompt.** That
  is a fork per prompt. It is unnoticeable in a normal repository; in a very large
  one it is the first thing to remove if the prompt starts to feel slow.

## The aliases

Grouped in the file: git, editors and remote machines, serial/3D-printing, system.

```
gs  git status -s          com…com5  chmod 777 /dev/ttyACM0-5
gk  gitk --all &           ports     list ttyACM devices
pull / push                cf        bridge octopi's USB serial over ssh
commit  -m "Updates"       mm        platformio build
add  git add *             g         gedit
gr  git remote -v          pi        ssh pi@raspberrypi
prune  fetch --prune       windows   reboot into Windows
tag / tagl                 usbw      which USB devices can wake the machine
                           reload    source ~/.bashrc
                           b         ~/common/scripts/commit.sh
                           cura      Ultimaker Cura
```

## Traps

These are kept **verbatim**, as asked. Each has a comment in the file saying what
the local equivalent is, and `install.sh` reports which targets are actually
present on the machine you are on.

**`pull` and `push` hardcode `master`.** This repository is on `master`, so they
work here — `git` 2.55 on this machine still defaults to `master` because
`init.defaultBranch` is unset. But **GitHub defaults new repositories to `main`**,
and any repo you clone from elsewhere is likely on `main` too, where these fail
with `couldn't find remote ref master`. The branch-agnostic versions are in the
file, commented out:

```bash
alias pull='git pull origin "$(git branch --show-current)"'
alias push='git push origin "$(git branch --show-current)"'
```

**`add` is `git add *`, not `git add -A`.** That is shell globbing, so it skips
dotfiles, ignores the repository root, and stages relative to wherever you happen
to be standing. `git add -A` is the one that stages everything, including
deletions, from anywhere in the tree.

**`cf` uses `$H`, which is almost certainly meant to be `$HOME`.** With `$H`
unset, `PTY,link=$H/dev/ttyACM0` resolves to `/dev/ttyACM0` — the real device node
— so socat tries to create its pseudo-terminal on top of a kernel device. The
intended line is in the file's comment.

**`com`…`com5` are `chmod 777` after every replug.** The lasting fix is group
membership:

```bash
sudo usermod -aG dialout $USER      # then log out and back in
ls -l /dev/ttyACM0                  # confirm which group owns it
```

**Four targets do not exist on this machine** — checked, not assumed:

| Alias | Problem | Here |
|---|---|---|
| `g` → `gedit` | GNOME editor, not installed on KDE | `kate`, or `flatpak install org.gnome.gedit` |
| `mm` → `platformio` | not installed | `pip install --user platformio`, or a toolbox container |
| `windows` → `/opt/reboot-into-windows` | script from the old machine | `systemctl reboot --boot-loader-entry=…`, snippet in the file |
| `cura` → an AppImage in `/opt` | that path and the Ubuntu `libstdc++` path are both Debian-specific | `flatpak install flathub com.ultimaker.cura` |

`gk`, `b`, `gs`, `gr`, `cf`, `pi` and the rest all work here. `gitk` resolves to a
distrobox shim in `~/.local/bin`, which is why it works on an immutable system at
all.

**On an immutable system, reach for `flatpak` or a toolbox before `rpm-ostree`**
when filling any of these gaps. See the Bazzite policy in `../AGENTS.md`.

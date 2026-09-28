# 06 — Pause/Break blanks the displays

One key blanks both screens without locking, suspending or stopping anything.
Wake them with any key or the mouse.

## What it installs

| File | |
|---|---|
| `~/.local/bin/displays-sleep` | sets DPMS off on every output |
| `~/.local/share/applications/displays-sleep.desktop` | what the shortcut is attached to |

The shortcut itself lives in `~/.config/kglobalshortcutsrc`, under
`[services][displays-sleep.desktop]` as `_launch=Pause`. The installer adds that
line via KDE's own tooling if it is not there.

## How it works

`kscreen-doctor --dpms off`. That is all — KWin blanks the outputs, and any input
brings them back. Nothing is suspended, so anything running keeps running, which
is the point: a game or a download carries on with the screens dark.

Tested by injecting a real `KEY_PAUSE` at the kernel level and watching DPMS go
`on → off`.

## Traps

**Suspend and hibernate are masked system-wide on this machine, deliberately.**
This component is the replacement for reaching for a sleep key. Do not "fix" it by
re-enabling `suspend.target`.

**Editing `kglobalshortcutsrc` by hand while Plasma is running is unreliable** —
`kglobalaccel` holds its own copy. The installer writes the file and then asks
`kglobalaccel` to reload; if the key does not work, log out and back in, or set it
in System Settings → Shortcuts → search "displays-sleep".

**Never call `org.kde.KGlobalAccel` over D-Bus with the wrong number of
arguments.** It crashes `kwin_wayland` and takes every XWayland app on the desktop
with it. If you are scripting against it, get the signature right first with
`busctl --user introspect`.

**The Qt D-Bus tool is not called `qdbus6` here.** Bazzite 44 ships `qdbus` and
`qdbus-qt6` but not `qdbus6`, which is the name most KDE documentation uses — so a
pasted `qdbus6 ...` line fails with "command not found" and, in a script with its
errors swallowed, does nothing at all while appearing to work. `common/lib.sh` has
a `qdbus_cmd` helper that finds whichever one exists.

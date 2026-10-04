# 09 — The taskbar launcher row

Which launchers sit on the Icons-Only Task Manager, and — more importantly — the
only safe way to change them.

## What is here

| File | |
|---|---|
| `panel-launchers.txt` | the live `launchers=` line, verbatim |
| `install.sh` | checks what is missing and walks you through applying it |

There is no `files/` tree. The full panel config is deliberately **not** tracked:
it is huge, it churns on every panel interaction, and Plasma rewrites it constantly.
Only one line matters.

## The row, left to right

| Icon | |
|---|---|
| Steam | |
| Lutris | |
| Konsole, Files | |
| Chrome | `google-chrome.desktop` (pacman) |
| **Desk Gaming / Desk Work / TV Mode / Dell Only** | the four `display-profile` layouts (`01`) |
| **Discord** | `discord.desktop` (pacman) |

That is the CachyOS row. On Bazzite, Chrome and Discord were flatpaks pinned by
their `/var/lib/flatpak/exports/...` paths, and Bazaar and yafti sat after Konsole;
neither exists on CachyOS.

Big Picture (`bazzite-steam-bpm`, "Big Picture (in desktop)") is no longer pinned.
There is no `steam-bigpicture.desktop` on this machine any more, so re-pinning it means recreating that launcher first.

The launchers themselves are `.desktop` files in `~/.local/share/applications/`,
installed by whichever component owns them. This component only sets the order and
which of them are pinned. `01-displays` pins its own four itself (appending them,
using `pin_launchers` in `common/lib.sh`), so they are on the taskbar after stage 1
even without this component; this one then sets the recorded order.

## How to change it

The list is the `launchers=` line under
`[Containments][4][Applets][7][Configuration][General]` in
`~/.config/plasma-org.kde.plasma.desktop-appletsrc`.

**Stop plasmashell before editing that file. Not just restart it afterwards.**

```bash
systemctl --user stop plasma-plasmashell.service
# edit launchers= now
systemctl --user start plasma-plasmashell.service
```

Easiest of all: drag the icons where you want them in the panel, then re-run
`./install.sh` to record the new line back into `panel-launchers.txt`.

## Traps

**Editing the file while plasmashell is running loses the edit, later, silently.**
plasmashell holds its own in-memory copy of the panel config and writes it back
over the file at some point after you have finished — taking your change with it.
That happened once and it took a removal *and two unrelated launchers* with it.
Hence: stop the shell first.

**Writing the line through Plasma's live scripting API does not work either.**
`evaluateScript` plus `reloadConfig()` updates the file but does not repopulate the
applet, and forcing it by removing and re-adding entries left the panel showing a
single blank placeholder. Both were tried. Stop the shell, edit the file, start the
shell.

**Do not pin `dlss-overlay-toggle.desktop` here.** See `03-dlss-debug-overlay` —
a pinned launcher cannot show live state, and having both it and the tray icon
means two controls that disagree.

**A pinned launcher's icon is cached** and only re-read when plasmashell restarts.
Anything that needs to change its own icon to reflect state has to be a system tray
item instead.

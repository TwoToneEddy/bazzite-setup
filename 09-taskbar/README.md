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
| **Big Picture (in desktop)** | `bazzite-steam-bpm` — the console interface as a window on this desktop, no logout. Named to distinguish it from the *session* called "Steam Big Picture" at the login screen, which is the real gamescope one. It uses `bazzite-steam-bpm` rather than Steam's own in-client button because switching to BPM from inside the client is known to be sluggish on Bazzite. |
| Lutris | |
| **Discord** | the flatpak |
| Chrome | the flatpak |
| **Desk Gaming / Desk Work / TV Mode / Dell Only** | the four `display-profile` layouts (`01`) |
| Konsole, Files, Bazaar, yafti | |

The launchers themselves are `.desktop` files in `~/.local/share/applications/`,
installed by whichever component owns them. This component only sets the order and
which of them are pinned.

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

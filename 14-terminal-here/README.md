# 14 — Open Terminal Here on right-click

A terminal entry on the right-click menus, opening in the folder you clicked.

| Right-click on | Comes from |
|---|---|
| a folder, in Dolphin or on the desktop | `~/.local/share/kio/servicemenus/open-terminal-here.desktop` → `konsole --workdir %f` |
| empty desktop space | Plasma's built-in **Open Terminal** item, which ships switched off |

These are two different menus, which is why both are needed. The service menu adds
nothing to the empty-desktop menu: that one belongs to the desktop's *Standard
Menu* mouse action, and its items are switches in
`~/.config/plasma-org.kde.plasma.desktop-appletsrc`:

```ini
[ActionPlugins][0][RightButton;NoModifier]
_open_terminal=true
```

The same switch is in the GUI: right-click the desktop → **Desktop and Wallpaper**
→ **Mouse Actions** → configure **Standard Menu** → tick **Open Terminal**. The
built-in item opens the default terminal application, not necessarily Konsole.

## What the installer does

1. Copies the service menu (it must be executable, or KIO ignores it).
2. If `_open_terminal` is not already `true`: backs up the appletsrc, **stops
   plasmashell**, sets the key, starts plasmashell again. Your panel disappears
   for a second or two. Editing that file with the shell running is lost the
   next time plasmashell saves — see the rule in `../AGENTS.md`.

Re-running is a no-op once both are in place. Dolphin only reads service menus at
start-up, so close every Dolphin window after a first install.

## Notes

- Uses Konsole. To use another terminal, change `Exec=` in the service menu
  (`alacritty --working-directory %f`, `kitty --directory %f`).
- `desktop-file-validate` complains about the service menu (`MimeType`/`Actions`
  on a `Type=Service`). That is the KIO service-menu format; ignore it.
- Recent Dolphin may also offer its own terminal entry. If a folder menu shows two,
  delete the installed service menu.

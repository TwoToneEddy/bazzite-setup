# 11 — Game window fixes (KWin rules)

One KWin rule, for one real annoyance: **Hunt: Showdown drops to the desktop the
moment it launches**, and you have to click the game window to get back into it.

## What it installs

| File | |
|---|---|
| `~/.config/kwinrulesrc` | the KWin window rules, including the Hunt focus rule |

## The rule

It forces focus and activation on Hunt's window when it appears. The cause is
`PROTON_ENABLE_WAYLAND=1` (`03-dlss-presets`): the game creates its Wayland surface
and KWin does not treat the new surface as focus-stealing-exempt, so focus stays
where it was — on the desktop.

Turning `PROTON_ENABLE_WAYLAND` off also cures it, at the cost of HDR. The rule was
the better trade.

## Traps

**The window class in the rule is a best guess.** It was written from what Hunt
reported at the time, and a game update that changes its window class will silently
stop the rule matching — the symptom being the original annoyance coming back, with
no error. To find the real class of any window:

```bash
window-info        # opens KWin's debug console; click the window
```

`window-info` is installed by `05-display-switching`.

**`kwinrulesrc` is the whole rules file, not just this rule.** Installing it
replaces any rules you have added since. A `.bak-gamingConfig` copy is kept, and
the GUI is System Settings → Window Management → Window Rules.

**Rules apply to new windows.** Restart the game, or ask KWin to re-read them,
after editing. Note the tool's name varies — Bazzite 44 has `qdbus` and
`qdbus-qt6` but **no** `qdbus6`, which is the name most KDE documentation uses, so
a copied-and-pasted command fails silently:

```bash
qdbus-qt6 org.kde.KWin /KWin reconfigure
```

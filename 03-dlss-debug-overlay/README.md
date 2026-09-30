# 03 — DLSS debug overlay toggle (tray icon)

NVIDIA's own DLSS / DLSS-G debug indicator — the little text block that tells you
which DLSS model and preset a game is really using — with a **system tray icon
that toggles it and shows its current state**. Port of Windows'
`Toggle-DlssOverlay.ps1`, using the same two icons.

## What it installs

| File | |
|---|---|
| `~/.local/bin/dlss-overlay-tray` | the tray icon (PySide6 StatusNotifierItem) |
| `~/.config/autostart/dlss-overlay-tray.desktop` | starts it at login |
| `~/.local/bin/dlss-overlay-toggle` | the same toggle from a shell or the app menu |
| `~/.local/share/applications/dlss-overlay-toggle.desktop` | its app-menu entry |
| `~/.local/share/icons/hicolor/*/apps/dlss-overlay-{on,off}.png` | the Windows `.ico` artwork, all eight sizes |

The underlying switch is the `dlss` command from `00-gaming-env`, which writes
NGX's registry values into every Proton prefix. Install that first.

## Using it

* **Left click** the tray icon toggles the overlay.
* **Right click** gives explicit on / off and a "Show DLSS settings" window.
* The icon changes **instantly**, and also follows changes made elsewhere — run
  `dlss overlay on` in a terminal and the tray icon updates, because it watches
  `~/.config/dlss-overlay` with a `QFileSystemWatcher`.

From a shell: `dlss overlay on`, `dlss overlay off`, `dlss overlay status`.

## Why it is a tray icon and ONLY a tray icon

Windows flips a registry value and then repoints its own shortcut at `dlss-on.ico`
/ `dlss-off.ico`, so the taskbar icon always shows the state. **That trick does
not work on Plasma.** The Icons-Only Task Manager caches a launcher's icon and
only re-reads the `.desktop` file when plasmashell restarts, so a pinned launcher
sits there showing the wrong state until the next login. Confirmed by screenshot,
twice.

A StatusNotifierItem can redraw on demand, so that is what this is. It costs about
80 MB of RAM, which is the price of a live indicator; nothing else on the system
can repaint a panel icon when asked.

**Do not pin `dlss-overlay-toggle.desktop` to the panel.** For a while it was
pinned *and* the tray icon was running, and the two disagreed — clicking either
changed the state, but only the tray icon redrew, so whichever you had not just
used showed the wrong thing. One control, in the tray.

## If the icon seems to have vanished

It is almost certainly collapsed behind the tray's `^` expander arrow rather than
gone, and the "off" icon is the dimmer of the two so it is easy to miss. Check in
this order:

```bash
pgrep -af dlss-overlay-tray          # is it running at all?
dlss overlay status                  # which icon should it be showing?
```

To keep it permanently visible: right-click the tray → **Configure System Tray** →
**Entries** → find it → **Always shown**.

## Traps

**Bare `dlss overlay` TOGGLES**; `dlss overlay status` is the read-only one.

**It applies at the next game launch, with no Steam restart.** A game that is
already open keeps its setting and is skipped by the toggle. Toggle again once
it is closed.

**`dlss-overlay-toggle` still rewrites its own `.desktop` icon**, Windows-style.
That is correct behaviour and harmless; it is just only visible after a relogin,
which is the whole reason the tray icon exists.

**The tray needs PySide6.** Bazzite has it; on a bare Fedora,
`rpm-ostree install python3-pyside6` or run it in a toolbox.

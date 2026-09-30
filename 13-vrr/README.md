# 13 — VRR for windowed games

Use KDE's per-window **Adaptive sync** rule to enable variable refresh rate
(VRR) for a game without enabling it for every desktop application. This guide
targets Bazzite's KDE Wayland session, with Plasma 6.1 or newer. No packages,
environment variables or installer are needed; `install-all.sh` skips this
documentation-only component.

## Choose the display policy

In **System Settings → Display & Monitor → Display Configuration**, select the
gaming display and set **Adaptive Sync → Automatic** (the fullscreen-only
policy). Repeat for each VRR-capable display you use for games.

| Policy | Behavior |
|---|---|
| Never | Disables VRR on that display; a window rule does not override it. |
| Automatic | Uses VRR for the active fullscreen window, or an active window whose Adaptive sync rule enables it. |
| Always | Enables VRR for the display, including ordinary desktop applications. |

**Borderless does not necessarily mean VRR is excluded.** Automatic checks
whether KWin considers the window fullscreen, not the label in the game's menu.
A borderless game recognised as fullscreen already qualifies. Add a rule for
games that do not qualify, including games played in an ordinary window.

The rule is per application, but VRR operates on the display as a whole. In
Automatic mode, KWin consults the active window on that output. It does not give
each visible window an independent refresh rate.

## Example: Onimusha: Way of the Sword

With the TV at 100% scale, VRR is confirmed working in Onimusha under the
Automatic policy with no window rule at all. The steps below are only needed if
that stops being true, or for another game where Automatic does not kick in.

1. Launch Onimusha, then open **System Settings → Window Management → Window
   Rules**.
2. Add a new rule named **Onimusha - VRR**.
3. Use **Detect Window Properties** and select the actual game window. Match its
   window class/application identity rather than a changing window title. Its
   class has been `onimushawots.exe` on native Wayland and
   `steam_app_2638890` on XWayland; confirm what your running game reports.
4. Choose **Add Property → Adaptive sync**, set the policy to **Force** and the
   value to **Yes**, then apply.
5. Focus the game and verify VRR as described below. Restart the game if needed
   after changing the rule.

For reference, the Adaptive sync property is stored in `~/.config/kwinrulesrc`
as these two entries inside the matching rule's section:

```ini
adaptivesync=true
adaptivesyncrule=2
```

Use the GUI to manage the rule and its matching criteria. These lines are not a
complete standalone rules file. **Do not replace your whole `kwinrulesrc` with
this example.**

To undo the VRR exception, remove only the **Adaptive sync** property (or delete
the dedicated VRR rule). The display then follows Automatic's default behavior.

## Verify on the display

Enable Adaptive Sync/FreeSync/G-SYNC in the monitor's own settings if required.
Use its live refresh-rate counter, if available, while the game is focused and
running at a varying frame rate within the display's VRR range. The refresh rate
should follow the game's presentation rate rather than stay at the display's
fixed maximum. Low-framerate compensation can produce multiples of the game FPS.

An FPS overlay alone does not prove VRR is active, and a monitor menu that merely
says Adaptive Sync is enabled does not prove it is being used. Compare the same
scene with the display policy temporarily set to Never, then restore Automatic.
If the monitor has no live counter, record verification as incomplete rather
than treating a saved rule as proof. This example has not been hardware-tested
as part of adding this guide.

## Windows comparison and references

NVIDIA's Windows control panel offers **Enable G-SYNC for windowed and full
screen mode**. Windows 11 also provides **Optimizations for windowed games**,
which moves compatible DX10/11 games to flip-model presentation and enables
features such as VRR. On KDE, Automatic plus per-game Adaptive sync rules gives
you explicit control over the exceptions; Always is the broader display-wide
option.

- [KDE Plasma 6.1 changelog: Adaptive Sync window rule](https://kde.org/announcements/changelogs/plasma/6/6.0.5-6.1.0/)
- [KWin 6.6 window preference: rule overrides fullscreen default](https://github.com/KDE/kwin/blob/Plasma/6.6/src/window.cpp#L4274)
- [KWin 6.6 compositor: output policy and active window](https://github.com/KDE/kwin/blob/Plasma/6.6/src/compositor.cpp#L663)
- [NVIDIA: setting up G-SYNC](https://www.nvidia.com/content/Control-Panel-Help/vLatest/en-us/mergedProjects/nvdsp/To_use_variable_refresh_rates.htm)
- [Microsoft: optimizations for windowed games](https://support.microsoft.com/en-US/Windows/Hardware/Display-Graphics/optimizations-for-windowed-games-in-windows-11)

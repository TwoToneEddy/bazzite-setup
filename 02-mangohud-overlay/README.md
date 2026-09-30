# 02 — Performance overlay (MangoHud, matched to Afterburner)

The in-game overlay, built to show **exactly** what MSI Afterburner shows on the
Windows install and nothing more. It starts hidden; `/` shows it, in every game.

## What it installs

| File | |
|---|---|
| `~/.config/MangoHud/bazzite-setup.d/10-overlay.conf` | keys, appearance, the GPU rows, max temp / max power |
| `~/.config/MangoHud/bazzite-setup.d/30-cpu-fps.conf` | the CPU, RAM and framerate rows |
| `~/.config/MangoHud/bazzite-setup.d/90-limiter.conf` | the FPS limiter, logging, the blacklist |
| `~/.config/MangoHud/MangoHud.conf` | the overlay itself, assembled from the pieces above |
| `~/.local/bin/gpu-peaks` | publishes peak GPU temperature and power |
| `~/.config/systemd/user/gpu-peaks.service` | runs the above |

`MANGOHUD=1` itself is set in `00-gaming-env`' `95-gaming.conf`, which is what
puts the overlay on every Steam game. MangoHud ships with Bazzite.

## MangoHud.conf is assembled

MangoHud reads one file, but two of its rows belong to other components, because
those components own what feeds them:

| Piece | From | Rows |
|---|---|---|
| `10-overlay.conf`, `30-cpu-fps.conf`, `90-limiter.conf` | here | everything else |
| `20-voltage.conf` | `08-gpu-undervolt` | VOLTAGE, fed by `gpu-voltage` through LACT |
| `50-pins.conf` | `05-per-pin-current` | the six 12V-2x6 pin currents |

Each of those installers copies its piece into `~/.config/MangoHud/bazzite-setup.d/`
and joins every piece there, in name order, into `MangoHud.conf`. So stage 1 gets
an overlay with no pin or voltage rows and nothing to layer, and the rows appear
when their component is installed, whichever order that happens in. The pieces
join back into exactly the file this used to be — checked with `cmp`.

## What is on screen

Thirteen items, taken from the `[Source *]` sections with `ShowInOSD=1` in the
Windows `MSIAfterburner.cfg`: GPU temperature, usage, memory usage, core clock,
power and voltage; CPU temperature and power; RAM usage; framerate, frametime,
1 % low and 0.1 % low (voltage only once `08` is installed). Plus three rows Afterburner has no equivalent for: the six
**12V-2x6 pin currents** (from `05`), **max temp / max power**, and **GPU memory clock**.

Four things about the translation are worth knowing:

* **CPU usage cannot be hidden.** Afterburner has it off. MangoHud draws usage,
  temperature and power as one row and drops the whole row if `cpu_stats` is off —
  verified by screenshot. So the percentage stays.
* **GPU voltage comes from LACT, not MangoHud**, because NVML — which MangoHud
  reads NVIDIA cards through — has no voltage API. The row and its feed live in
  `08-gpu-undervolt`, which runs the LACT daemon they read; its README has the
  detail.
* **Max temp / max power** exist because MangoHud has no peak tracking of its own —
  there is no `gpu_temp_max` parameter — and Afterburner does. `gpu-peaks` reads
  NVML directly rather than shelling out to `nvidia-smi`, which costs 50–100 ms a
  call.
* **GPU memory clock** needs `vram` enabled or MangoHud drops it silently, and it
  shares the VRAM row rather than getting a labelled row of its own. It agrees
  with LACT — 405 MHz idle, 810 MHz under light load, checked side by side.

**Only the 5090 is listed**, via `pci_dev=0000:01:00.0`. Index 0 is the Radeon
iGPU in the 9800X3D, and Afterburner hides its first GPU the same way. Selected by
PCI address rather than `gpu_list=1` because the index depends on enumeration
order, which is not guaranteed to match inside Steam's container. **If the selector
ever points at nothing, MangoHud silently drops the GPU and VRAM rows and keeps
everything else** — so a missing GPU row means that line, not a broken overlay.
On different hardware, `lspci -nn | grep -i vga` gives you the address to use.

Colours are Afterburner's "modern" layout (`OSDLayout = 1`): GPU group `008040`,
CPU group `0080C0`, framerate group `C08080`, values white.

## In-game keys

| Key | |
|---|---|
| `/` | show / hide the overlay |
| `Shift_L+F1` | cycle the frame limiter |
| `Shift_L+F2` | log to `~/mangohud-logs` |
| `Shift_L+F4` | **reload the config** — use this after editing, no restart needed |
| `Shift_L+F11` | cycle the overlay position |

## Tuning

| What | Where |
|---|---|
| which items show | one line each in the pieces under `files/home/.config/MangoHud/bazzite-setup.d/`. Delete or comment a line, then re-run `./install.sh`. |
| order on screen | **the order blocks appear in the assembled file**, which is the pieces in name order. To put the 12V-2x6 rows at the top, give `50-pins.conf` a name that sorts before the GPU block — which means splitting `10-overlay.conf` there. Verified by screenshot. |
| position | `position=` — `top-left`, `top-center`, `top-right`, `middle-left`, `middle-right`, `bottom-left`, `bottom-center`, `bottom-right`. Or `Shift+F11` in-game with no editing. |
| font, size, colours | `font_size`, `*_color` |
| FPS cap | `fps_limit=<cap>,0` — `Shift+F1` toggles between the cap and unlimited. The cap is per screen (AOC 250, TV 116, Dell 59), written by `display-profile` (`01`); the piece holds the AOC's as the default. `fps_limit_method=early` for even frame pacing on VRR, and `show_fps_limit` puts the active cap on the overlay. |
| toggle key | `toggle_hud=slash`. `no_display` makes every game start with the overlay hidden - MangoHud keeps no state between launches, so this is the only way to not have it pop up |
| logging | `autostart_log=` (`0` = off); `Shift+F2` logs on demand |

GOverlay is installed if you would rather edit this in a GUI.

## Traps

**`custom_text` and `exec` rows only render with `legacy_layout=false`.** With the
default `true`, MangoHud silently draws none of them and never runs the `exec`
commands at all — the overlay looks fine, just missing five rows. This cost an
afternoon once: a test that measured how often `exec` fires recorded zero
invocations, because nothing was rendering.

**MangoHud renders only the last line an `exec` prints.** That is why each pin
gets its own row rather than one `exec` printing six figures.

**`exec` is not on the render path.** It runs via `popen` roughly twice a second
per row regardless of frame rate, in a separate thread. Measured: 72 invocations
over 12 s across 3 rows. A deliberate `sleep 0.4` in an `exec` row changed average
FPS by 0.5 % and *improved* the 0.1 % low, so these rows are not a stutter source.

**`gpu_mem_clock` needs `vram`.** Without it, no error — the row just is not there.

**Steam has to be fully quit and restarted** for a change to `MANGOHUD=1` to
reach games. A reassembled `MangoHud.conf` needs only `Shift_L+F4`.

**An edit to the live `MangoHud.conf` is lost at the next reassembly** — which
running this installer, `05`'s or `08`'s does. Try a change live with
`Shift_L+F4`, then put it in the piece it belongs to. That includes `fps_limit=`:
`display-profile` rewrites it in the live file with the current screen's cap, and a
reassembly puts the AOC default back until the next profile switch.

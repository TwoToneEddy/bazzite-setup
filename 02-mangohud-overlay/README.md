# 02 — Performance overlay (MangoHud, matched to Afterburner)

The in-game overlay, built to show **exactly** what MSI Afterburner shows on the
Windows install and nothing more. `/` toggles it, in every game.

## What it installs

| File | |
|---|---|
| `~/.config/MangoHud/MangoHud.conf` | the overlay itself |
| `~/.local/bin/gpu-peaks` | publishes peak GPU temperature and power |
| `~/.local/bin/gpu-voltage` | publishes GPU core voltage, read from LACT |
| `~/.config/systemd/user/gpu-peaks.service` | runs the above |
| `~/.config/systemd/user/gpu-voltage.service` | |

`MANGOHUD=1` itself is set in `03-dlss-presets`' `95-gaming.conf`, which is what
puts the overlay on every Steam game. MangoHud ships with Bazzite.

## What is on screen

Thirteen items, taken from the `[Source *]` sections with `ShowInOSD=1` in the
Windows `MSIAfterburner.cfg`: GPU temperature, usage, memory usage, core clock,
power and voltage; CPU temperature and power; RAM usage; framerate, frametime,
1 % low and 0.1 % low. Plus three rows Afterburner has no equivalent for: the six
**12V-2x6 pin currents**, **max temp / max power**, and **GPU memory clock**.

Four things about the translation are worth knowing:

* **CPU usage cannot be hidden.** Afterburner has it off. MangoHud draws usage,
  temperature and power as one row and drops the whole row if `cpu_stats` is off —
  verified by screenshot. So the percentage stays.
* **GPU voltage comes from LACT, not MangoHud.** MangoHud reads NVIDIA cards
  through NVML, and this driver has no voltage API — no voltage symbol in
  `libnvidia-ml.so.1` at all, and `nvidia-smi -q -d VOLTAGE` prints an empty
  section. MangoHud's own `gpu_voltage` would be a permanent `0 mV` row, so it
  stays off. LACT gets the figure through NvAPI, so `gpu-voltage.service` asks
  LACT once a second and publishes to `/dev/shm/gpu-voltage.mv`, which the overlay
  `cat`s. Same pattern as the pins and the peaks, for the same two reasons: one
  stats query costs ~16 ms (fine once a second, absurd at the overlay's refresh
  rate), and Steam's container has no `lact` binary inside it.
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
| which items show | one line each in `MangoHud.conf`. Delete or comment a line to drop it. |
| order on screen | **the order blocks appear in the file.** Moving the `12V PINS` block above the GPU block puts the currents at the top. Verified. |
| position | `position=` — `top-left`, `top-center`, `top-right`, `middle-left`, `middle-right`, `bottom-left`, `bottom-center`, `bottom-right`. Or `Shift+F11` in-game with no editing. |
| font, size, colours | `font_size`, `*_color` |
| FPS cap | `fps_limit=` — a list; `Shift+F1` cycles it. 276 is first, to leave G-Sync headroom under 280 Hz. |
| toggle key | `toggle_hud=slash` |
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

**The `lact cli` trap, which shipped a wrong reading once.** `lact cli stats` with
no `-g` silently selects GPU 0 — the Radeon iGPU — and prints *its* voltage and
clocks with no warning. The numbers look perfectly plausible (~1170 mV while the
5090 was at 980 mV), which is exactly why it got past review. Always pass the GPU
id, and note `-g` is a flag on `lact cli`, **not** on `stats`, so it goes *before*
the subcommand:

```bash
lact cli -g 10DE:2B85-1043:89E3-0000:01:00.0 stats
```

`~/.local/bin/gpu-voltage` has the id at the top as `GPU_ID`; that is the line to
change on other hardware. `lact cli list-gpus` prints the ids.

**Steam has to be fully quit and restarted** for a change to `MANGOHUD=1` to
reach games. Changes to `MangoHud.conf` itself need only `Shift_L+F4`.

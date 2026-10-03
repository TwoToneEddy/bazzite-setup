# Frame pacing diagnostics

A read-only audit of a running game plus a MangoHud CSV analyser. Uses Python 3's
standard library: no build, pip, installation, root, or services required. Run it
from this checkout on Bazzite. It only writes reports you explicitly request,
refuses to overwrite them, and never edits gaming settings.

**This is a first diagnostic step, not an end-to-end frame pacing meter.** It can
find configured limiter candidates and quantify uneven application frames. It
cannot declare a visibly choppy game smooth because MangoHud's timings look good.
It does not capture KWin presentation timestamps, page-flip intervals, repeated
images, or the light leaving the panel. Hardware integration has not yet been
validated on Bazzite; parser/statistical tests run on another Linux system.

## Start with the Witcher 3

Launch the game, then in a terminal in this repository:

```bash
python3 tools/frame-pacing/frame-pacing.py audit
```

Find the actual `witcher3.exe` PID in `game_candidates` (not a launcher or
wineserver), then use that number in place of `12345`:

```bash
python3 tools/frame-pacing/frame-pacing.py audit --pid 12345 --delay 10 --output witcher-audit.json
```

Return focus to the game during those ten seconds. The snapshot records:

- Selected limiter/HDR/backend environment requests from the running process.
- Loaded MangoHud and Wine window-system library names, as supporting evidence.
- Limiter and logging options from candidate MangoHud and DXVK configurations.
- Witcher `user.settings` and `dx12user.settings` under the game's Wine prefix,
  when that prefix is available. Both are candidates, not assumed active.
- KScreen output state and optional `drm_info -j` output, with explicit errors
  when tools or permissions are missing. Nothing is installed automatically.
- Gamescope processes and their options before `--`, without assuming that a
  gamescope process belongs to the selected game.

`limiter_review` pulls saved limiter candidates together. No entry means **unknown**,
not unlimited. `fps_limit=250,0` lists cap choices: it does not prove 250 is active,
because the hotkey can select unlimited. Configuration precedence and reloads
are not inferred. `PROTON_ENABLE_WAYLAND=1` is a request, not proof of presentation
through Wayland. The presence of both display environment variables proves neither.

If the prefix/config isn't found, pass the actual saved file explicitly:

```bash
python3 tools/frame-pacing/frame-pacing.py audit --pid 12345 \
  --game-config '/path/to/The Witcher 3/dx12user.settings'
```

The report filters environment/config keys instead of dumping arbitrary values
or Steam account files. It still contains local paths, game identifiers, display
identifiers, and hardware details; review before sharing. JSON is printed unless
`--output` is given. Keep captures outside version control.

## Measure application-side pacing

This repo's `90-limiter.conf` already requests `log_interval=0` (per frame) and
logs under `~/mangohud-logs`. Confirm the running game's configuration and logging
location in the audit. No launch-option changes are required for that setup.

1. Let shaders/load-in settle; choose a repeatable 30–60 second route or camera pan.
2. Note the monitor/output, refresh rate, the overlay's **active** FPS cap,
   in-game VSync/limit, Reflex and frame-generation state. Record these yourself;
   this tool does not reliably observe all of them.
3. Press **left Shift+F2** to start logging, repeat the movement, then press it
   again to stop. Exclude menus/loading by controlling when logging starts/stops.
4. Analyse the new CSV, **not** its `_summary.csv`. Use the intended cap as the
   target; the following 60 FPS is an example, not a recommended setting:

```bash
python3 tools/frame-pacing/frame-pacing.py analyze \
  ~/mangohud-logs/witcher3_YOUR_CAPTURE.csv \
  --per-frame --target-fps 60 --html witcher-pacing.html
```

Open `witcher-pacing.html` in a browser. It is a standalone report with an SVG
frametime graph and all statistics, with no network requests. Large logs use
min/max buckets so isolated spikes are preserved. The horizontal axis is sample
index, not wall-clock time; individual worst samples include elapsed timestamps
when the CSV has them.

`--per-frame` means **you confirmed log_interval=0 during this capture**. The CSV
does not encode that setting. Without confirmation the tool reports sample
statistics but refuses to assess all frames. Clearly sparse timestamp intervals
also force an incomplete result, even with that flag. This is a conservative
sanity check, not proof that no frames are missing.

The report includes median, p95/p99 and maximum milliseconds, median absolute
deviation, p95 absolute change between successive samples, counts above 50 ms,
and the ten slowest samples. It flags any sample above 1.5 times the target frame
budget, or p95 successive variation above 25% of that budget. Without a target,
it uses the capture median. These are transparent **heuristics**, not validated
perceptual thresholds. A stable but too-low frame rate can look poor without
triggering a relative-variation check. Counts refer to samples, not distinct
stutter episodes, missed refreshes or duplicated images. Frame generation further
complicates how application samples relate to displayed frames.

## When the graph looks good but the game doesn't

That is a useful result: application-side timing has not explained the symptom.
It is **not** a clean bill of health for KWin, VRR, the monitor, or game animation.

Check the live monitor refresh counter with the game focused; see
[the repo's VRR guide](../../13-vrr/README.md). KScreen policy and the DRM
`VRR_ENABLED` property are configuration evidence, not measured display intervals.
Alt-tabbing to collect a snapshot can change that state, hence `--delay`.

A true next stage needs a validated game/compositor presentation capture or an
external high-speed recording. MangoHud also has an FCAT colour-strip facility
for analysing an image stream, but this tool does not decode it. Screen recording
can itself alter pacing and may resample frames; it isn't a substitute for panel
measurement. Don't change multiple caps/HDR/VRR settings to chase a clean graph.
Make one controlled comparison at a time and retain both audit and log.

## Development and sources

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tools/frame-pacing -v
```

Tests cover steady/alternating/hitch captures, sparse logging, versioned headers,
nanosecond timestamps, invalid data, filtered process evidence and safe report
creation. The tool rejects malformed samples rather than quietly deleting them.
Missing optional commands are recorded as unavailable. No installer or status
component was added because there is no persistent service to install or verify.

Format/API references checked during implementation:

- [MangoHud logging source](https://github.com/flightlessmango/MangoHud/blob/master/src/logging.cpp): sample header, frametime and elapsed nanoseconds.
- [MangoHud example config](https://github.com/flightlessmango/MangoHud/blob/master/data/MangoHud.conf): logging, active-cap display, presentation display options and FCAT.
- [drm_info](https://github.com/emersion/drm_info): optional read-only DRM query, JSON output.

Upstream versions can change. Missing or differently formatted evidence should
be treated as unavailable, never as proof that a feature is off.

#!/usr/bin/env python3
"""Read-only gaming audit and MangoHud sample analysis; Python standard library only."""
import argparse
import csv
import datetime
import html
import json
import math
import os
from pathlib import Path
import re
import statistics
import subprocess
import sys
import time

ENV_KEYS = {
    'MANGOHUD', 'MANGOHUD_CONFIGFILE', 'DXVK_FRAME_RATE', 'DXVK_CONFIG_FILE',
    'VKD3D_FRAME_RATE', 'PROTON_ENABLE_WAYLAND', 'PROTON_ENABLE_HDR', 'DXVK_HDR',
    '__GL_SYNC_TO_VBLANK', '__GL_MaxFramesAllowed', '__GL_VRR_ALLOWED',
    '__GL_GSYNC_ALLOWED', 'vblank_mode', 'MESA_VK_WSI_PRESENT_MODE',
    'VKD3D_CONFIG', 'WINEPREFIX', 'SteamAppId', 'SteamGameId',
    'XDG_SESSION_TYPE', 'WAYLAND_DISPLAY', 'DISPLAY',
}
MANGO_KEYS = {
    'fps_limit', 'fps_limit_method', 'vsync', 'gl_vsync', 'log_interval',
    'output_folder', 'toggle_fps_limit', 'toggle_logging', 'show_fps_limit',
    'read_cfg', 'present_mode', 'display_server',
}
GAME_KEYS = {'vsync', 'limitfps', 'maxfps', 'frameratelimit', 'fullscreenmode',
             'fullscreen', 'borderless', 'reflex', 'nvreflex', 'framegeneration',
             'dlssframegeneration', 'dxgi.maxframerate', 'dxgi.syncinterval',
             'd3d9.maxframerate', 'd3d9.presentinterval'}
LIMITS = (
    'Screen-delivery pacing: UNKNOWN. No presentation timestamps or panel measurements collected.',
    'Actual game backend, swapchain present mode, active hotkey cap, in-game limiter and VRR use '
    'require confirmation. Environment and saved configuration are requests, not proof.',
)


def read(path):
    return Path(path).read_text(errors='replace')


def settings(text, keys):
    result = []
    for line in text.splitlines():
        line = line.split('#', 1)[0].strip()
        if not line or line.startswith((';', '[')):
            continue
        key, sep, value = line.partition('=')
        if key.strip().lower() in keys:
            result.append({'key': key.strip(), 'value': value.strip() if sep else 'enabled'})
    return result


def command(argv):
    try:
        p = subprocess.run(argv, capture_output=True, text=True, timeout=8)
        return {'command': argv, 'returncode': p.returncode,
                'output': p.stdout.strip(), 'error': p.stderr.strip()}
    except (OSError, subprocess.TimeoutExpired) as e:
        return {'command': argv, 'unavailable': str(e)}


def process(pid, proc=Path('/proc')):
    base = proc / str(pid)
    env = dict(item.split('=', 1) for item in
               (base / 'environ').read_bytes().decode(errors='replace').split('\0') if '=' in item)
    args = (base / 'cmdline').read_bytes().decode(errors='replace').split('\0')
    maps = read(base / 'maps')
    # No full environment, command line, memory maps or Steam account files in reports.
    result = {'pid': pid, 'name': read(base / 'comm').strip(),
              'executable_arguments': [Path(x.replace('\\', '/')).name for x in args
                                       if x.lower().endswith('.exe')],
              'environment_requests': {k: v for k, v in env.items() if k in ENV_KEYS},
              'mapped_libraries': sorted(set(re.findall(
                  r'[^/\s]*(?:MangoHud|winewayland|winex11|libwayland-client|libX11)[^/\s]*', maps)))}
    if 'MANGOHUD_CONFIG' in env:
        # Only diagnostic options; never dump arbitrary exec commands from MangoHud.
        result['mangohud_inline_requests'] = settings(
            re.sub(r',(?=[A-Za-z_][A-Za-z_0-9]*(?:=|,|$))', '\n', env['MANGOHUD_CONFIG']), MANGO_KEYS)
    if 'DXVK_CONFIG' in env:
        result['dxvk_inline_requests'] = settings(env['DXVK_CONFIG'].replace(';', '\n'), GAME_KEYS)
    return result, env


def candidates():
    rows = []
    for base in Path('/proc').iterdir():
        if not base.name.isdigit():
            continue
        try:
            if base.stat().st_uid != os.getuid():
                continue
            args = (base / 'cmdline').read_bytes().decode(errors='replace').split('\0')
            exes = [Path(a.replace('\\', '/')).name for a in args if a.lower().endswith('.exe')]
            if exes:
                rows.append({'pid': int(base.name), 'name': read(base / 'comm').strip(), 'exe': exes})
        except OSError:
            pass
    return sorted(rows, key=lambda r: r['pid'])


def audit(args):
    if args.delay:
        print(f'Waiting {args.delay:g}s; focus the game now.', file=sys.stderr)
        time.sleep(args.delay)
    result = {'captured_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'limitations': list(LIMITS), 'files': [], 'observations': []}
    env = os.environ.copy()
    if args.pid:
        result['process'], env = process(args.pid)
    else:
        result['game_candidates'] = candidates()
        result['limitations'].append('No PID selected: configuration belongs to this shell user, not a verified game.')
    home = Path(env.get('HOME', str(Path.home())))
    config = Path(env.get('XDG_CONFIG_HOME', str(home / '.config')))
    paths = [(config / 'MangoHud/MangoHud.conf', MANGO_KEYS, 'MangoHud global candidate')]
    paths += [(p, MANGO_KEYS, 'MangoHud per-application candidate')
              for p in sorted((config / 'MangoHud').glob('*.conf')) if p.name != 'MangoHud.conf']
    for key, keys in [('MANGOHUD_CONFIGFILE', MANGO_KEYS), ('DXVK_CONFIG_FILE', GAME_KEYS)]:
        if env.get(key):
            path = Path(env[key])
            if not path.is_absolute() and args.pid:
                path = Path('/proc') / str(args.pid) / 'cwd' / path
            paths.append((path, keys, key))
    if args.pid:
        paths.append((Path('/proc') / str(args.pid) / 'cwd/dxvk.conf', GAME_KEYS, 'DXVK working-directory candidate'))
    if env.get('WINEPREFIX'):
        prefix = Path(env['WINEPREFIX'])
        for user in sorted((prefix / 'drive_c/users').glob('*')):
            for name in ('user.settings', 'dx12user.settings'):
                paths.append((user / 'Documents/The Witcher 3' / name, GAME_KEYS, 'Witcher 3 saved settings'))
    paths += [(Path(p).expanduser(), GAME_KEYS, 'User-supplied game settings') for p in args.game_config]
    for path, keys, purpose in paths:
        entry = {'path': str(path), 'purpose': purpose, 'status': 'configured only; selection/reload not verified'}
        try:
            entry['settings'] = settings(read(path), keys)
        except OSError as e:
            entry['unavailable'] = str(e)
        result['files'].append(entry)
    # Read-only queries. No D-Bus mutation, sudo, tracing setup, or changes to the session.
    for argv in (['kscreen-doctor', '-o'], ['drm_info', '-j'],
                 ['rpm', '-q', 'MangoHud', 'gamescope', 'kwin', 'xorg-x11-drv-nvidia'],
                 ['uname', '-r']):
        result['observations'].append(command(argv))
    result['limitations'].append('DRM properties, if readable, show kernel configuration at this instant; '
                                'VRR_ENABLED is not a measurement of refresh intervals or fresh game frames. '
                                'Changing focus may change VRR policy.')
    result['limiter_review'] = []
    for entry in result['files']:
        for setting in entry.get('settings', []):
            if setting['key'].lower() in {'fps_limit', 'vsync', 'gl_vsync', 'limitfps',
                                         'maxfps', 'frameratelimit', 'dxgi.maxframerate',
                                         'dxgi.syncinterval', 'd3d9.maxframerate', 'd3d9.presentinterval'}:
                result['limiter_review'].append({**setting, 'source': entry['path'],
                                                'evidence': 'saved candidate; active value UNKNOWN'})
    result['next_checks'] = [
        'Read the active cap from MangoHud show_fps_limit while playing; Shift+F1 can change it without changing the file.',
        'Check VSync, frame limit, Reflex and frame generation in the game menu; saved files may be stale or for the other renderer.',
        'While the game is focused, compare the monitor live refresh counter with FPS. A static VRR-enabled label is insufficient.',
        'If application times are steady but motion judders, screen-delivery timing and game animation remain unresolved; do not dismiss the symptom.',
    ]
    result['limitations'].append('Config candidates are not a reconstruction of configuration precedence. '
                                'Steam/Flatpak mount namespaces and application overrides can hide files. '
                                'Library mappings show loaded code, not which backend is presenting.')
    # Find gamescope without storing child game arguments or unrelated launch credentials.
    result['gamescope_processes'] = []
    for base in Path('/proc').iterdir():
        if not base.name.isdigit():
            continue
        try:
            if read(base / 'comm').strip() == 'gamescope':
                argv = (base / 'cmdline').read_bytes().decode(errors='replace').split('\0')
                result['gamescope_processes'].append({'pid': int(base.name),
                    'options': argv[1:argv.index('--')] if '--' in argv else ['unknown: no -- delimiter'],
                    'relationship_to_game': 'unverified'})
        except OSError:
            pass
    return result


def load_csv(path):
    samples, header = [], None
    with open(path, newline='', encoding='utf-8-sig') as f:
        for line, row in enumerate(csv.reader(f), 1):
            normalized = [v.strip().lower() for v in row]
            if header is None:
                if 'frametime' in normalized and 'fps' in normalized:
                    header = normalized
                continue
            if not row or not any(v.strip() for v in row):
                continue
            try:
                frame = float(row[header.index('frametime')])
                elapsed = float(row[header.index('elapsed')]) / 1e9 if 'elapsed' in header else None
                if not math.isfinite(frame) or frame <= 0:
                    raise ValueError('frametime must be finite and positive')
                if elapsed is not None and (not math.isfinite(elapsed) or elapsed < 0):
                    raise ValueError('elapsed must be finite and nonnegative')
                if samples and elapsed is not None and elapsed <= samples[-1][0]:
                    raise ValueError('elapsed timestamps must strictly increase; use one capture per file')
                samples.append((elapsed, frame))
            except (ValueError, IndexError) as e:
                raise ValueError(f'{path}:{line}: invalid sample ({e})') from e
    if len(samples) < 2:
        raise ValueError('Need at least two samples with a fps,frametime header; summary CSVs are not supported.')
    return samples


def percentile(values, q):
    ordered = sorted(values)
    index = (len(ordered) - 1) * q
    low = math.floor(index)
    return ordered[low] + (ordered[math.ceil(index)] - ordered[low]) * (index - low)


def analyze(samples, target=None, per_frame=False):
    frames = [s[1] for s in samples]
    median = statistics.median(frames)
    budget = 1000 / target if target else median
    threshold = 1.5 * budget
    count = sum(f > threshold for f in frames)
    cadence = None
    if samples[0][0] is not None:
        cadence = statistics.median([(b[0] - a[0]) * 1000 for a, b in zip(samples, samples[1:])])
    sparse = cadence is not None and cadence > median * 1.5
    trusted = per_frame and not sparse
    result = {
        'scope': 'Application-side MangoHud samples; screen-delivery pacing remains UNKNOWN',
        'samples': len(frames), 'per_frame_confirmed_by_user': per_frame,
        'sampling_warning': 'Likely sparse logging or missing frames' if sparse else
                            ('Per-frame capture asserted by user, not proven by CSV' if per_frame else
                             'Sampling mode unknown; pass --per-frame only if log_interval=0 during capture'),
        'median_logging_interval_ms': cadence,
        'median_ms': median, 'p95_ms': percentile(frames, .95),
        'p99_ms': percentile(frames, .99), 'max_ms': max(frames),
        'median_absolute_deviation_ms': statistics.median([abs(f - median) for f in frames]),
        'successive_difference_p95_ms': percentile([abs(b - a) for a, b in zip(frames, frames[1:])], .95),
        'reference': f'{target:g} FPS target' if target else 'capture median (no target supplied)',
        'reference_ms': budget, 'long_sample_threshold_ms': threshold,
        'long_samples': count, 'long_samples_percent': 100 * count / len(frames),
        'over_50_ms': sum(f > 50 for f in frames),
        'largest_samples': [{'sample': i + 1, 'elapsed_s': samples[i][0], 'frametime_ms': f}
                            for i, f in sorted(enumerate(frames), key=lambda v: v[1], reverse=True)[:10]],
    }
    if not trusted:
        result['assessment'] = 'INCOMPLETE: sample statistics only; cannot assess all rendered frames.'
    elif count or result['successive_difference_p95_ms'] > budget * .25:
        result['assessment'] = 'Application-side unevenness detected by the stated heuristic; cause unknown.'
    else:
        result['assessment'] = 'No large application-side unevenness detected by the stated heuristic; visible smoothness unverified.'
    result['heuristic'] = 'Flags any sample >1.5x reference, or p95 successive difference >25% of reference. '
    result['heuristic'] += 'These are descriptive thresholds, not perceptual standards, missed-refresh counts or limiter identification.'
    return result


def html_report(path, result, samples):
    # Min/max per bucket preserves spikes instead of dropping them in large logs.
    frames = [s[1] for s in samples]
    maximum = max(max(frames), result['reference_ms'])
    width, height = 1000, 260
    bucket = max(1, math.ceil(len(frames) / width))
    lines = []
    for start in range(0, len(frames), bucket):
        part = frames[start:start + bucket]
        x = start / max(1, len(frames) - 1) * width
        y1, y2 = (height - v / maximum * (height - 10) for v in (min(part), max(part)))
        lines.append(f'<line x1="{x:.2f}" x2="{x:.2f}" y1="{y1:.2f}" y2="{y2 + .8:.2f}"/>')
    ref_y = height - result['reference_ms'] / maximum * (height - 10)
    page = ('<!doctype html><meta charset="utf-8"><title>Frame pacing report</title>'
            '<style>body{font:16px system-ui;max-width:1100px;margin:2em auto;padding:1em;'
            'background:#141821;color:#e8edf6}pre{white-space:pre-wrap}svg{width:100%;background:#202735}</style>'
            '<h1>Application frame times</h1><p>Screen-delivery pacing: UNKNOWN. '
            'This graph cannot establish that the game looks smooth.</p>'
            f'<p>Horizontal: sample index 1–{len(frames)}. Vertical: 0–{maximum:.2f} ms; '
            'higher means slower. Blue: min/max per bucket; orange: reference.</p>'
            f'<svg role="img" aria-label="Application frametime graph" viewBox="0 0 {width} {height}">'
            '<g stroke="#72b7ff">' + ''.join(lines) + '</g>'
            f'<path stroke="#ffb454" stroke-dasharray="6 4" d="M0 {ref_y}H{width}"/></svg>'
            '<pre>' + html.escape(json.dumps(result, indent=2)) + '</pre>')
    with open(path, 'x', encoding='utf-8') as f:
        f.write(page)


def positive(value):
    number = float(value)
    if not math.isfinite(number) or number <= 0:
        raise argparse.ArgumentTypeError('must be finite and positive')
    return number


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    ap = sub.add_parser('audit', help='read running-game settings and available display state')
    ap.add_argument('--pid', type=int, help='actual game process PID; omit to list candidates')
    ap.add_argument('--game-config', action='append', default=[], help='extra saved game settings file')
    ap.add_argument('--delay', type=positive, default=0, help='seconds to refocus game before snapshot')
    ap.add_argument('--output', type=Path, help='save JSON to a NEW file instead of stdout')
    lp = sub.add_parser('analyze', help='analyze a MangoHud CSV without claiming display timing')
    lp.add_argument('csv', type=Path)
    lp.add_argument('--target-fps', type=positive)
    lp.add_argument('--per-frame', action='store_true', help='confirm log_interval=0 for this capture')
    lp.add_argument('--html', type=Path, help='also write a standalone graph to a NEW file')
    args = parser.parse_args()
    try:
        if args.action == 'audit':
            result = audit(args)
            if args.output:
                with args.output.open('x', encoding='utf-8') as f:
                    json.dump(result, f, indent=2)
                print(f'Saved {args.output}')
            else:
                print(json.dumps(result, indent=2))
        else:
            samples = load_csv(args.csv)
            result = analyze(samples, args.target_fps, args.per_frame)
            if args.html:
                html_report(args.html, result, samples)
            print(json.dumps(result, indent=2))
    except (OSError, ValueError) as e:
        parser.exit(1, f'frame-pacing: {e}\n')


if __name__ == '__main__':
    main()

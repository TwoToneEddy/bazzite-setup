#!/usr/bin/env python3
"""Read-only, bounded freeze capture. No attachment to or modification of the game."""
import argparse
import datetime
import json
import os
from pathlib import Path
import signal
import subprocess
import time


def read(path):
    try:
        return Path(path).read_text().strip()
    except (OSError, UnicodeError):
        return None


def stamp():
    return datetime.datetime.now().astimezone().isoformat(timespec='milliseconds')


def sample(pid):
    threads = []
    for task in Path(f'/proc/{pid}/task').glob('*'):
        stat = read(task / 'stat')
        if not stat:
            continue
        fields = stat[stat.rfind(')') + 2:].split()
        threads.append(dict(tid=int(task.name), name=read(task / 'comm'),
                            state=fields[0], ticks=int(fields[11]) + int(fields[12]),
                            wait=read(task / 'wchan')))
    return dict(time=stamp(), monotonic=time.monotonic(), threads=threads,
                cpu=read('/proc/stat'), memory=read('/proc/meminfo'),
                pressure={p: read(f'/proc/pressure/{p}') for p in ('cpu', 'io', 'memory')},
                game_io=read(f'/proc/{pid}/io'), game_status=read(f'/proc/{pid}/status'),
                disk=read('/proc/diskstats'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pid', type=int, help='Actual HuntGame.exe PID; auto-detected if unique')
    parser.add_argument('--output', type=Path, required=True, help='New private capture directory')
    parser.add_argument('--seconds', type=int, default=10800, help='Maximum duration (default 3 hours)')
    parser.add_argument('--no-gpu', action='store_true', help='Skip NVIDIA polling for an observer-effect comparison')
    args = parser.parse_args()
    if args.seconds < 1:
        parser.error('--seconds must be positive')
    if args.pid is None:
        # Under Wine, comm is the main thread's name ("Main"), so match argv[0] instead.
        candidates = [int(p.name) for p in Path('/proc').glob('[0-9]*')
                      if (read(p / 'cmdline') or '').split('\0')[0].replace('\\', '/')
                      .lower().endswith('/huntgame.exe')]
        if len(candidates) != 1:
            parser.error(f'Expected one HuntGame process, found {candidates}; use --pid')
        args.pid = candidates[0]
    if not Path(f'/proc/{args.pid}/stat').exists():
        parser.error('PID does not exist')
    os.umask(0o077)
    args.output.mkdir(parents=True, exist_ok=False)
    children, files = [], []
    stopping = False

    def stop(*_):
        nonlocal stopping
        stopping = True

    def mark(*_):
        with (args.output / 'markers.txt').open('a') as f:
            f.write(stamp() + ' user marked recent freeze\n')

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGUSR1, mark)
    (args.output / 'capture.pid').write_text(str(os.getpid()) + '\n')
    metadata = dict(start=stamp(), game_pid=args.pid, game_name=read(f'/proc/{args.pid}/comm'),
                    kernel=os.uname().release, clock_ticks=os.sysconf('SC_CLK_TCK'),
                    gpu_polling=not args.no_gpu, interval_seconds=1)
    (args.output / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')

    def launch(name, cmd):
        f = (args.output / name).open('w')
        files.append(f)
        try:
            children.append((name, subprocess.Popen(cmd, stdout=f, stderr=subprocess.STDOUT,
                                                   start_new_session=True)))
        except OSError as e:
            f.write(str(e) + '\n')
            f.flush()

    launch('kernel.log', ['journalctl', '-k', '-f', '-n', '0', '-o', 'short-iso-precise', '--no-pager'])
    launch('kwin.log', ['journalctl', '--user', '-f', '-n', '0', '-o', 'short-iso-precise',
                        '--no-pager', '_COMM=kwin_wayland'])
    if not args.no_gpu:
        launch('gpu.csv', ['nvidia-smi',
               '--query-gpu=timestamp,index,utilization.gpu,utilization.memory,power.draw,temperature.gpu,clocks.gr,clocks.mem,fan.speed,pstate',
               '--format=csv', '--loop=1'])
    print(f'Capturing PID {args.pid} into {args.output}; Ctrl+C stops. Maximum {args.seconds}s.', flush=True)
    print(f'After a freeze: kill -USR1 {os.getpid()} (marks the time only).', flush=True)
    started = time.monotonic()
    reported = set()
    try:
        with (args.output / 'samples.jsonl').open('w', buffering=1) as f:
            while not stopping and time.monotonic() - started < args.seconds:
                if not Path(f'/proc/{args.pid}').exists():
                    break
                tick = time.monotonic()
                f.write(json.dumps(sample(args.pid)) + '\n')
                for name, child in children:
                    if child.poll() is not None and name not in reported:
                        print(f'Collector {name} exited ({child.returncode}); check its log.', flush=True)
                        reported.add(name)
                time.sleep(max(0, 1 - (time.monotonic() - tick)))
    finally:
        status = {}
        for name, child in children:
            if child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait()
            status[name] = child.returncode
        for f in files:
            f.close()
        (args.output / 'completion.json').write_text(json.dumps(dict(end=stamp(), collectors=status), indent=2) + '\n')
        print('Capture stopped. Check collector logs for unavailable metrics or permission errors.')


if __name__ == '__main__':
    main()

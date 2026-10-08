# Hunt freeze capture

Start Hunt, then run from the repository in a terminal:

```bash
python3 tools/hunt-capture/capture.py --output "$HOME/hunt-captures/$(date +%Y%m%d-%H%M%S)"
```

Leave it running during play. It finds the unique `HuntGame` process, samples once
per second, and stops when the game exits, after three hours, or with Ctrl+C.
If detection fails, supply `--pid` with the actual game PID. No sudo is needed.
Keep MangoHud disabled and keep gameplay settings fixed for the capture.

After a freeze, run the `kill -USR1 NUMBER` command printed at startup to mark
the time. This signals the recorder, not the game. Alternatively note the clock
time and approximate duration. Marking after Alt-Tab also records the effect of
switching focus, so distinguish that from the freeze itself.

The private output directory contains:

- `samples.jsonl`: timestamped cumulative per-thread CPU ticks, thread state and
  kernel wait channel, system CPU/memory/IO pressure and disk counters, game IO.
  CPU use is calculated from differences between samples, not absolute ticks.
- `gpu.csv`: NVIDIA utilisation, power, temperature, clocks, GPU fan percentage,
  and performance state. This does not measure case/CPU fan RPM.
- `kernel.log`, `kwin.log`: new kernel and KWin user-journal events.
- Metadata, completion status, and optional freeze markers.

Missing permissions/metrics are recorded as null or in collector logs. A wait
channel of `0` is not proof a thread is running: visibility may be restricted.
Kernel wait channels do not provide userspace backtraces. These observations can
narrow down a wait, pressure spike, or GPU idle period; they cannot alone prove
its root cause. The recorder does not attach a debugger, change game files,
alter clocks, or stop per-pin alarms.

NVIDIA polling itself can affect timing. Use `--no-gpu` for a separate comparison
if needed. A single persistent `nvidia-smi` process polls once a second; no new
process is spawned per sample. Capture sizes grow with game thread count, so
retain only useful sessions. Review logs before sharing; raw captures stay out
of the repository. No automatic uploads occur.

This uses the Python standard library, journalctl and optionally nvidia-smi.
An end-to-end capture during a real Hunt freeze remains to be validated.

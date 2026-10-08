# Hunt freezes with MangoHud — ongoing investigation

Recorded 2026-10-06; updated 2026-10-07. **Root cause remains unknown.** Longer
play weakened the initial MangoHud hypothesis: the user thought freezes were
less frequent but was not convinced. Keep this record updated as sessions are tested.

## Follow-up on 2026-10-07

- User hears the fans slow down during the freeze. Together with the earlier
  MangoHud utilisation drops, this is consistent with reduced workload during
  the stall, but is not a measured fan-RPM/power trace and does not identify its
  cause. No evidence yet establishes a fan-control fault or thermal throttling.
- User confirms these freezes **predated installation of per-pin sensing**.
  The per-pin daemon therefore cannot explain their original onset. Keep its
  monitoring and alarm enabled; do not prioritize disabling it for this symptom
  without new evidence of a separate contribution.
- User also reports CPU and GPU utilisation dropping to zero in MangoHud during
  earlier freezes, before disabling it. No independent utilisation capture exists
  for the latest MangoHud-disabled freeze. Treat this as reported telemetry,
  not proof of both devices actually doing no work.
- User confirmed a freeze within roughly ten minutes before reporting it:
  visuals froze for about **five seconds and recovered automatically**, while
  both game audio and Discord comms continued. This confirms recurrence with
  MangoHud disabled, so MangoHud is not required for this symptom. It does not
  exclude MangoHud contributing to other stalls. This transient stall differs
  from the persistent freeze described in the upstream DLSS report.
- The latest Hunt Proton log confirms `MANGOHUD: 0`, GE-Proton11-7, and
  `PROTON_DLSS_UPGRADE: 1`. It also confirms loading the redirected DLSS DLL
  from `c:\windows\system32\umu`, rather than the game's bundled DLL.
- Another Steam graphics-query helper crash occurred at 19:03:17 BST (PID 4221),
  again on `mangohud-amdgpu`. Disabling MangoHud for Hunt does not disable it
  for Steam's startup helpers; this does not show that Hunt's override failed.
- No NVIDIA Xid or OOM-kill evidence was found in the current boot's kernel log.
  The Proton log contained no matches for the checked device-lost/removed/hung,
  unhandled-exception or `err:vkd3d` patterns. Its handled exceptions and warning
  messages alone do not identify a freeze cause.
- Next proposed single-variable test: keep MangoHud off and add
  `PROTON_DLSS_UPGRADE=0` to Hunt's existing launch options. Keep HDR, Wayland,
  Proton version and other overrides fixed. The older upstream DLSS freeze
  report below motivates this test but does not establish the cause here.
- LACT's saved profile remains UV1; testing stock GPU settings is a separate
  possible follow-up, not a change performed during this investigation.

## Observations

- Hunt froze with MangoHud enabled. After testing with `MANGOHUD=0`, the user
  reported “not a single freeze”. Session duration and match count were not
  recorded; longer testing is pending.
- Disabling MangoHud also disables its FPS limiter. This test does not isolate
  overlay rendering, sensor polling, custom commands, or frame limiting.
- At 19:31:33 BST, `coredumpctl info 35298` identified a SIGSEGV in Steam's
  `d3ddriverquery64.exe`, on thread `mangohud-amdgpu`, using proton-cachyos-slr.
  This happened **before Hunt launched** with GE-Proton. It is a separate crash
  and a useful lead, not a backtrace of Hunt's freeze. The available trace had
  unresolved frames in `ntdll.so` and libc; the thread name alone does not prove
  the faulty instruction was in MangoHud.
- Steam's startup output included `double free or corruption (out)` and
  `free(): invalid size`. Their precise origin was not established.
- The inspected boot's kernel journal contained no NVIDIA Xid errors or OOM
  kills. That does not rule out a userspace hang or hardware instability.
- Prefix-version warnings referred to `compatdata/0`, not Hunt's `594650`
  prefix. No prefix or shader cache was deleted.

## Environment at the time

| Item | Observed value |
|---|---|
| OS / kernel | CachyOS / `7.2.9-1-cachyos` |
| GPU | RTX 5090, PCI `0000:01:00.0`; AMD integrated GPU also present |
| NVIDIA userspace driver, both architectures | `615.71.09-1` |
| MangoHud | `0.8.4-1.1` |
| lib32-mangohud | `0.8.4-1` |
| Hunt Proton | GE-Proton11-7 |
| Presentation settings | `PROTON_ENABLE_WAYLAND=1`, `PROTON_ENABLE_HDR=1` |
| Global DLSS setting | `PROTON_DLSS_UPGRADE=1` |
| LACT saved configuration | `current_profile: UV1`, automatic switching off |

LACT's configuration was read, not changed; actual voltage/clock stability was
not verified. The different MangoHud package release suffixes are recorded for
reproducibility, not evidence of an incompatibility.

The proposed test launch options preserved the existing overrides and added
MangoHud disabling plus Proton logging:

```text
MANGOHUD=0 PROTON_LOG=1 DXVK_NVAPI_DRS_SETTINGS=0x00634291=0x2,0x10E41DF3=0xC PROTON_ENABLE_NVAPI=1 PROTON_ENABLE_WAYLAND=1 PROTON_ENABLE_HDR=1 %command%
```

The user reported success after this recommendation; the exact effective process
environment was not captured. `PROTON_LOG=1` can be removed for routine play;
when enabled its log is `~/steam-594650.log`.

## Per-pin alarm remains independent

Verified separately on 2026-10-06:

- `astral-pins.service` was active and enabled at boot; its shared-memory feed
  updated across two readings two seconds apart.
- The running command samples once per second, warns at **9.0 A on any pin**,
  and invokes `/usr/local/bin/astral-pins-alarm`, repeating every 30 seconds.
- The source triggers at `peak >= 9.0` and clears below `8.5` A. MangoHud only
  reads the exported values; it does not drive this alarm logic.
- The built-in simulated alarm successfully submitted a notification. A direct
  test of the same alarm script returned `alarm notification rc=0` and
  `alarm sound rc=0 (4x)`. The default audio sink was unmuted at 100%.
- Software delivery succeeded; actual audibility in a game was not confirmed.
  No real overload was induced, and the configured threshold was not changed.

This is a sampled, warning-only monitor, not an automatic shutdown mechanism.
See [the per-pin component](../05-per-pin-current/README.md).

## Next steps, after more baseline play

For pre-emptive logging without MangoHud, use the
[Hunt capture tool](../tools/hunt-capture/README.md). It records timestamped
thread CPU/wait counters, system pressure/IO, NVIDIA telemetry and new kernel/KWin
events. A three-second smoke test validated CPU/thread samples and orderly exit.
NVIDIA access failed in the agent's restricted execution environment, so GPU
capture must be verified from the user's desktop terminal. This failure does not
establish a fault in the host driver. A real freeze capture is still pending.

1. Record duration/match count with MangoHud disabled and whether any freeze
   returns. For a freeze, record time, audio behaviour, desktop responsiveness,
   and whether it recovers or requires terminating Hunt.
2. When ready to reproduce, compare with MangoHud enabled under otherwise
   unchanged conditions. Record the FPS cap: removal of the limiter is a
   confounding change in the initial test.
3. Test a separate minimal MangoHud configuration, then add feature groups one
   at a time: GPU/CPU telemetry, custom `exec` rows, and limiter. Use a dedicated
   `MANGOHUD_CONFIGFILE` rather than overwriting the assembled normal config.
   Verify what each test actually enables; hiding the HUD is not unloading it.
4. Investigate the graphics-query helper crash separately. Obtain a symbolized
   backtrace with matching binaries/debug symbols and compare against the
   installed package's source and patches. The AMD polling thread is a lead
   despite the selected overlay GPU being NVIDIA.
5. With a repeatable case, compare an isolated upstream build or bisect the
   relevant changes. Keep the known-good play configuration available. An
   upstream report should include versions, minimal config, steps, and sanitized
   logs/backtrace. Do not publish Steam configs, tokens, or raw core dumps.

No driver changes, source builds, upstream reports, or permanent overlay changes
were made as part of this investigation. Keep the per-pin daemon running during
overlay tests; preserve HDR/Wayland and avoid changing several variables at once.

## Upstream leads

Relevant existing local evidence:

- [Per-pin polling history](GAMING_SETUP_NOTES.md#12v-2x6-per-pin-currents--astral-pins):
  old byte-at-a-time reads measured 34.6 ms, replacement block reads 4.5 ms.
  These historical measurements do not explain a five-second stall by themselves.
- [Per-pin component traps](../05-per-pin-current/README.md#traps) explicitly
  flag GPU I2C polling as a generic frame-presentation stall suspect. However,
  the user confirms this symptom predates its installation, so that warning
  does not explain the original freezes. The daemon remains active with MangoHud
  disabled. No test stopping the daemon or its connector alarm was performed.
- [Overlay traps](../02-mangohud-overlay/README.md#traps) record a prior experiment
  in which custom exec rows ran off the render thread and did not worsen pacing.
  This is evidence from that experiment, not proof against all monitoring stalls.
- [Frame-pacing tools](../tools/frame-pacing/README.md) provide a read-only
  running-process audit and MangoHud CSV analysis. They do not capture thread
  waits or prove compositor/display delivery; CSV capture requires MangoHud.

- [MangoHud source and build instructions](https://github.com/flightlessmango/MangoHud)
  — open source under the MIT license; source-level debugging is possible.
- [MangoHud issue #2034](https://github.com/flightlessmango/MangoHud/issues/2034)
  — exit/double-free report; not established as this crash or freeze.
- [Hunt DLSS freeze report #368](https://github.com/jp7677/dxvk-nvapi/issues/368)
  — a report using older software with upgraded DLSS. An alternative lead if
  freezes return with MangoHud disabled, not proof against the installed versions.

## Further test results

| Date | Configuration | Duration / matches | Result |
|---|---|---|---|
| 2026-10-06 | MangoHud enabled, existing setup | Not recorded | Freezes reported |
| 2026-10-06 | MangoHud disabled | Not recorded | User reported no freezes; further testing pending |
| 2026-10-07 | MangoHud disabled (confirmed in Proton log) | Not recorded | Confirmed ~5-second visual freeze, automatic recovery; game audio and Discord continued. Frequency may be lower, unmeasured. |

## Split-lock mitigation — check this after moving distro

First clean capture (2026-10-08, 66 min on CachyOS, no freeze, `tools/hunt-capture`):
no sampling gaps, no Xid/NVRM/AER, negligible IO pressure. But 6,242 of the
kernel log's lines were `x86/split lock detection: #DB: ... took a bus_lock trap`
from Hunt's own threads — mostly `Streaming File` and `JobWorker_N`.

That is harmless **only because `kernel.split_lock_mitigate = 0`**. At the kernel
default of `1`, each trapped split lock puts the offending thread to sleep for
~10 ms, so the streaming and job threads would stall thousands of times an hour —
a plausible stutter or freeze source in its own right.

The 0 was not set by hand: CachyOS ships it in
`/usr/lib/sysctl.d/99-splitlock.conf` (package `cachyos-gaming-meta`). Bazzite is
believed to ship the same, but **this has not been verified on this machine** —
after moving back, check:

```bash
sysctl kernel.split_lock_mitigate        # want 0
```

`reference/health-check.sh` now reports it. If it reads 1, set it with a file in
`/etc/sysctl.d/` (writable on Bazzite, but per-deployment — re-check after a rollback).

The warnings are logged even with mitigation off; filter them before reading a
freeze capture: `grep -v 'split lock' kernel.log`.

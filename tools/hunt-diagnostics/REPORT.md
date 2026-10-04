# Hunt freeze investigation — 2 October 2026

Recordings stopped at 20:29 local time. Detailed sampling covers 20:02:15–20:29:17 (1,623 samples); earlier GPU/system recordings are also retained.

## Finding
The evidence strongly argues against the Ethernet adapter entering runtime suspend. It does not exclude loss or latency on the route to the game server. The recurring signature is a game-side wait: main and render threads cease doing substantial work, GPU utilization drops to zero, audio threads continue.

## Network evidence
- Default route uses enp5s0, Realtek RTL8125B, r8169 driver, 2.5 Gbit/s. Wi-Fi is disconnected.
- At inspection, power/control=on, runtime_status=active, runtime_suspended_time=0. These were inspected after gameplay, not sampled continuously.
- Energy Efficient Ethernet reports enabled but inactive at inspection.
- No Ethernet link drops or resets during the session were found in kernel logs.
- Detailed samples contain 130,052 received and 105,937 transmitted packets, with zero increases in interface errors/drops. Adapter hardware error/missed counters are also zero.
- Traffic continues each second throughout all eight multi-second low-CPU intervals identified. At 20:24:54–20:24:58, receive packet counts per second are 83,56,58,57,61; transmit counts 20,16,16,13,16.
- System-wide TCP retransmissions increased by 30 over 27 minutes, without consistent stall correlation. UDP input, checksum, receive-buffer and send-buffer errors did not increase. Six UDP NoPorts increments occurred; these do not identify remote packet loss.
- No packet capture or continuous game-server RTT measurement was collected. Interface counters include other applications and cannot establish whether Hunt's server traffic continued normally.

## Game/GPU evidence
- Repeated approximately five-second GPU idle intervals, including 20:10:39–20:10:43, 20:22:42–20:22:47, 20:24:53–20:24:58, 20:26:27–20:26:31 and 20:27:54–20:27:59.
- During corresponding low-CPU intervals, the main thread is observed in futex_do_wait and render thread usually in ntsync_schedule.isra.0. Audio threads continue consuming CPU, matching the user's report.
- These wait sites describe synchronization mechanisms, not the original cause; they do not prove an NTSYNC defect or identify a lock owner.
- No NVIDIA reset/crash messages or sampled GPU hardware thermal/power-brake slowdown flags. Power-cap flags occur elsewhere and do not establish a fault.
- No substantial system memory or I/O pressure coincident with the observed waits.
- Many bus-lock warnings exist during ordinary gameplay too. split_lock_mitigate is already 0. No causal relationship established.
- A USB monitor hub enumerated at 20:02:16–17, separate from the subsequent recurring stalls.
- Game log times appear one hour behind local time. The 19:28:06 game-log disconnect therefore corresponds to 20:28:06 local and reports MissionRequested, not an adapter link failure.

## Configuration and next experiment
GE-Proton11-7-x86_64, native Wine Wayland, HDR, NTSYNC, MangoHud, Steam overlay, DLSS replacement are enabled/present. This is context, not evidence against any individual feature.

For the next session, record timestamped gateway and external reachability plus game-flow packet timing (headers/metadata only) alongside the thread/GPU logger. This separates local-link failures from remote-server/path stalls. Then test one Proton/rendering variable at a time, preserving the original launch options. Do not change NIC power management based on this capture alone: runtime suspend is already disabled.

No game, driver or network settings were changed.

## Next-session checklist

1. Preserve the current launch options and Proton version as the baseline. Start the capture before joining a match; record the new Hunt process ID rather than reusing PID 27648.
2. Run timestamped, low-rate reachability/latency probes to the default gateway and an external endpoint. Treat missing ICMP responses cautiously: endpoints can filter or deprioritize probes.
3. Identify the current Hunt server connection and collect narrowly filtered packet timing/header metadata, avoiding payload capture. Game servers may change between matches; update the filter accordingly. If capture privileges are unavailable, document that limitation.
4. Continue game-thread wait/activity samples, GPU utilization/clocks, memory and disk pressure, game logs and kernel logs. Add continuous Ethernet carrier, error/drop counters and runtime-power status. Include wineserver activity to improve visibility into Proton waits.
5. Mark each user-reported freeze immediately with local time and whether audio continues. Capture several events and ordinary gameplay for comparison, then stop the collectors.
6. Compare each event: gateway trouble suggests a local network issue; external-only trouble suggests an upstream path issue; game-flow disruption with healthy probes suggests a server/path-specific issue. Healthy aggregate traffic alone is insufficient to clear the game connection. A change in packet timing can also be an effect of the game stalling, so examine which change begins first.
7. If network evidence stays healthy, run controlled comparisons of Proton/synchronization or the native Wayland rendering path. Verify the installed Proton version's supported toggles before changing them. Change only one variable per session, keep the same capture, and restore the baseline between tests. Do not disable several features at once or assume NTSYNC is faulty because its wait function appears in samples.

## Handoff

User suspects network-card sleep. Current evidence argues strongly against that specific mechanism but does not exclude server/path latency or game-side network waits. Root cause is unconfirmed. All collectors were stopped on user request; nothing is currently being monitored by this investigation. No game/network/driver settings were changed.

Primary detailed data: `/var/home/lee/bazzite-setup/tools/hunt-diagnostics/20261002-200215/`.
Analysis script: `/var/home/lee/bazzite-setup/tools/hunt-diagnostics/analyse.py`.
Analysis output: `/var/home/lee/bazzite-setup/tools/hunt-diagnostics/analysis-output.txt`.
Collector template: `/var/home/lee/bazzite-setup/tools/hunt-diagnostics/collect.py` (contains the old process ID; adapt before reuse).
Earlier captures also remain in `/tmp/hunt-watch/` and `/tmp/hunt-watch-continued/`; retained copies of their earlier contents are inside the primary data directory.

## Shader-compilation hypothesis checked

The sampled thread named ShaderCompile (TID 27804) accumulated zero CPU ticks across four checked freeze windows (20:10:39–44, 20:22:42–48, 20:24:53–59, 20:27:53–20:28:00), and only two ticks across 20:26:26–32. Every sampled wait site for that thread in these windows was poll_schedule_timeout.constprop.0. The two monitored vkd3d cache files in the game directory showed no size or mtime changes during the detailed capture.

This weakens the hypothesis of sustained active compilation causing these freezes, but does not rule out pipeline creation/driver compilation on another thread, a compilation-related synchronization wait, buffered cache writes, or a different active cache location. The capture did not contain driver compilation call stacks or pipeline timing. Add targeted compilation/pipeline timing diagnostics, if supported by the installed VKD3D version, to the next-session options; verify overhead and supported flags first. Preserve caches as the baseline rather than deleting them during diagnosis.

## Cross-game observation and online reports — 3 October 2026

User also observes similar freezes in ARC Raiders, and has not yet observed them in single-player games. ARC Raiders has not been instrumented here, so a common mechanism remains a hypothesis.

Firsthand reports found online:
- ARC Raiders: intermittent 4–5-second freezes that recover. Replies include NVIDIA 4090 and 50-series discussion, and a World of Warcraft comparison. Proposed graphics launch-option fixes have conflicting outcomes; no verified common cause. https://www.reddit.com/r/linux_gaming/comments/1svkqa4/arc_raiders_freezes_for_45_seconds_and_becomes/
- Hunt on CachyOS: random freezes with RTX 5080; another commenter reports RTX 5090. Original poster has a Realtek RTL8125/r8169 Ethernet adapter, matching the adapter family/driver here, but the report does not establish a network fault. Their need to switch windows differs from our automatic recovery. https://www.reddit.com/r/linux_gaming/comments/1rfle7t/hunt_showdown_hardfreeze_linux_cachyos/
- Battlefield 4 and Rocket League under Proton: firsthand September 2020 report of recurring 3–5-second freezes on Wi-Fi but not Ethernet. Relevant network-sensitive precedent, but old, different hardware and different connection type; not evidence for our NIC sleeping. https://forum.manjaro.org/t/proton-games-freeze-system-when-ping-spikes/26934
- Hunt: audio and Discord continue during display freezes, but report includes NVIDIA Xid 32 and forced termination. Our capture had no NVIDIA Xid/reset and recovered automatically, so this is a weaker match. https://www.reddit.com/r/linux_gaming/comments/1rzzqbp/hunt_showdown_freezes_entire_display_audio/

Interpretation: comparable reports exist for multiple multiplayer games, but no verified multiplayer-wide defect or confirmed matching fix was found in the reviewed sources. Keep networking and shared graphics/Proton components as competing hypotheses. Next session should capture ARC Raiders using the same methodology to establish whether its freeze signature actually matches Hunt. Add a similarly demanding single-player comparison if practical, without assuming multiplayer alone is causal. Do not copy speculative launch-option bundles from forum comments.

## Deeper capture prepared — 3 October 2026

Clarification: the Bazzite 43 test was abandoned because of other problems BEFORE freeze testing. Therefore the 43/44 comparison has not answered whether the freezes are a system regression. The machine is back on pinned 44.20260929.

See NEXT-TEST.md for prepared normal and privileged collectors. collect-next.py and kernel-capture.py pass Python syntax checks; the privileged trace has not yet been run because passwordless sudo is unavailable. No debugger attached, anti-cheat changed, or global trace/performance settings altered. A new collector was started waiting up to 30 minutes for Hunt or ARC Raiders; it is only capturing after game detection, for at most two hours. Do not assume it remains active in a later session without checking.

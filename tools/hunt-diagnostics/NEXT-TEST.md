# Next test: deeper freeze capture

3 October clarification: Bazzite 43 had unrelated problems. The user did NOT test whether the original freezes occur on 43. It is not a negative result for the OS-regression hypothesis. Current deployment is pinned Bazzite 44.20260929, NVIDIA-open, with 43.20260420 retained.

1. Preserve existing game launch options. Add these environment assignments before the existing command/wrappers; retain exactly one %command%:

   PROTON_LOG=1 PROTON_LOG_DIR=/var/home/lee/bazzite-setup/tools/hunt-diagnostics/proton-logs VKD3D_DEBUG=info

2. Start `python3 /var/home/lee/bazzite-setup/tools/hunt-diagnostics/collect-next.py` before launching Hunt or ARC Raiders. It waits up to 30 minutes, then records for up to 4 hours or game exit. It auto-detects the game PID. Do not run duplicate collectors.
3. Once the collector prints CAPTURING, use your own terminal for the privileged trace:

   sudo python3 /var/home/lee/bazzite-setup/tools/hunt-diagnostics/kernel-capture.py

   This records up to 4 hours or 100 GiB, whichever comes first. Run it during gameplay where freezes recur. It uses a separate kernel trace instance, captures scheduling/syscall events for selected game threads, and attempts kernel stacks on blocking main/render-thread switches. It also records interface-wide TCP/UDP packet summaries (addresses, ports, lengths and timing; no packet payload file). Other applications' connections may appear. Ctrl+C cleans up. Elevated trace has been run successfully; sudo requires the user's password. It does not attach a debugger or disable anti-cheat. No userspace call stacks or lock-owner attribution are provided by this capture.
4. Report freeze times promptly. Keep audio observation and any network indicators. The normal collector records gateway/external ping, NIC power/link state, sockets, game-thread states at 2 Hz, wineserver state, GPU data, and system pressure.
5. Compare earliest change across packet timing, RTT, game waits and kernel syscall durations. Check trace-buffer loss and whether instrumented gameplay differs from baseline. ICMP filtering is not proof of network failure; socket snapshots may miss short-lived connections; kernel stacks may be unavailable.
6. After capture, preserve Proton logs before the next launch (same AppID can overwrite its log). Remove diagnostic launch assignments after testing. Keep original graphics/sync settings until a baseline freeze is recorded.

Further escalation if needed: install/use supported perf or eBPF tooling for userspace/off-CPU stack attribution, subject to game/anti-cheat compatibility, and run one-variable synchronization/rendering comparisons. Neither perf, bpftrace nor strace is currently installed. No global security/performance settings have been changed.

Updated at user request: kernel trace limit is 100 GiB and duration 4 hours. Each run uses a separate timestamped kernel subdirectory, preserving previous captures. Ctrl+C stops early.

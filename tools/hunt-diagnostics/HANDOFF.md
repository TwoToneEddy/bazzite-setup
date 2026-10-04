# Resume here: multiplayer freezes

Last update: 3 October 2026. User wants to resume simply by asking about the freeze investigation; read this and REPORT.md before work.

## Latest outcome
User played with the deep capture and experienced NO freezes. This is an inconclusive negative session, not proof of a fix. Tracing can alter timing and may mask a timing-sensitive issue. The first privileged capture reached 256 MiB in approximately 10 seconds, dominated by vkd3d_fence poll activity. A subsequent version used 50 GiB / 30 minutes. Preserve those results as a normal-play baseline.

No collector processes were found running at handoff. Current latest data pointer is latest.txt (do not assume it identifies the next session).

## User preference and next session
User authorizes intensive logging and up to 100 GB if needed for a longer real gameplay session. Scripts now default to 4 hours; kernel-capture.py permits up to 100 GiB of trace plus packet metadata (100 GiB is approximately 107 GB decimal), stops at game exit or Ctrl+C, and uses unique subfolders. collect-next.py also records up to 4 hours. Nothing has been started for the next session.

Before playing:
1. Check available disk space, active OS/driver/Proton and existing collectors. Read NEXT-TEST.md. Preserve any existing Proton log before another launch overwrites it.
2. Verify diagnostic launch options are actually active; do not assume the earlier pasted EBUG=info text means they were set successfully. Keep the user's normal rendering and synchronization configuration.
3. Start collect-next.py before Hunt or ARC Raiders; it waits up to 30 minutes for the game. Confirm correct PID, growing files and gateway/external probe behaviour.
4. User runs sudo python3 /var/home/lee/bazzite-setup/tools/hunt-diagnostics/kernel-capture.py once in gameplay. Assistant has no passwordless sudo. Confirm trace coverage and monitor growth/free space. The cap is a ceiling, not preallocated disk space.
5. Mark user-reported freezes with local timestamps. After one or several freezes, stop and analyse correlated GPU, thread, scheduler/syscall, network timing and Proton logs.

## Confidence and gaps
The capture is substantially deeper but cannot guarantee root cause. Kernel stacks do not identify userspace lock owners/call chains. Selected TIDs are fixed at trace start and can miss later threads. Poll-heavy trace creates material overhead. Record trace-buffer loss statistics and review event volume before relying on absence of an event. Packet summaries are system-wide; correlate Hunt/ARC sockets to actual server flows. ICMP results alone cannot clear or implicate a server path. Do not infer shader compilation from GPU inactivity or an NTSYNC bug from a wait function.

If repeated heavily traced sessions are clean, compare with a lighter capture to check whether logging masks the problem. If a freeze occurs but kernel waits remain ambiguous, consider supported perf/eBPF off-CPU/userspace stack tools, checking compatibility with the game's anti-cheat before use. Avoid unplanned debugger attachment. Perf/bpftrace/strace were not installed at the last inspection.

## Prior evidence
Original Hunt freezes self-recover after roughly five seconds, audio continues, main/render processing and GPU activity collapse. Ethernet keeps exchanging packets; runtime suspend disabled and suspended time zero. No GPU reset, substantial memory pressure or disk bottleneck. Named shader compiler thread was idle in checked windows. User sees similar behaviour in ARC Raiders, not yet in single-player games.

Bazzite 43 had OTHER problems and was abandoned BEFORE freeze testing. Never characterize the downgrade as reproducing the freezes or ruling out a Bazzite regression. User is back on pinned Bazzite 44.20260929. Original diagnosis and sources are in REPORT.md.

## New result supersedes the earlier no-freeze session
At 20:53 on 3 October, user reported a captured big freeze. A full five-second stall at 20:52:34–39 is covered by kernel/network data in `20261003-204501-deep`. Read that directory's FINDINGS.md first. Both collectors are stopped. Gateway/external RTT remained normal; actual game-server packets continued, with outgoing cadence dropping before incoming cadence collapsed. Main/render threads repeatedly time out in synchronization waits; Streaming File thread has a 5.151454-second futex wait. Initiating cause still unknown. Raw kernel trace ~14.5GB is preserved. Later 20:52:58 GPU dip is outside kernel trace coverage; do not conflate events.

## Next concrete experiment: NTSYNC A/B
Verified installed GE-Proton11-7-x86_64/proton supports PROTON_NO_NTSYNC=1: it removes WINENTSYNC from the game environment. Next test is to prepend PROTON_NO_NTSYNC=1 to existing Hunt launch options, keeping the same Proton, graphics, HDR/Wayland and other settings. Restart the game fully. Verify actual synchronization backend from the new Proton log/environment, rather than assuming fsync fallback solely from env vars. Use the normal collector for event confirmation; do not routinely repeat the 14GB poll-heavy trace. A single clean session is not proof. If repeated comparable play is clean, restore NTSYNC and attempt to reproduce; if freezes persist with NTSYNC confirmed off, remove the test flag and investigate another layer. No Steam launch settings have been changed by the assistant.

## NTSYNC-disabled test result — 3 October, 21:06
Freeze reproduced with PROTON_NO_NTSYNC=1 and Proton confirming `fsync: up and running.` Session: 20261003-210000-deep; preserved log: proton-captured-fsync.log. Particularly clear GPU idle interval 21:06:24.847–21:06:29.869; main thread in futex_do_wait and render thread in futex_wait_multiple across the interval. Gateway RTT 0.392–0.426ms and external RTT 8.38–9.40ms, no missed-reply messages in 21:06:24–30. User reported just froze at approximately 21:06:54; additional GPU idle periods exist later, but may include menu/alt-tab activity. Do not label every idle interval a gameplay freeze without confirmation. NTSYNC is not required to trigger the stall; disabling it is not a fix. Do not repeat this test as the next suggestion. Restore the baseline flag on next restart; then investigate the shared game/Proton/rendering path with one controlled change (native Wine Wayland versus XWayland is an available candidate), or targeted userspace stack attribution. Collector may still be active; check before restarting it.

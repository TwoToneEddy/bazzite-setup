# Hunt Showdown freeze investigation

Start with [REPORT.md](REPORT.md) for findings, evidence limitations and the next-session checklist.

Session: 2 October 2026, Europe/London local time.
Status: recordings stopped; cause unconfirmed; no settings changed.

The data argues against Ethernet runtime sleep. The next session should correlate game-flow packet timing and gateway/external latency with game-thread and GPU stalls.

For the latest session outcome and instructions to resume, read [HANDOFF.md](HANDOFF.md) first. The latest intensive logging session had no freezes; this did not establish a fix. Prepared next-session limits are 4 hours / 100 GiB.

## Location and stored captures

This investigation lives in `tools/hunt-diagnostics` within `bazzite-setup`.
The old `~/hunt-diagnostics` path is a compatibility symlink on this machine,
so existing Steam `PROTON_LOG_DIR` settings and saved commands still work.
Timestamped capture directories, Proton logs and generated output are local
artifacts excluded from Git; the scripts and top-level notes can be versioned.
The collectors resolve their data directory relative to the script.

---
description: Show which bazzite-setup components are installed and running on this machine.
---

Run `./status.sh` and `./preflight.sh --brief` from the repository root and present
the result to the user as a short report:

- which components are `ok`, and which need a step (say which step)
- whether the hardware matches `machine-profile.conf`, and if not, which file each
  difference lives in
- what to run next

Do not install or change anything. If they want to act on it, `/setup` is the
wizard. Note that `status.sh` cannot see the in-game side — the overlay, the
hotkeys and the tray icon need a human to confirm.

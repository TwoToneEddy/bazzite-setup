#!/usr/bin/env bash
# stage1.sh - the basics on a fresh install, with nothing layered and no reboot.
#
#   HDR               03 (PROTON_ENABLE_WAYLAND/HDR) + 05 (KWin's per-output HDR)
#   display switching 05
#   MangoHud + FPS    02 with STAGE1=1: no 12V-2x6 rows, no VOLTAGE row (needs lact)
#   limiter           and 03 (MANGOHUD=1)
#   DLSS indicator    03 (the dlss command) + 04 (the tray toggle)
#
#   ./stage1.sh              install it
#   DRY_RUN=1 ./stage1.sh    print what would happen, change nothing
#
# Everything else is stage 2: ./install-all.sh as usual. Running 02 again without
# STAGE1 there puts the full overlay back.
set -euo pipefail
cd "$(dirname "$0")"

STAGE1=1 ./install-all.sh 02 03 04 05

printf '\n\033[1m=== stage 1 status ===\033[0m\n'
./status.sh --porcelain | grep -E '^0[2-5]-' || true

cat <<'EOF'

  Still needs you:
    - log out and back in: 95-gaming.conf and the KWin output config load at login
    - per game, Steam -> Properties -> Compatibility -> GE-Proton, or HDR is ignored
    - in a game: '/' shows the overlay, Shift_L+F1 cycles the FPS limit,
      left-click the DLSS tray icon to toggle the indicator
EOF

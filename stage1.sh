#!/usr/bin/env bash
# stage1.sh - the basics on a fresh install, with nothing layered and no reboot.
#
# Components 00-03 are stage 1, by construction: they depend on nothing numbered
# higher, and nothing in them needs a layered package.
#
#   00-gaming-env        the Proton HDR switches, MANGOHUD=1, the dlss command
#   01-displays          display-profile, and HDR per screen in KWin
#   02-mangohud-overlay  the overlay and its FPS limiter
#   03-dlss-debug-overlay  the tray toggle for the DLSS indicator
#
#   ./stage1.sh              install them
#   DRY_RUN=1 ./stage1.sh    print what would happen, change nothing
#
# Stage 2 is ./install-all.sh 04 onwards. 05 and 08 add their rows to the overlay.
set -euo pipefail
cd "$(dirname "$0")"

./install-all.sh 00 01 02 03

printf '\n\033[1m=== stage 1 status ===\033[0m\n'
./status.sh --porcelain | grep -E '^0[0-3]-' || true

cat <<'EOF'

  Still needs you:
    - log out and back in: 95-gaming.conf and the KWin output config load at login
    - per game, Steam -> Properties -> Compatibility -> GE-Proton, or HDR is ignored
    - in a game: '/' shows the overlay, Shift_L+F1 toggles the FPS limit,
      left-click the DLSS tray icon to toggle the indicator
EOF

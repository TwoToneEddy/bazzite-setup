#!/usr/bin/env bash
# Install the Dolphin "Add to Steam" right-click entry, and check the helper it
# calls is present on this image.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

say "Dolphin service menu"
install_tree

# The menu only calls steamos-add-to-steam, which ships in the Bazzite image. On
# anything else the entry appears and then does nothing, so say so now.
say "helper"
if have steamos-add-to-steam; then
    ok "present       $(command -v steamos-add-to-steam)"
else
    warn "steamos-add-to-steam is NOT on this machine - the menu entry will fail."
    warn "It ships with Bazzite and SteamOS; see README.md for what it does."
fi

echo
echo "  Close every Dolphin window and reopen it. Right-click an .exe -> Add to Steam."

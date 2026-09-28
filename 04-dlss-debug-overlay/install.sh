#!/usr/bin/env bash
# Install the DLSS overlay tray icon, its CLI twin and the Windows icons.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

[ -r "$HOME/.config/environment.d/95-gaming.conf" ] \
    || warn "95-gaming.conf is missing - install ../03-dlss-presets first."

say "tray, toggle, desktop entry and icons"
install_tree
refresh_desktop_caches

if ! python3 -c 'import PySide6' 2>/dev/null; then
    warn "PySide6 is missing, so the tray icon cannot start."
    warn "  sudo rpm-ostree install python3-pyside6   (then reboot)"
fi

say "starting the tray"
if pgrep -f dlss-overlay-tray >/dev/null; then
    ok "already running (pid $(pgrep -f dlss-overlay-tray | head -1))"
    echo "        restart it to pick up a new version:"
    echo "          pkill -f dlss-overlay-tray; setsid ~/.local/bin/dlss-overlay-tray &"
elif [ "${DRY_RUN:-0}" = 1 ]; then
    echo "  would  start ~/.local/bin/dlss-overlay-tray"
else
    setsid "$HOME/.local/bin/dlss-overlay-tray" >/dev/null 2>&1 &
    sleep 2
    pgrep -f dlss-overlay-tray >/dev/null && ok "started" || warn "it did not stay running"
fi

echo
echo "  If you cannot see it, look behind the tray's '^' arrow - the 'off' icon is"
echo "  the dim one. Configure System Tray -> Entries -> Always shown pins it out."

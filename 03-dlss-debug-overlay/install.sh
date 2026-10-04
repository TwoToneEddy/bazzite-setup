#!/usr/bin/env bash
# Install the DLSS overlay tray icon, its CLI twin and the Windows icons.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

[ -r "$HOME/.config/environment.d/95-gaming.conf" ] \
    || warn "95-gaming.conf is missing - install ../00-gaming-env first."

say "tray, toggle, desktop entry and icons"
install_tree
refresh_desktop_caches

# The tray needs PySide6. Bazzite 44 has it; 43 does not. Rather than layer
# python3-pyside6, give the tray a private venv - the tray re-runs itself under it.
say "PySide6 for the tray"
venv="$HOME/.local/share/dlss-overlay-tray/venv"
if python3 -c 'import PySide6' 2>/dev/null; then
    ok "system python has it"
elif "$venv/bin/python" -c 'import PySide6' 2>/dev/null; then
    ok "unchanged     private venv at $venv"
elif [ "${DRY_RUN:-0}" = 1 ]; then
    echo "  would  create $venv and pip install PySide6 (~650 MB)"
else
    python3 -m venv "$venv"
    "$venv/bin/pip" install -q PySide6
    ok "installed     PySide6 into $venv"
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

#!/usr/bin/env bash
# Install display-profile, its launchers and icons, and the login-screen layout.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

have kscreen-doctor || die "kscreen-doctor not found. This needs KDE Plasma."

say "command, launchers, icons and layouts"
back_up "$HOME/.config/kwinoutputconfig.json"
back_up /var/lib/plasmalogin/.config/kwinoutputconfig.json
install_tree
refresh_desktop_caches

say "outputs this machine actually has"
kscreen-doctor -o 2>/dev/null | grep -E 'Output|Modes' | sed 's/^/        /' | head -20 || true

say "outputs display-profile expects"
grep -oE '"?(DP|HDMI|eDP)-[A-Z]?-?[0-9]+"?' "$HOME/.local/bin/display-profile" \
    | tr -d '"' | sort -u | while read -r o; do
    if matches "$o" kscreen-doctor -o; then
        ok "connected     $o"
    else
        warn "not present   $o  - edit the constants at the top of display-profile"
    fi
done

if [ "${DRY_RUN:-0}" != 1 ]; then
    say "current state"
    "$HOME/.local/bin/display-profile" status 2>/dev/null | sed 's/^/        /' || true
fi

echo
echo "  'display-profile tv' has never been verified on the real TV - see the README."

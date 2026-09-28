#!/usr/bin/env bash
# Install the KWin window rules.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

if [ -r "$HOME/.config/kwinrulesrc" ] && ! cmp -s files/home/.config/kwinrulesrc "$HOME/.config/kwinrulesrc"; then
    warn "you have window rules that differ from these. This replaces the whole file;"
    warn "a copy is kept at ~/.config/kwinrulesrc.bak-bazzite-setup"
fi

say "window rules"
back_up "$HOME/.config/kwinrulesrc"
install_tree

say "asking KWin to re-read them"
if [ "${DRY_RUN:-0}" != 1 ]; then
    if q=$(qdbus_cmd); then
        "$q" org.kde.KWin /KWin reconfigure >/dev/null 2>&1 \
            && ok "KWin reconfigured" \
            || warn "could not reach KWin - the rules apply at the next login anyway"
    else
        warn "no qdbus available - the rules apply at the next login"
    fi
fi

echo
echo "  The Hunt rule matches on window class, which a game update can change."
echo "  If the desktop-drop comes back, find the real class with: window-info"

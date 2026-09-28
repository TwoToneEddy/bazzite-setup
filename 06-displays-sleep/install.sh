#!/usr/bin/env bash
# Install displays-sleep and bind it to Pause/Break.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

have kscreen-doctor || die "kscreen-doctor not found. This needs KDE Plasma."

say "script and desktop entry"
install_tree
refresh_desktop_caches

say "the Pause/Break binding"
rc="$HOME/.config/kglobalshortcutsrc"
if grep -q '^\[services\]\[displays-sleep.desktop\]' "$rc" 2>/dev/null; then
    ok "already bound  $(grep -A1 '^\[services\]\[displays-sleep.desktop\]' "$rc" | tail -1)"
else
    back_up "$rc"
    if [ "${DRY_RUN:-0}" = 1 ]; then
        echo "  would  add [services][displays-sleep.desktop] _launch=Pause to $rc"
    else
        printf '\n[services][displays-sleep.desktop]\n_launch=Pause\n' >> "$rc"
        ok "bound         Pause -> displays-sleep"
        # kglobalaccel keeps its own copy in memory; ask it to re-read.
        # Careful: a wrong-arity call on org.kde.KGlobalAccel crashes kwin_wayland and
        # takes every XWayland app with it. reloadConfig takes no arguments.
        if q=$(qdbus_cmd); then
            "$q" org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.reloadConfig \
                >/dev/null 2>&1 || warn "kglobalaccel did not reload - log out and back in"
        else
            warn "no qdbus available - log out and back in for the key to take effect"
        fi
    fi
fi

echo
echo "  Test it: press Pause/Break. Any key or mouse move brings the screens back."
echo "  If nothing happens, set it in System Settings -> Shortcuts -> 'displays-sleep'."

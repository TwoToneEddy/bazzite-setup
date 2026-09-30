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
        # There is no live reload: this Plasma's KGlobalAccel has no reloadConfig
        # method (introspected). The binding also ships as
        # ~/.local/share/kglobalaccel/displays-sleep.desktop (X-KDE-Shortcuts),
        # which kglobalacceld reads at login.
        warn "Pause takes effect after logging out and back in, or set it now in"
        warn "System Settings -> Shortcuts -> Add New -> Application -> Sleep Displays."
    fi
fi

echo
echo "  Test it: press Pause/Break. Any key or mouse move brings the screens back."
echo "  If nothing happens, set it in System Settings -> Shortcuts -> 'displays-sleep'."

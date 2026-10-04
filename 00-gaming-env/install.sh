#!/usr/bin/env bash
# Install the dlss command, the gaming environment file and the Steam wrapper.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

say "dlss command, environment and Steam wrapper"
back_up "$HOME/.config/environment.d/95-gaming.conf"
install_tree

# The notes refer to ~/.config/gaming-env.conf; keep that name working.
if [ ! -e "$HOME/.config/gaming-env.conf" ]; then
    run ln -s environment.d/95-gaming.conf "$HOME/.config/gaming-env.conf" \
        && ok "symlink       ~/.config/gaming-env.conf"
else
    skip "exists        ~/.config/gaming-env.conf"
fi

refresh_desktop_caches

# Proton from a system package (Proton-CachyOS) needs the DLSS-indicator hook
# written as root; per-user Proton is hooked by dlss itself on every toggle.
say "DLSS indicator hook for system Proton"
run "$HOME/.local/bin/dlss" hook-system || warn "dlss hook-system failed"

if [ "${DRY_RUN:-0}" != 1 ]; then
    say "current settings"
    "$HOME/.local/bin/dlss" status 2>/dev/null | sed 's/^/        /' || warn "dlss status failed"
fi

echo
echo "  Log out and back in for environment.d to reach the session, and fully quit"
echo "  Steam and start it again for these to reach your games."

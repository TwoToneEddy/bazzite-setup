#!/usr/bin/env bash
# Install the dlss command, the gaming environment file and the Steam wrapper.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

# The environment used to live in ~/.config/environment.d/95-gaming.conf, with
# ~/.config/gaming-env.conf a symlink to it. environment.d exports it into the
# whole desktop session - MangoHud ended up inside kwin_wayland - so it is now a
# plain file that only steam-gaming reads. Undo the old layout first, or
# install_tree would write the new file through the symlink into environment.d.
OLD_ENV="$HOME/.config/environment.d/95-gaming.conf"
say "move the environment out of the desktop session"
if [ -L "$HOME/.config/gaming-env.conf" ]; then
    run rm "$HOME/.config/gaming-env.conf" && ok "removed       symlink ~/.config/gaming-env.conf"
fi
if [ -e "$OLD_ENV" ]; then
    # Kept, renamed: environment.d only reads *.conf, so this no longer exports.
    run mv "$OLD_ENV" "$OLD_ENV.moved-bazzite-setup" \
        && ok "moved aside   $OLD_ENV -> .moved-bazzite-setup (now ~/.config/gaming-env.conf)"
    # The user manager read environment.d when it started. unset-environment
    # does not touch generator-provided values (verified: exits 0, changes
    # nothing); a daemon-reload re-runs the generator without the file. Apps
    # already running keep the variables until you log out.
    run systemctl --user daemon-reload || warn "could not reload the user manager"
else
    skip "already out   nothing in ~/.config/environment.d"
fi

say "dlss command, environment and Steam wrapper"
back_up "$HOME/.config/gaming-env.conf"
install_tree

refresh_desktop_caches

# Proton from a system package (Proton-CachyOS) needs the DLSS-indicator hook
# written as root; per-user Proton is hooked by dlss itself on every toggle.
say "DLSS indicator hook for system Proton"
run "$HOME/.local/bin/dlss" hook-system || warn "dlss hook-system failed"

"$(dirname "$0")/install-ge-proton.sh"

if [ "${DRY_RUN:-0}" != 1 ]; then
    say "current settings"
    "$HOME/.local/bin/dlss" status 2>/dev/null | sed 's/^/        /' || warn "dlss status failed"
fi

echo
echo "  Fully quit Steam and start it again for these to reach your games."

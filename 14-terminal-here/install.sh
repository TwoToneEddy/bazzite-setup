#!/usr/bin/env bash
# Put "Open Terminal Here" on the right-click menus: folders (Dolphin and desktop
# icons) via a KIO service menu, and empty desktop space via Plasma's own
# "Open Terminal" item, which is off by default.
#
# The second one is a key in the Plasma desktop config, which plasmashell holds in
# memory and writes back over any edit made while it runs. So it is set with the
# shell stopped, and only when it is not already set.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

say "folder right-click: service menu"
install_tree
have konsole || warn "konsole is not installed - the service menu runs 'konsole --workdir'; edit its Exec= line"

say "empty-desktop right-click: Plasma's Open Terminal item"
rc="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
group=(--file "$rc" --group ActionPlugins --group 0 --group "RightButton;NoModifier")
if [ ! -r "$rc" ]; then
    warn "no Plasma desktop config at $rc - log in to Plasma once, then re-run"
elif [ "$(kreadconfig6 "${group[@]}" --key _open_terminal 2>/dev/null)" = true ]; then
    skip "unchanged     _open_terminal=true"
else
    back_up "$rc"
    # Stop, edit, start: see the plasmashell rule in AGENTS.md. Bazzite runs the
    # shell as a systemd user unit; CachyOS (and a shell started by kstart) does not.
    if systemctl --user is-active --quiet plasma-plasmashell.service; then
        run systemctl --user stop plasma-plasmashell.service
        run kwriteconfig6 "${group[@]}" --key _open_terminal true
        run systemctl --user start plasma-plasmashell.service
    else
        run kquitapp6 plasmashell || true
        run kwriteconfig6 "${group[@]}" --key _open_terminal true
        if [ "${DRY_RUN:-0}" != 1 ]; then kstart plasmashell >/dev/null 2>&1; else echo "  would  kstart plasmashell"; fi
    fi
    ok "set           _open_terminal=true (plasmashell restarted)"
fi

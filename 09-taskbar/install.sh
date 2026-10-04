#!/usr/bin/env bash
# Compare the recorded launcher row against the live one, and record or apply.
#
# This installer does NOT edit the panel config behind your back: doing that while
# plasmashell is running loses the edit later, silently, and plasmashell is always
# running when you would be doing this. It tells you what differs and gives you the
# three commands.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

rc="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
[ -r "$rc" ] || die "no Plasma panel config at $rc"

live=$(grep -m1 '^launchers=' "$rc" || true)
mine=$(cat "$COMPONENT_DIR/panel-launchers.txt")

if [ "$live" = "$mine" ]; then
    ok "the panel row already matches panel-launchers.txt"
else
    say "the live row and the recorded row differ"
    echo "  recorded:"; echo "    ${mine#launchers=}" | tr ',' '\n' | sed 's/^/      /'
    echo "  live:"; echo "    ${live#launchers=}" | tr ',' '\n' | sed 's/^/      /'
fi

say "do the recorded launchers exist on this machine?"
echo "${mine#launchers=}" | tr ',' '\n' | while read -r l; do
    case "$l" in
        applications:*) f="${l#applications:}"
            if [ -e "$HOME/.local/share/applications/$f" ] \
            || [ -e "/usr/share/applications/$f" ] \
            || [ -e "/var/lib/flatpak/exports/share/applications/$f" ]; then
                ok "found         $f"
            else
                warn "missing       $f  - its component may not be installed yet"
            fi ;;
        file://*) [ -e "${l#file://}" ] && ok "found         $l" || warn "missing       $l" ;;
        preferred://*) ok "found         $l" ;;
    esac
done

# The paths are absolute: these get pasted from wherever the shell happens to be,
# and a relative panel-launchers.txt that cat cannot find made sed replace the
# row with nothing - the whole taskbar launcher list gone, with no error.
cat <<END

  To make the live panel match the recorded row - note the STOP first, it matters:

    systemctl --user stop plasma-plasmashell.service
    row=\$(cat $COMPONENT_DIR/panel-launchers.txt) && [ -n "\$row" ] && \\
        sed -i "s|^launchers=.*|\$row|" ~/.config/plasma-org.kde.plasma.desktop-appletsrc
    systemctl --user start plasma-plasmashell.service

  Or, going the other way - you have arranged the panel by dragging icons and want
  to record that here:

    grep -m1 '^launchers=' ~/.config/plasma-org.kde.plasma.desktop-appletsrc \\
        > $COMPONENT_DIR/panel-launchers.txt
END

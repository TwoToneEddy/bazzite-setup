# lib.sh - shared helpers for the bazzite-setup component installers.
#
# Every component is a directory with a files/ tree and an install.sh. The
# files/ tree mirrors the real filesystem in two halves:
#
#   files/home/...    installed under $HOME
#   files/system/...  installed under /      (needs sudo)
#
# install_tree copies both, creating parent directories and preserving the
# executable bit. It is idempotent: running it twice changes nothing.
#
# Nothing here removes or moves a file it did not put there. Where a component
# needs to replace something that already exists and matters - a LACT profile,
# a CoolerControl database, the Plasma panel config - it takes a .bak-bazzite-setup
# copy first, and says so.
set -u

COMPONENT_DIR=$(cd "$(dirname "${BASH_SOURCE[1]:-$0}")" && pwd)
COMPONENT=$(basename "$COMPONENT_DIR")

_c_blue=$'\033[34m'; _c_green=$'\033[32m'; _c_yellow=$'\033[33m'
_c_red=$'\033[31m'; _c_off=$'\033[0m'

say()  { printf '%s==>%s %s\n' "$_c_blue"  "$_c_off" "$*"; }
ok()   { printf '  %sok%s      %s\n'   "$_c_green"  "$_c_off" "$*"; }
skip() { printf '  %sskip%s    %s\n'   "$_c_yellow" "$_c_off" "$*"; }
warn() { printf '  %swarn%s    %s\n'   "$_c_yellow" "$_c_off" "$*" >&2; }
die()  { printf '  %serror%s   %s\n'   "$_c_red"    "$_c_off" "$*" >&2; exit 1; }

# DRY_RUN=1 ./install.sh  - print what would happen, touch nothing.
run() {
    if [ "${DRY_RUN:-0}" = 1 ]; then printf '  would  %s\n' "$*"; return 0; fi
    "$@"
}

have() { command -v "$1" >/dev/null 2>&1; }

# back_up <path> - keep one .bak-bazzite-setup copy of a file before replacing it.
# Only the first run makes a backup; later runs leave the original backup alone,
# so re-running an installer can never overwrite the copy of the pristine file.
back_up() {
    local f="$1" sudo_=""
    [ -e "$f" ] || return 0
    [ -w "$(dirname "$f")" ] || sudo_="sudo"
    if $sudo_ test -e "$f.bak-bazzite-setup" 2>/dev/null; then
        skip "backup exists  $f.bak-bazzite-setup"
        return 0
    fi
    run $sudo_ cp -a "$f" "$f.bak-bazzite-setup" || return 1
    [ "${DRY_RUN:-0}" = 1 ] || ok "backed up      $f"
}

_install_one() {
    local src="$1" dst="$2" sudo_="$3" mode
    mode=644
    [ -x "$src" ] && mode=755
    if [ -e "$dst" ] && cmp -s "$src" "$dst"; then
        skip "unchanged     $dst"
        return 0
    fi
    run $sudo_ install -D -m "$mode" "$src" "$dst" || die "could not install $dst"
    ok "installed     $dst"
}

# install_tree - copy files/home -> $HOME and files/system -> /
install_tree() {
    local base="$COMPONENT_DIR/files" src rel
    if [ -d "$base/home" ]; then
        while IFS= read -r src; do
            rel=${src#"$base/home/"}
            _install_one "$src" "$HOME/$rel" ""
        done < <(find "$base/home" -type f | sort)
    fi
    if [ -d "$base/system" ]; then
        while IFS= read -r src; do
            rel=${src#"$base/system/"}
            _install_one "$src" "/$rel" "sudo"
        done < <(find "$base/system" -type f | sort)
    fi
}

# refresh_desktop_caches - make Plasma notice new .desktop files and icons.
#
# kbuildsycoca6 --noincremental takes several seconds, and five components call
# this, so install-all.sh sets BAZZITE_SETUP_DEFER_CACHES=1 and runs it once at the
# end instead. On its own, a single component still refreshes immediately.
refresh_desktop_caches() {
    if [ "${BAZZITE_SETUP_DEFER_CACHES:-0}" = 1 ]; then
        skip "cache refresh deferred to the end of install-all.sh"
        return 0
    fi
    have gtk-update-icon-cache && \
        run gtk-update-icon-cache -q -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null
    have update-desktop-database && \
        run update-desktop-database "$HOME/.local/share/applications" 2>/dev/null
    have kbuildsycoca6 && run kbuildsycoca6 --noincremental >/dev/null 2>&1
    ok "desktop and icon caches refreshed"
}

# assemble_mangohud - join the overlay pieces into MangoHud.conf.
#
# MangoHud reads one file, but its rows belong to different components: 02 owns
# the base overlay, 05 the 12V-2x6 rows, 08 the VOLTAGE row. Each installs its
# piece into bazzite-setup.d/ and calls this, so a row exists only when the
# component that feeds it does. Pieces join in name order, which is on-screen
# order. Does nothing until 02 has put the base piece in place.
MANGOHUD_PARTS="$HOME/.config/MangoHud/bazzite-setup.d"
assemble_mangohud() {
    local conf="$HOME/.config/MangoHud/MangoHud.conf" tmp f first=1
    if [ "${DRY_RUN:-0}" = 1 ]; then
        printf '  would  assemble %s from %s/*.conf\n' "$conf" "$MANGOHUD_PARTS"
        return 0
    fi
    if [ ! -e "$MANGOHUD_PARTS/10-overlay.conf" ]; then
        skip "no base overlay yet - these rows appear once 02-mangohud-overlay is installed"
        return 0
    fi
    tmp=$(mktemp)
    {
        echo "# Assembled by bazzite-setup from $MANGOHUD_PARTS/*.conf."
        echo "# Edit those pieces, not this file: any installer that reassembles it"
        echo "# overwrites a change made here. display-profile rewrites fps_limit=."
        echo
        for f in "$MANGOHUD_PARTS"/*.conf; do
            [ "$first" = 1 ] || echo
            first=0
            cat "$f"
        done
    } >"$tmp"
    back_up "$conf"
    _install_one "$tmp" "$conf" ""
    rm -f "$tmp"
    ok "overlay rows from: $(cd "$MANGOHUD_PARTS" && echo *.conf)"
}

# enable_user_units <unit>... - reload, enable and start user services.
enable_user_units() {
    run systemctl --user daemon-reload
    for u in "$@"; do
        run systemctl --user enable --now "$u" && ok "user unit      $u"
    done
}

# matches <pattern> <command...> - true if the command's output matches.
#
# Use this rather than `command | grep -q pattern`, which is a coin flip under
# `set -o pipefail`: grep -q exits on the first match, the writer gets SIGPIPE,
# and pipefail then reports the whole pipeline as failed even though the match
# was found. That bug made this very library report a correctly configured GPU
# as absent, so it is worth the helper.
matches() {
    local pat="$1" out
    shift
    out=$("$@" 2>/dev/null) || true
    grep -q -- "$pat" <<<"$out"
}

# qdbus_cmd - print the Qt D-Bus CLI's name, or nothing if there is none.
#
# It is qdbus6 on some distributions, qdbus-qt6 on others, and plain qdbus where
# that is the Qt6 build. Bazzite 44 has qdbus and qdbus-qt6 but no qdbus6, so
# hardcoding qdbus6 silently skips whatever you were asking KDE to do.
qdbus_cmd() {
    local c
    for c in qdbus6 qdbus-qt6 qdbus; do
        if have "$c"; then printf '%s' "$c"; return 0; fi
    done
    return 1
}

# pin_launchers <file.desktop>... - add launchers to the taskbar, if missing.
#
# Appends any of the named launchers that are not already on the first Icons-Only
# Task Manager's launchers= line (the one 09-taskbar records). plasmashell keeps
# its own copy of that file and writes it back over an edit made while it runs,
# so it is stopped first and started after - never edited live. Does nothing, and
# does not touch plasmashell, when every launcher is already pinned.
pin_launchers() {
    local rc="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    local live new l missing=() was_running=0
    if [ ! -w "$rc" ] || ! live=$(grep -m1 '^launchers=' "$rc"); then
        warn "no taskbar launcher row found in $rc - pin from the app menu instead"
        return 0
    fi
    for l in "$@"; do
        case ",${live#launchers=}," in
            *",applications:$l,"*) skip "pinned        $l" ;;
            *) missing+=("applications:$l") ;;
        esac
    done
    [ "${#missing[@]}" -gt 0 ] || return 0

    new="$live"
    for l in "${missing[@]}"; do
        if [ "$new" = "launchers=" ]; then new="launchers=$l"; else new="$new,$l"; fi
    done
    if [ "${DRY_RUN:-0}" = 1 ]; then
        printf '  would  stop plasmashell, pin %s, start plasmashell\n' "${missing[*]}"
        return 0
    fi

    if systemctl --user is-active -q plasma-plasmashell.service; then
        was_running=1
    elif pgrep -x plasmashell >/dev/null; then
        warn "plasmashell is running outside systemd, so it cannot be stopped safely"
        warn "pin these from the app menu instead: ${missing[*]}"
        return 0
    fi

    back_up "$rc"
    [ "$was_running" = 0 ] || systemctl --user stop plasma-plasmashell.service
    awk -v new="$new" '!done && /^launchers=/ { print new; done=1; next } { print }' \
        "$rc" >"$rc.tmp.$$" && cat "$rc.tmp.$$" >"$rc"
    rm -f "$rc.tmp.$$"
    [ "$was_running" = 0 ] || systemctl --user start plasma-plasmashell.service
    for l in "${missing[@]}"; do ok "pinned        ${l#applications:}"; done
}

# add_to_desktop <file.desktop>... - copy launchers from ~/.local/share/applications
# onto the desktop. Executable, because Plasma refuses to run an untrusted one.
add_to_desktop() {
    local dir l src
    dir=$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")
    for l in "$@"; do
        src="$HOME/.local/share/applications/$l"
        [ "${DRY_RUN:-0}" = 1 ] || [ -e "$src" ] || { warn "no launcher $src"; continue; }
        if [ -x "$dir/$l" ] && cmp -s "$src" "$dir/$l"; then
            skip "unchanged     $dir/$l"
            continue
        fi
        run install -D -m 755 "$src" "$dir/$l" && ok "installed     $dir/$l"
    done
}

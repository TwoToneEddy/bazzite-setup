# lib.sh - shared helpers for the gamingConfig component installers.
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
# a CoolerControl database, the Plasma panel config - it takes a .bak-gamingConfig
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

# back_up <path> - keep one .bak-gamingConfig copy of a file before replacing it.
# Only the first run makes a backup; later runs leave the original backup alone,
# so re-running an installer can never overwrite the copy of the pristine file.
back_up() {
    local f="$1" sudo_=""
    [ -e "$f" ] || return 0
    [ -w "$(dirname "$f")" ] || sudo_="sudo"
    if $sudo_ test -e "$f.bak-gamingConfig" 2>/dev/null; then
        skip "backup exists  $f.bak-gamingConfig"
        return 0
    fi
    run $sudo_ cp -a "$f" "$f.bak-gamingConfig" || return 1
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
refresh_desktop_caches() {
    have gtk-update-icon-cache && \
        run gtk-update-icon-cache -q -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null
    have update-desktop-database && \
        run update-desktop-database "$HOME/.local/share/applications" 2>/dev/null
    have kbuildsycoca6 && run kbuildsycoca6 --noincremental >/dev/null 2>&1
    ok "desktop and icon caches refreshed"
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

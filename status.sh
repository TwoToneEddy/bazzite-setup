#!/usr/bin/env bash
# status.sh - per-component state: is it installed, and is it actually running?
#
# The health check in reference/ is organised by component but reports on the
# machine as a whole. This answers the other question - "where am I up to?" -
# which is what you want when working through a fresh install one piece at a time.
#
#   ./status.sh              a table
#   ./status.sh --porcelain  one line per component: <dir> <state> <detail>
#   ./status.sh 02           just that component
#
# Read-only. Three states:
#
#   ok       installed, and the parts that should be running are running
#   partial  installed, but something that should be running is not
#   absent   not installed on this machine
#
# "absent" for a component you chose to skip is a correct answer, not a failure.
set -u
cd "$(dirname "$0")"

PORCELAIN=0
WANT=""
for a in "$@"; do
    case "$a" in
        --porcelain) PORCELAIN=1 ;;
        *) WANT="$a" ;;
    esac
done

g=$'\033[32m'; y=$'\033[33m'; d=$'\033[90m'; b=$'\033[1m'; o=$'\033[0m'

# report <dir> <state> <detail>
report() {
    if [ "$PORCELAIN" = 1 ]; then
        printf '%s %s %s\n' "$1" "$2" "$3"
        return
    fi
    local colour
    case "$2" in
        ok) colour=$g ;;
        partial) colour=$y ;;
        *) colour=$d ;;
    esac
    printf '  %-22s %s%-8s%s %s\n' "$1" "$colour" "$2" "$o" "$3"
}

# every_file_installed <dir> - true when each file in its files/ tree is in place
every_file_installed() {
    local base="$1/files" src rel target missing=0 total=0 unknown=0
    [ -d "$base" ] || return 0
    if [ -d "$base/home" ]; then
        while IFS= read -r src; do
            rel=${src#"$base/home/"}; target="$HOME/$rel"
            total=$((total+1)); [ -e "$target" ] || missing=$((missing+1))
        done < <(find "$base/home" -type f)
    fi
    if [ -d "$base/system" ]; then
        while IFS= read -r src; do
            rel=${src#"$base/system/"}; target="/$rel"
            total=$((total+1))
            if [ -e "$target" ] || sudo -n test -e "$target" 2>/dev/null; then :
            # A parent directory we cannot enter (e.g. /var/lib/plasmalogin, 0750)
            # makes the file unknowable without root, which is not the same as absent.
            elif [ ! -x "$(dirname "$target")" ] && ! sudo -n true 2>/dev/null; then unknown=$((unknown+1))
            else missing=$((missing+1)); fi
        done < <(find "$base/system" -type f)
    fi
    FILES_TOTAL=$total; FILES_MISSING=$missing; FILES_UNKNOWN=$unknown
    [ "$missing" = 0 ]
}

active()      { systemctl is-active --quiet "$1"; }

# root_grep <grep args...> <file> - grep a root-owned file. Read it directly when it
# is world-readable (/etc/coolercontrol and /etc/lact are), and only fall back to
# sudo -n otherwise. Relying on sudo -n alone reported "missing" whenever no sudo
# credential happened to be cached.
root_grep() {
    local f="${!#}"
    if [ -r "$f" ]; then grep "$@"; else sudo -n grep "$@"; fi
}
user_active() { systemctl --user is-active --quiet "$1"; }

MANGO_CONF="$HOME/.config/MangoHud/MangoHud.conf"
MANGO_PARTS="$HOME/.config/MangoHud/bazzite-setup.d"

check() {
    local dir="$1" state detail
    FILES_TOTAL=0; FILES_MISSING=0; FILES_UNKNOWN=0
    every_file_installed "$dir"
    if [ "$FILES_TOTAL" -gt 0 ] && [ "$FILES_MISSING" = "$FILES_TOTAL" ]; then
        report "$dir" absent "none of its $FILES_TOTAL files are installed"
        return
    fi
    if [ "$FILES_MISSING" -gt 0 ]; then
        report "$dir" partial "$FILES_MISSING of $FILES_TOTAL files missing - run its install.sh"
        return
    fi

    # Files are in place. Now the part a file check cannot tell you.
    state=ok; detail="installed"
    local unverified=""
    [ "$FILES_UNKNOWN" -gt 0 ] && unverified=" ($FILES_UNKNOWN root-only file(s) unverified - sudo -v first)"
    case "$dir" in
        00-gaming-env)
            if grep -q '^MANGOHUD=1' "$HOME/.config/environment.d/95-gaming.conf" 2>/dev/null; then
                detail="$(command -v dlss >/dev/null && dlss overlay status 2>/dev/null | tr -s ' ' || echo configured)"
            else state=partial; detail="95-gaming.conf has no MANGOHUD=1"; fi ;;
        00-rhi)
            if [ ! -d "$HOME/RHI/.git" ]; then state=absent; detail="repo not cloned"
            elif [ ! -x "$HOME/RHI/artifacts/linux-x64/RHI.Linux" ]; then state=partial; detail="cloned but not built"
            elif [ ! -e "$HOME/.local/share/applications/rhi-linux.desktop" ]; then state=partial; detail="built, no menu entry"
            else detail="built, repo on $(git -C "$HOME/RHI" branch --show-current 2>/dev/null)"; fi ;;
        01-displays)
            if command -v kscreen-doctor >/dev/null; then
                detail="$(display-profile status 2>/dev/null | grep -c ON) output(s) on"
            else state=partial; detail="no kscreen-doctor - KDE only"; fi ;;
        02-mangohud-overlay)
            if [ ! -r "$MANGO_CONF" ]; then state=partial; detail="MangoHud.conf not assembled - run its install.sh"
            elif ! user_active gpu-peaks; then state=partial; detail="user service not active: gpu-peaks"
            else detail="rows from: $(cd "$MANGO_PARTS" 2>/dev/null && echo *.conf), peak $(cat /dev/shm/gpu-peaks.temp 2>/dev/null)"; fi ;;
        03-dlss-debug-overlay)
            if pgrep -f dlss-overlay-tray >/dev/null; then detail="tray running (pid $(pgrep -f dlss-overlay-tray | head -1))"
            else state=partial; detail="tray not running - start dlss-overlay-tray"; fi ;;
        04-prerequisites)
            local miss=""
            for m in nct6775 i2c_dev; do
                grep -q "^$m " <<<"$(lsmod)" || miss="$miss $m"
            done
            for p in coolercontrol lact liquidctl; do
                rpm -q "$p" >/dev/null 2>&1 || miss="$miss $p"
            done
            if [ -n "$miss" ]; then state=partial; detail="not loaded/layered:$miss"
            else detail="modules loaded, 3 packages layered"; fi ;;
        05-per-pin-current)
            if [ ! -x /usr/local/bin/astral-pins ]; then state=partial; detail="binary not built"
            elif ! active astral-pins; then state=partial; detail="astral-pins.service not active"
            elif [ ! -r /dev/shm/astral-pins ]; then state=partial; detail="no reading published"
            elif ! grep -q 'astral-pins\.pin1' "$MANGO_CONF" 2>/dev/null; then state=partial; detail="12V-2x6 rows not in MangoHud.conf - re-run 02-mangohud-overlay/install.sh"
            else detail="$(cat /dev/shm/astral-pins 2>/dev/null)"; fi ;;
        06-displays-sleep)
            if grep -q '^\[services\]\[displays-sleep.desktop\]' "$HOME/.config/kglobalshortcutsrc" 2>/dev/null; then
                detail="bound to Pause"
            # kglobalacceld also reads X-KDE-Shortcuts from here at login; that alone
            # is enough (verified: Pause blanks the screens with no kglobalshortcutsrc entry).
            elif grep -q '^X-KDE-Shortcuts=Pause' "$HOME/.local/share/kglobalaccel/displays-sleep.desktop" 2>/dev/null; then
                detail="bound to Pause (via kglobalaccel desktop file)"
            else state=partial; detail="installed but not bound to a key"; fi ;;
        07-fan-control)
            if ! active coolercontrold; then state=partial; detail="coolercontrold not active"
            elif root_grep -q 'name = "Main Mix"' /etc/coolercontrol/config.toml 2>/dev/null; then
                detail="curves present in CoolerControl"
            else state=partial; detail="curves not in CoolerControl - run its install.sh"; fi ;;
        08-gpu-undervolt)
            if ! active lactd; then state=partial; detail="lactd not active"
            elif ! user_active gpu-voltage; then state=partial; detail="user service not active: gpu-voltage"
            elif ! grep -q 'gpu-voltage\.mv' "$MANGO_CONF" 2>/dev/null; then state=partial; detail="LACT row not in MangoHud.conf - re-run 02-mangohud-overlay/install.sh"
            else
                local cur; cur=$(root_grep -m1 '^current_profile:' /etc/lact/config.yaml 2>/dev/null | awk '{print $2}')
                if [ "${cur:-null}" = null ]; then state=partial; detail="profile defined but NOT active (current_profile: null)"
                else detail="active profile: $cur"; fi
            fi ;;
        09-taskbar)
            local rc="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
            if [ "$(grep -m1 '^launchers=' "$rc" 2>/dev/null)" = "$(cat "$dir/panel-launchers.txt" 2>/dev/null)" ]; then
                detail="panel row matches panel-launchers.txt"
            else state=partial; detail="panel row differs from the recorded one"; fi ;;
        10-nvtruehdr)
            if [ ! -d "$HOME/nvtruehdr/.git" ]; then state=partial; detail="repo not cloned"
            elif [ ! -x "$HOME/.local/bin/nvtruehdr" ]; then state=partial; detail="layer not built"
            else detail="layer built, repo on $(git -C "$HOME/nvtruehdr" branch --show-current 2>/dev/null)"; fi ;;
        12-shell-environment)
            if ! grep -q 'bashrc.d' "$HOME/.bashrc" 2>/dev/null; then
                state=partial; detail="~/.bashrc does not source ~/.bashrc.d/"
            else
                # Which GUI editor `g` resolves to on this machine, if any.
                local editor=""
                for e in kate kwrite gnome-text-editor gedit; do
                    command -v "$e" >/dev/null 2>&1 && { editor="$e"; break; }
                done
                if [ -n "$editor" ]; then
                    detail="aliases and git prompt installed, g -> $editor"
                else
                    state=partial; detail="installed, but g has no GUI editor to open"
                fi
            fi ;;
    esac
    report "$dir" "$state" "$detail$unverified"
}

if [ "$PORCELAIN" != 1 ]; then
    printf '%sComponent status%s  (ok = running · partial = needs a step · absent = not installed)\n\n' "$b" "$o"
fi
for c in $(find . -maxdepth 1 -type d -name '[0-9][0-9]-*' -printf '%f\n' | sort); do
    [ -n "$WANT" ] && case "$c" in "$WANT"*) ;; *) continue ;; esac
    check "$c"
done
if [ "$PORCELAIN" != 1 ]; then
    printf '\n  %sNext:%s ./preflight.sh for hardware differences · ./install-all.sh NN for one component\n' "$b" "$o"
    printf '  Nothing here proves the in-game side. reference/health-check.sh goes deeper.\n'
fi

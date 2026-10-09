#!/usr/bin/env bash
# install-all.sh - run every component installer, in order.
#
#   ./install-all.sh              everything
#   ./install-all.sh 02 05        only the components whose name starts 02 / 05
#   DRY_RUN=1 ./install-all.sh    print what would happen, change nothing
#
# Stops at the first component that fails, rather than carrying on and leaving a
# half-installed system that looks finished. Also stops, cleanly, when a component
# has layered packages (04) and a reboot is needed before the rest can work.
set -euo pipefail
cd "$(dirname "$0")"

mapfile -t all < <(find . -maxdepth 1 -type d -name '[0-9][0-9]-*' -printf '%f\n' | sort)

if [ "$#" -gt 0 ]; then
    want=()
    for arg in "$@"; do
        for c in "${all[@]}"; do
            case "$c" in "$arg"*) want+=("$c") ;; esac
        done
    done
    [ "${#want[@]}" -gt 0 ] || { echo "no component matches: $*" >&2; exit 2; }
else
    want=("${all[@]}")
fi

# Ask for sudo once here rather than having each installer stop and prompt in the
# middle of its own output.
if [ "${DRY_RUN:-0}" != 1 ]; then
    for c in "${want[@]}"; do
        if [ -d "$c/files/system" ]; then sudo -v; break; fi
    done
fi

# Five components would each run kbuildsycoca6 --noincremental, which takes several
# seconds a go. Defer it and do it once at the end.
export BAZZITE_SETUP_DEFER_CACHES=1

for c in "${want[@]}"; do
    [ -x "$c/install.sh" ] || { echo "skipping $c (no installer)"; continue; }
    # A component with a SKIP file is kept in the repo but not installed by a
    # full run. Name it explicitly (./install-all.sh 10) to install it anyway.
    if [ -e "$c/SKIP" ] && [ "$#" -eq 0 ]; then echo "skipping $c (SKIP: $(head -1 "$c/SKIP"))"; continue; fi
    printf '\n\033[1m=== %s ===\033[0m\n' "$c"
    rc=0
    ( cd "$c" && ./install.sh ) || rc=$?
    case $rc in
        0) ;;
        100) printf '\n\033[1mreboot pending\033[0m — stopped after %s. Reboot, then run ./install-all.sh again.\n' "$c"
             exit 0 ;;
        *) exit "$rc" ;;
    esac
done

printf '\n\033[1m=== desktop and icon caches ===\033[0m\n'
if [ "${DRY_RUN:-0}" = 1 ]; then
    echo "  would  refresh the desktop and icon caches once"
else
    BAZZITE_SETUP_DEFER_CACHES=0 bash -c '. common/lib.sh; refresh_desktop_caches'
fi

printf '\n\033[32mdone\033[0m — check it with reference/health-check.sh\n'

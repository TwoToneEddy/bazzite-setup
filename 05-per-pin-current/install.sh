#!/usr/bin/env bash
# Build and install astral-pins, then start it.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

if ! matches "^i2c_dev" lsmod; then
    warn "i2c-dev is not loaded - install 04-prerequisites first, or: sudo modprobe i2c-dev"
fi

say "source, alarm script, unit and overlay rows"
install_tree

say "building astral-pins"
have gcc || die "gcc not found. On Bazzite: use a toolbox, or layer gcc."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
if [ "${DRY_RUN:-0}" = 1 ]; then
    echo "  would  gcc -O2 -o astral-pins /usr/local/src/astral-pins/astral-pins.c"
else
    gcc -O2 -Wall -Wextra -o "$tmp/astral-pins" /usr/local/src/astral-pins/astral-pins.c \
        || die "build failed"
    if cmp -s "$tmp/astral-pins" /usr/local/bin/astral-pins 2>/dev/null; then
        skip "unchanged     /usr/local/bin/astral-pins"
    else
        sudo install -m 0755 "$tmp/astral-pins" /usr/local/bin/astral-pins
        ok "installed     /usr/local/bin/astral-pins"
    fi
fi

say "checking the card answers"
if [ "${DRY_RUN:-0}" != 1 ]; then
    if sudo /usr/local/bin/astral-pins --status >/dev/null 2>&1; then
        ok "sensor found - $(sudo /usr/local/bin/astral-pins --status 2>/dev/null | tail -1)"
    else
        warn "the IT8915FN did not answer. This card may not be a ROG Astral."
        warn "run: sudo astral-pins --probe"
    fi
fi

say "service"
run sudo systemctl daemon-reload
run sudo systemctl enable --now astral-pins.service
if [ "${DRY_RUN:-0}" != 1 ]; then
    sleep 2
    if [ -r /dev/shm/astral-pins ]; then
        ok "publishing    $(cat /dev/shm/astral-pins)"
    else
        warn "/dev/shm/astral-pins not written yet - journalctl -u astral-pins -n 20"
    fi
fi

say "overlay rows"
assemble_mangohud

#!/usr/bin/env bash
# Install the overlay config and the two feed daemons.
#
# STAGE1=1 ./install.sh  - the overlay without the rows that need other components:
# the 12V-2x6 block (01-per-pin-current) and VOLTAGE (lact, from 00). The FPS
# limiter and everything MangoHud reads itself stay. Run it again without STAGE1
# to get the full overlay.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

CONF="$HOME/.config/MangoHud/MangoHud.conf"
STAGE1=${STAGE1:-0}

# stage1_conf - the full config minus the 12V-2x6 block and the VOLTAGE row
stage1_conf() {
    echo "# Installed with STAGE1=1: the 12V-2x6 and VOLTAGE rows are removed."
    echo "# Re-run 02-mangohud-overlay/install.sh without STAGE1 for the full overlay."
    echo
    awk '
        /12V-2x6 CONNECTOR/          { skip = 1 }
        /FPS LIMITER/                { skip = 0 }
        /^# Core voltage\./          { skip = 1 }
        /gpu-voltage\.mv/            { skip = 0; next }
        !skip
    ' "$COMPONENT_DIR/files/home/.config/MangoHud/MangoHud.conf"
}

say "overlay config and feed daemons"
back_up "$CONF"
if [ "$STAGE1" = 1 ]; then
    install_tree 'MangoHud\.conf$'
    tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
    stage1_conf >"$tmp"
    # The awk keys on section headers; if they are renamed it would strip the
    # wrong thing, or nothing, without complaint. Check the result instead.
    if grep -qE 'astral-pins|gpu-voltage\.mv' "$tmp" || ! grep -q '^fps_limit=' "$tmp"; then
        die "stage 1 filter did not produce a sane MangoHud.conf - check the section headers"
    fi
    _install_one "$tmp" "$CONF" ""
else
    install_tree
fi

if ! have mangohud; then
    warn "mangohud not found - it ships with Bazzite; otherwise layer it."
fi
if [ "$STAGE1" != 1 ] && ! have lact; then
    warn "lact not found - the VOLTAGE row will read '--'. See ../00-prerequisites."
fi

say "the GPU this overlay is pinned to"
want=$(grep -m1 '^pci_dev=' "$COMPONENT_DIR/files/home/.config/MangoHud/MangoHud.conf" | cut -d= -f2 || true)
if [ -n "${want:-}" ]; then
    if matches "^$want" lspci -D; then
        ok "pci_dev=$want  $(lspci -D 2>/dev/null | grep "^$want" | cut -d' ' -f2- || true)"
    else
        warn "pci_dev=$want is not on this machine. The GPU and VRAM rows will be"
        warn "missing and nothing will say so. Fix it with: lspci -nn | grep -i vga"
    fi
fi

if [ "$STAGE1" != 1 ]; then
    say "the GPU id gpu-voltage asks LACT for"
    gid=$(grep -m1 '^GPU_ID' "$HOME/.local/bin/gpu-voltage" | cut -d'"' -f2 || true)
    if [ -n "${gid:-}" ] && have lact; then
        if matches "$gid" lact cli list-gpus; then
            ok "GPU_ID=$gid"
        else
            warn "GPU_ID=$gid is not in 'lact cli list-gpus'."
            warn "Set GPU_ID at the top of ~/.local/bin/gpu-voltage to the right one, or the"
            warn "VOLTAGE row will read the iGPU and be plausibly wrong."
        fi
    fi
fi

say "feed services"
if [ "$STAGE1" = 1 ]; then
    units=(gpu-peaks.service)
    feeds=(/dev/shm/gpu-peaks.temp /dev/shm/gpu-peaks.power)
else
    units=(gpu-peaks.service gpu-voltage.service)
    feeds=(/dev/shm/gpu-peaks.temp /dev/shm/gpu-peaks.power /dev/shm/gpu-voltage.mv)
fi
enable_user_units "${units[@]}"
if [ "${DRY_RUN:-0}" != 1 ]; then
    sleep 2
    for f in "${feeds[@]}"; do
        if [ -r "$f" ]; then ok "$(basename "$f") = $(cat "$f")"
        else warn "$f not written - systemctl --user status $(basename "${f%%.*}")"; fi
    done
fi

echo
echo "  In a running game, press Shift_L+F4 to reload the config; '/' toggles the overlay."
echo "  Shift_L+F1 cycles the FPS limit: 276, 59, 115, 280, unlimited, 240, 144, 120, 60."

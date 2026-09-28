#!/usr/bin/env bash
# Install the overlay config and the two feed daemons.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

say "overlay config and feed daemons"
back_up "$HOME/.config/MangoHud/MangoHud.conf"
install_tree

if ! have mangohud; then
    warn "mangohud not found - it ships with Bazzite; otherwise layer it."
fi
if ! have lact; then
    warn "lact not found - the VOLTAGE row will read '--'. See ../00-prerequisites."
fi

say "the GPU this overlay is pinned to"
want=$(grep -m1 '^pci_dev=' "$HOME/.config/MangoHud/MangoHud.conf" | cut -d= -f2 || true)
if [ -n "${want:-}" ]; then
    if matches "^$want" lspci -D; then
        ok "pci_dev=$want  $(lspci -D 2>/dev/null | grep "^$want" | cut -d' ' -f2- || true)"
    else
        warn "pci_dev=$want is not on this machine. The GPU and VRAM rows will be"
        warn "missing and nothing will say so. Fix it with: lspci -nn | grep -i vga"
    fi
fi

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

say "feed services"
enable_user_units gpu-peaks.service gpu-voltage.service
if [ "${DRY_RUN:-0}" != 1 ]; then
    sleep 2
    for f in /dev/shm/gpu-peaks.temp /dev/shm/gpu-peaks.power /dev/shm/gpu-voltage.mv; do
        if [ -r "$f" ]; then ok "$(basename "$f") = $(cat "$f")"
        else warn "$f not written - systemctl --user status $(basename "${f%%.*}")"; fi
    done
fi

echo
echo "  In a running game, press Shift_L+F4 to reload the config; '/' toggles the overlay."

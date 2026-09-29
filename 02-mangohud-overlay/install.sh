#!/usr/bin/env bash
# Install the base overlay and the peaks feed, then assemble MangoHud.conf.
#
# The 12V-2x6 and VOLTAGE rows are not here: 05-per-pin-current and
# 08-gpu-undervolt add them, because they own what feeds them.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

say "overlay pieces and the peaks feed"
install_tree
assemble_mangohud

if ! have mangohud; then
    warn "mangohud not found - it ships with Bazzite; otherwise layer it."
fi

say "the GPU this overlay is pinned to"
want=$(grep -m1 '^pci_dev=' "$COMPONENT_DIR/files/home/.config/MangoHud/bazzite-setup.d/10-overlay.conf" | cut -d= -f2 || true)
if [ -n "${want:-}" ]; then
    if matches "^$want" lspci -D; then
        ok "pci_dev=$want  $(lspci -D 2>/dev/null | grep "^$want" | cut -d' ' -f2- || true)"
    else
        warn "pci_dev=$want is not on this machine. The GPU and VRAM rows will be"
        warn "missing and nothing will say so. Fix it with: lspci -nn | grep -i vga"
    fi
fi

say "feed service"
enable_user_units gpu-peaks.service
if [ "${DRY_RUN:-0}" != 1 ]; then
    sleep 2
    for f in /dev/shm/gpu-peaks.temp /dev/shm/gpu-peaks.power; do
        if [ -r "$f" ]; then ok "$(basename "$f") = $(cat "$f")"
        else warn "$f not written - systemctl --user status gpu-peaks"; fi
    done
fi

echo
echo "  In a running game, press Shift_L+F4 to reload the config; '/' toggles the overlay."
echo "  Shift_L+F1 cycles the FPS limit: 276, 59, 115, 280, unlimited, 240, 144, 120, 60."

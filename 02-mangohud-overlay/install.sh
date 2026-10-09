#!/usr/bin/env bash
# Install the base overlay, then assemble MangoHud.conf.
#
# The 12V-2x6 and VOLTAGE rows are not here: 05-per-pin-current and
# 08-gpu-undervolt add them, because they own what feeds them.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

say "overlay pieces"
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

# gpu-peaks.service fed MAX TEMP / MAX POWER rows that were dropped to match the
# Windows overlay, and was then removed. Retire it where an older install left it.
old_unit="$HOME/.config/systemd/user/gpu-peaks.service"
if [ -e "$old_unit" ] || [ -e "$HOME/.local/bin/gpu-peaks" ]; then
    say "retiring gpu-peaks"
    run systemctl --user disable --now gpu-peaks.service 2>/dev/null || true
    run rm -f "$old_unit" "$HOME/.local/bin/gpu-peaks" \
        /dev/shm/gpu-peaks.temp /dev/shm/gpu-peaks.power /dev/shm/gpu-peaks.reset
    run systemctl --user daemon-reload
    [ "${DRY_RUN:-0}" = 1 ] || ok "removed gpu-peaks service, script and /dev/shm feeds"
fi

echo
echo "  In a running game, press Shift_L+F4 to reload the config; '/' toggles the overlay."
echo "  Shift_L+F1 toggles the FPS limit between the primary screen's cap and unlimited."

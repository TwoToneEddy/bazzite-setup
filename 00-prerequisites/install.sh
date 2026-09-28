#!/usr/bin/env bash
# Install the two kernel-module configs and check the layered packages are there.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

say "kernel module configs"
install_tree

say "kernel modules, right now"
for m in nct6775 i2c-dev; do
    mod=${m//-/_}
    if matches "^$mod " lsmod; then
        skip "already loaded  $m"
    else
        run sudo modprobe "$m" && ok "loaded         $m" || warn "modprobe $m failed - it will be tried again at boot"
    fi
done

say "layered packages"
missing=()
for pkg in coolercontrol lact liquidctl gamescope-session-steam; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
        ok "layered       $pkg"
    else
        missing+=("$pkg")
        warn "missing       $pkg"
    fi
done
if [ "${#missing[@]}" -gt 0 ]; then
    echo
    echo "  Layer them, then reboot - this installer will not do it for you:"
    echo "    sudo rpm-ostree install ${missing[*]}"
    echo "    sudo systemctl reboot"
fi

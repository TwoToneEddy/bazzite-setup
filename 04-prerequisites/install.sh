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

if [ "$DISTRO" = cachyos ]; then
    # CachyOS ships none of the gaming stack Bazzite bundles, so check that too.
    # Plain gamescope is wanted (Bazzite has it in the image); the gamescope
    # *session* is deliberately left out, as on the Bazzite machine.
    say "packages (pacman)"
    missing=()
    for pkg in coolercontrol lact liquidctl i2c-tools lm_sensors \
               steam mangohud lib32-mangohud goverlay gamescope vkbasalt kate base-devel; do
        if pkg_installed "$pkg"; then ok "installed     $pkg"
        else missing+=("$pkg"); warn "missing       $pkg"; fi
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        echo
        echo "  Install them - no reboot needed. coolercontrol/lact are in the CachyOS"
        echo "  repos; if pacman cannot find one, use the AUR (paru):"
        echo "    sudo pacman -S --needed ${missing[*]}"
        echo "    sudo systemctl enable --now coolercontrold lactd"
    fi
    exit 0
fi

say "layered packages"
missing=()
for pkg in coolercontrol lact liquidctl; do  # gamescope-session-steam deliberately not layered
    if rpm -q "$pkg" >/dev/null 2>&1; then
        ok "layered       $pkg"
    else
        missing+=("$pkg")
        warn "missing       $pkg"
    fi
done
if [ "${#missing[@]}" -gt 0 ]; then
    echo
    echo "  Layer them, then reboot - this installer will not do it for you."
    copr_missing=0
    for pkg in "${missing[@]}"; do
        case $pkg in coolercontrol|lact) copr_missing=1 ;; esac
    done
    if [ "$copr_missing" = 1 ]; then
        echo "  coolercontrol and lact are not in Fedora's repos; add their COPRs first:"
        echo "    F=\$(rpm -E %fedora)"
        echo "    sudo curl -fLo /etc/yum.repos.d/_copr_codifryed-CoolerControl.repo https://copr.fedorainfracloud.org/coprs/codifryed/CoolerControl/repo/fedora-\$F/codifryed-CoolerControl-fedora-\$F.repo"
        echo "    sudo curl -fLo /etc/yum.repos.d/_copr_ilyaz-LACT.repo https://copr.fedorainfracloud.org/coprs/ilyaz/LACT/repo/fedora-\$F/ilyaz-LACT-fedora-\$F.repo"
    fi
    echo "    sudo rpm-ostree install ${missing[*]}"
    echo "    sudo systemctl reboot"
fi

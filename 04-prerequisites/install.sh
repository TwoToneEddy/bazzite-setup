#!/usr/bin/env bash
# Install the two kernel-module configs and layer the packages stage 2 needs.
# Layering means a reboot; this asks first, and never reboots on its own.
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
for pkg in coolercontrol lact liquidctl; do  # gamescope-session-steam deliberately not layered
    if rpm -q "$pkg" >/dev/null 2>&1; then
        ok "layered       $pkg"
    else
        missing+=("$pkg")
        warn "missing       $pkg"
    fi
done
[ "${#missing[@]}" -gt 0 ] || exit 0

# coolercontrol and lact are not in Fedora's repos. -f makes curl fail rather than
# save a 404 page if a COPR has no build for this Fedora release yet.
say "COPR repos"
F=$(rpm -E %fedora)
add_copr() {  # add_copr <owner/project> <repo file>
    local dst=/etc/yum.repos.d/$2 owner=${1%/*} project=${1#*/}
    if [ -e "$dst" ]; then skip "present       $dst"; return 0; fi
    run sudo curl -fsSLo "$dst" \
        "https://copr.fedorainfracloud.org/coprs/$1/repo/fedora-$F/$owner-$project-fedora-$F.repo" \
        || die "no $1 COPR for Fedora $F - check https://copr.fedorainfracloud.org/coprs/$1/"
    [ "${DRY_RUN:-0}" = 1 ] || ok "added         $dst"
}
for pkg in "${missing[@]}"; do
    case $pkg in
        coolercontrol) add_copr codifryed/CoolerControl _copr_codifryed-CoolerControl.repo ;;
        lact)          add_copr ilyaz/LACT _copr_ilyaz-LACT.repo ;;
    esac
done

# Layering builds a new deployment; nothing exists until it is booted. --idempotent
# makes a re-run before that reboot a no-op instead of an error.
say "layering ${missing[*]}"
run sudo rpm-ostree install --idempotent "${missing[@]}"
[ "${DRY_RUN:-0}" = 1 ] && exit 0

echo
echo "  ${missing[*]} are layered on a new deployment, which exists only after a reboot."
echo "  05, 07 and 08 need it. After rebooting, run ./install-all.sh again."
# Never reboot unasked: only on an explicit yes at a terminal.
if [ -t 0 ]; then
    read -r -p "  Reboot now? [y/N] " answer
    case $answer in [yY]*) sudo systemctl reboot ;; esac
fi
exit 100  # install-all.sh: stop here, a reboot is pending

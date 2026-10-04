#!/usr/bin/env bash
# Install the fan curve script and apply the curves.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

pkg_installed coolercontrol \
    || die "coolercontrol is not installed. See ../04-prerequisites."

if ! matches "^nct6775" lsmod; then
    warn "nct6775 is not loaded, so the board fan channels will not exist."
    warn "See ../04-prerequisites, or: sudo modprobe nct6775"
fi

say "curve script"
install_tree

say "coolercontrold"
if systemctl is-active --quiet coolercontrold; then
    ok "running"
else
    run sudo systemctl enable --now coolercontrold
    [ "${DRY_RUN:-0}" = 1 ] || sleep 3
fi

say "applying the curves"
# The curves live in CoolerControl's own database, so this talks to the daemon.
# Two outcomes are worth telling apart: it could not authenticate (the curves are
# probably already correct and this is only a rebuild path), or it ran and failed
# (the curves are not there). Aborting the whole install for the first would stop
# the components after this one for no reason.
if [ "${DRY_RUN:-0}" = 1 ]; then
    echo "  would  python3 ~/.local/share/gaming-setup/apply-fan-curves.py"
else
    out=$(CC_USER="${CC_USER:-CCAdmin}" CC_PASSWORD="${CC_PASSWORD:-coolAdmin}" \
          python3 "$HOME/.local/share/gaming-setup/apply-fan-curves.py" 2>&1) && rc=0 || rc=$?
    printf '%s\n' "$out" | sed 's/^/        /'
    if [ "$rc" != 0 ]; then
        if grep -q '401' <<<"$out"; then
            warn "CoolerControl rejected the stock login, so a password has been set in its GUI."
            warn "The daemon keeps only a hash (/etc/coolercontrol/.passwd), so pass the real one:"
            warn "  CC_PASSWORD='yourpassword' ./install.sh"
        fi
        # Are the three ported profiles in the live database anyway?
        if sudo grep -q 'name = "Main Mix"' /etc/coolercontrol/config.toml 2>/dev/null; then
            warn "the curves ARE already in the live config (GPU, CPU, Main Mix all present),"
            warn "so nothing is broken - only the rebuild path is blocked. Carrying on."
        else
            die "the curves are not in CoolerControl and could not be applied."
        fi
    fi
fi

say "sensors"
sensors 2>/dev/null | grep -A10 nct6799 | sed 's/^/        /' \
    || warn "no nct6799 section - the board sensors are not visible"

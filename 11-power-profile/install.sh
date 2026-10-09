#!/usr/bin/env bash
# Put the power mode on Performance, and keep it there across reboots.
#
# KDE's Power Mode switch talks to tuned-ppd, not power-profiles-daemon, and
# tuned-ppd maps it onto a TuneD profile (performance -> throughput-performance-bazzite).
# Two places decide what it comes up as at boot:
#
#   /etc/tuned/ppd_base_profile  the last choice, restored at boot. Setting the
#                                profile over D-Bus writes it.
#   /etc/tuned/ppd.conf default= used only if that file is empty or lost.
#
# Both are in /etc, so per-deployment: re-run this after an rpm-ostree rollback.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

WANT=performance
CONF=/etc/tuned/ppd.conf
BUS=(org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles
     org.freedesktop.UPower.PowerProfiles)

active_profile() {
    busctl get-property "${BUS[@]}" ActiveProfile 2>/dev/null | awk -F'"' '{print $2}'
}

systemctl is-active --quiet tuned-ppd \
    || die "tuned-ppd is not running. Bazzite ships it; systemctl status tuned-ppd"

say "the boot-time fallback in $CONF"
[ -r "$CONF" ] || die "$CONF not found"
if grep -q "^default=$WANT\$" "$CONF"; then
    skip "unchanged     default=$WANT"
else
    back_up "$CONF"
    run sudo sed -i "s/^default=.*/default=$WANT/" "$CONF"
    [ "${DRY_RUN:-0}" = 1 ] || ok "set           default=$WANT"
fi

say "the active power mode"
now=$(active_profile)
if [ "$now" = "$WANT" ]; then
    skip "unchanged     $WANT ($(tuned-adm active 2>/dev/null | sed 's/.*: //'))"
else
    # SetActiveProfile also saves it as the base profile restored at boot.
    # polkit lets the logged-in user do this; fall back to sudo if it does not.
    run busctl set-property "${BUS[@]}" ActiveProfile s "$WANT" 2>/dev/null \
        || run sudo busctl set-property "${BUS[@]}" ActiveProfile s "$WANT" \
        || die "could not set the power mode to $WANT"
    if [ "${DRY_RUN:-0}" != 1 ]; then
        now=$(active_profile)
        [ "$now" = "$WANT" ] || die "asked for $WANT, tuned-ppd reports '$now'"
        ok "switched      ${now:-?} -> $(tuned-adm active 2>/dev/null | sed 's/.*: //')"
    fi
fi

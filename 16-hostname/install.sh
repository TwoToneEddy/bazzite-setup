#!/usr/bin/env bash
# Hostname: a fixed static hostname, so it cannot change under a running session.
#
# With no static hostname (/etc/hostname empty, the Bazzite default) NetworkManager
# sets a transient one from a reverse-DNS lookup of the address, after login. Every X11
# app started before that - Steam, from autostart - keeps tagging its windows
# with the old name, which then no longer resolves. KWin resolves that name each
# time such a window closes, and blocks its main thread until the lookup gives up
# (4 s here): Steam's hover tooltips froze the whole desktop. See README.
#
# A static hostname wins over NetworkManager's, so the name never moves. It is
# written to /etc/hostname - per-deployment, like the rest of /etc: re-run this
# after an rpm-ostree rollback.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

WANT=bazzite      # also recorded as HOSTNAME in machine-profile.conf

have hostnamectl || die "hostnamectl not found"

say "static hostname"
static=$(hostnamectl --static 2>/dev/null || true)
live=$(hostname)
if [ "$static" = "$WANT" ] && [ "$live" = "$WANT" ]; then
    skip "unchanged     static and live hostname are $WANT"
else
    # Sets the static (/etc/hostname) and transient name together.
    run sudo hostnamectl hostname "$WANT" || die "hostnamectl hostname $WANT failed"
    [ "${DRY_RUN:-0}" = 1 ] || ok "set           static '${static:-<none>}' live '$live' -> $WANT"
fi

[ "${DRY_RUN:-0}" = 1 ] && exit 0

say "verify"
[ "$(hostnamectl --static)" = "$WANT" ] || die "static hostname is '$(hostnamectl --static)', not $WANT"
[ "$(hostname)" = "$WANT" ] || die "live hostname is '$(hostname)', not $WANT"
ok "static and live hostname: $WANT"
# What KWin does on every X11 window close: this must answer instantly.
t0=$(date +%s%N)
getent ahosts "$WANT" >/dev/null || die "$WANT does not resolve - check hosts: in /etc/nsswitch.conf"
ms=$(( ($(date +%s%N) - t0) / 1000000 ))
[ "$ms" -lt 500 ] && ok "$WANT resolves in ${ms} ms" || warn "$WANT took ${ms} ms to resolve"

if [ "$live" != "$WANT" ]; then
    echo
    echo "  The live hostname just changed from '$live'. X11 apps already running"
    echo "  still use the old name, which can now stall KWin the same way. Reboot,"
    echo "  or at least fully quit and restart Steam and any other XWayland app."
fi

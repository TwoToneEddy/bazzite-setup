#!/usr/bin/env bash
# Wake-on-LAN: magic-packet wake on every active wired NetworkManager connection.
#
# The setting lives in the NetworkManager connection profile
# (802-3-ethernet.wake-on-lan), which NM applies to the NIC each time the
# connection comes up, so it survives reboots. The profile is in
# /etc/NetworkManager/system-connections - per-deployment, like the rest of /etc:
# re-run this after an rpm-ostree rollback.
#
# Nothing here is hardcoded: the connection and interface are found at run time,
# because their names and UUIDs change on a fresh install.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

WANT=magic

have nmcli || die "nmcli not found - NetworkManager is how Bazzite manages the network"

say "active wired connections"
mapfile -t conns < <(nmcli -t -f UUID,TYPE,DEVICE connection show --active \
    | awk -F: '$2 == "802-3-ethernet" {print $1 ":" $3}')
[ "${#conns[@]}" -gt 0 ] || die "no active wired connection. WoL needs Ethernet; Wi-Fi cannot wake the PC."

for entry in "${conns[@]}"; do
    uuid=${entry%%:*}; dev=${entry#*:}
    name=$(nmcli -g connection.id connection show uuid "$uuid")
    mac=$(cat "/sys/class/net/$dev/address" 2>/dev/null || echo unknown)
    say "$name ($dev, MAC $mac)"

    now=$(nmcli -g 802-3-ethernet.wake-on-lan connection show uuid "$uuid")
    if [ "$now" = "$WANT" ]; then
        skip "unchanged     802-3-ethernet.wake-on-lan $WANT"
    else
        # polkit lets the logged-in user modify system connections; sudo otherwise.
        run nmcli connection modify uuid "$uuid" 802-3-ethernet.wake-on-lan "$WANT" 2>/dev/null \
            || run sudo nmcli connection modify uuid "$uuid" 802-3-ethernet.wake-on-lan "$WANT" \
            || die "could not set wake-on-lan on $name"
        # reapply pushes the change to the NIC without dropping the link.
        run nmcli device reapply "$dev" 2>/dev/null || run sudo nmcli device reapply "$dev" \
            || die "saved, but could not reapply to $dev - it takes effect on the next reconnect"
        [ "${DRY_RUN:-0}" = 1 ] || ok "set           802-3-ethernet.wake-on-lan $now -> $WANT"
    fi

    [ "${DRY_RUN:-0}" = 1 ] && continue
    # What the NIC itself says. Reading wake settings from ethtool needs root.
    if out=$(sudo ethtool "$dev" 2>/dev/null); then
        supports=$(awk -F': ' '/Supports Wake-on/ {print $2}' <<<"$out")
        wakeon=$(awk -F': ' '/^[[:space:]]*Wake-on/ {print $2}' <<<"$out")
        case "$supports" in *g*) ;; *) die "$dev does not support magic-packet wake (Supports Wake-on: ${supports:-?})" ;; esac
        case "$wakeon" in
            *g*) ok "NIC armed     Wake-on: $wakeon" ;;
            *) die "NM has $WANT, but the NIC reports Wake-on: ${wakeon:-?}" ;;
        esac
    else
        warn "could not run sudo ethtool $dev - NIC state unverified"
    fi
    wake=$(cat "/sys/class/net/$dev/device/power/wakeup" 2>/dev/null || echo unknown)
    note_="/sys/class/net/$dev/device/power/wakeup: $wake"
    [ "$wake" = enabled ] && ok "$note_" || warn "$note_"
done

say "what a script cannot do"
skip "the BIOS must allow wake from PCIe/network and have ErP disabled - see README"
skip "wake from a powered-off PC is untested until someone sends a packet"

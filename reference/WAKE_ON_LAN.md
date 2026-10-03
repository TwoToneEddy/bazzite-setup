# Wake-on-LAN

Wake-on-LAN was enabled on this machine on 2026-10-03 through its wired
NetworkManager connection. The saved profile requests magic-packet wake and was
reapplied to the active adapter without disconnecting it.

| Setting | Recorded value |
|---|---|
| Ethernet adapter | `enp5s0` |
| MAC address (magic-packet destination) | `8c:32:23:77:1b:e8` |
| Connection name | `Wired connection 1` |
| Connection UUID | `eff48623-24fb-3b55-90f5-aceaa0aad749` |
| `802-3-ethernet.wake-on-lan` | `magic` |
| `/sys/class/net/enp5s0/device/power/wakeup` | `enabled` |

## Reproduce the setting

Find the active wired connection first; the interface name and UUID can change
on a fresh install or another machine:

```bash
nmcli -t -f NAME,UUID,TYPE,DEVICE connection show --active
ip -brief link
```

For the recorded connection:

```bash
nmcli connection modify uuid eff48623-24fb-3b55-90f5-aceaa0aad749 \
    802-3-ethernet.wake-on-lan magic
nmcli device reapply enp5s0
```

The first command saves the setting for subsequent connection activations,
including after reboot. The second applies it now. Both succeeded in the local
desktop session without sudo; if NetworkManager denies permission in another
session, run them with sudo. This is a manual setting, not part of
`install-all.sh`.

## Verify and use

```bash
nmcli -f 802-3-ethernet.wake-on-lan connection show \
    uuid eff48623-24fb-3b55-90f5-aceaa0aad749
cat /sys/class/net/enp5s0/device/power/wakeup
sudo ethtool enp5s0
```

The first two checks returned `magic` and `enabled`. NetworkManager also reported
that the connection was successfully reapplied. The privileged `ethtool` check
has **not** been completed: the unprivileged query could not read the wake
settings. With privileges, look for `g` in `Supports Wake-on` and `Wake-on: g`.

From another device on the same LAN, send a Wake-on-LAN magic packet to
`8c:32:23:77:1b:e8`. Keep Ethernet connected and the PC connected to power.
Firmware must allow network/PCIe wake for the power state being used.

**Actual wake from sleep or shutdown has not been tested.** Suspend and hibernate
are deliberately masked on this machine; do not unmask them to set up WoL.
[`06-displays-sleep`](../06-displays-sleep/) only blanks the displays while the
PC stays awake. After a deployment change, recheck the saved connection setting.

## Disable

```bash
nmcli connection modify uuid eff48623-24fb-3b55-90f5-aceaa0aad749 \
    802-3-ethernet.wake-on-lan none
nmcli device reapply enp5s0
```

To restore the previous profile value instead of explicitly disabling WoL, use
`default` in place of `none`.

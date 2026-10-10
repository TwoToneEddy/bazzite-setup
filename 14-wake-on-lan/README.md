# 14 — Wake-on-LAN

Lets another device on the LAN switch this PC on with a magic packet.

```bash
./install.sh                    # or ../install-all.sh 14
```

## What it changes

| Where | |
|---|---|
| every **active wired** NetworkManager connection | `802-3-ethernet.wake-on-lan` → `magic`, then `nmcli device reapply` so it takes effect without dropping the link |

No files are copied, so there is no `files/` tree. Nothing is hardcoded either: the
connection and interface are found at run time, because the connection's UUID
changes on every fresh install (it did between 2026-10-03 and 2026-10-10 here).

NetworkManager writes the setting to the NIC each time the connection comes up, so
it survives reboots. The profile itself lives in
`/etc/NetworkManager/system-connections/`, which is **per-deployment**: re-run this
after an `rpm-ostree rollback`.

## Verify

```bash
../status.sh 14
sudo ethtool enp5s0 | grep Wake-on      # want: Supports Wake-on: ...g...  and  Wake-on: g
cat /sys/class/net/enp5s0/device/power/wakeup      # enabled
```

The installer checks both and stops if the NIC does not report `Wake-on: g`.
Verified on 2026-10-10: `enp5s0` (Realtek, `r8169`), MAC `8c:32:23:77:1b:e8`,
`Wake-on: g`, device wakeup `enabled`.

## Use it

From another machine on the same LAN, send a magic packet to the MAC the
installer printed:

```bash
wakeonlan 8c:32:23:77:1b:e8        # or: wol 8c:32:23:77:1b:e8
```

Phone apps work too. Over the internet it needs the router to forward a UDP port
(usually 9) to the broadcast address, which most home routers will not do — use a
VPN onto the LAN, or a device on it, instead.

## What needs a human

* **The BIOS.** Wake from a powered-off PC (S5) needs the board to keep the NIC
  powered: on the SAPPHIRE NITRO+ B850M look for **ErP Ready → Disabled** and
  **Power On By PCI-E / Wake on LAN → Enabled** (names vary by BIOS version).
  With ErP enabled the NIC has no standby power and nothing here can help.
* **An actual wake test.** Shut down, send a packet, see it boot. **Not yet done.**
  Suspend and hibernate are deliberately masked on this machine (see
  `06-displays-sleep`), so shutdown → wake is the case that matters; do not unmask
  sleep targets to test WoL.
* **Windows dual-boot.** If Windows was the last OS shut down, *its* NIC driver
  settings decide whether WoL is armed — and Windows Fast Startup can leave it
  off. Enable "Wake on Magic Packet" in the adapter's properties there too.

## Undo

```bash
nmcli connection modify "Wired connection 1" 802-3-ethernet.wake-on-lan default
nmcli device reapply enp5s0
```

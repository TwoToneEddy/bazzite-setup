# Bazzite KDE power profiles

## Select a profile

1. Open the system tray near the clock; use the arrow to reveal hidden items.
2. Open **Power and Battery** (the name may be **Battery and Brightness** on
   other Plasma versions).
3. Set **Power Profile** to **Performance**.

Choose **Balanced** in the same control to undo the change. No package install
or reboot is needed. System Settings → Power Management also has profile
switching settings; the tray control is the direct way to change the current
profile.

Performance favours performance over energy savings and can increase power use,
heat and fan noise. Compare the same game scene with each profile, including
frame times; selecting Performance does not establish that FPS improved.

## Verify the active profile

These checks are read-only and do not need sudo:

```bash
tuned-adm active
busctl get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles \
  net.hadess.PowerProfiles ActiveProfile
```

On this machine, Performance returns:

```text
Current active profile: throughput-performance-bazzite
s "performance"
```

Bazzite uses `tuned` with `tuned-ppd` to expose the profiles to KDE. The mapping
in this installation's `/etc/tuned/ppd.conf` is:

| KDE profile | TuneD profile |
|---|---|
| Power Save | `powersave-bazzite` |
| Balanced | `balanced-bazzite` |
| Performance | `throughput-performance-bazzite` |

`powerprofilesctl` is not installed on this machine; its absence does not mean
power profiles are unavailable. No need to install a replacement power daemon.

For this Ryzen system using `amd-pstate-epp`, also check:

```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference
```

The observed value changed from `balance_performance` to `performance`.
The governor name alone is insufficient to determine the power profile: with
AMD P-State, `powersave` can still permit boost and dynamic frequency scaling.
The sysfs path and available preferences can differ on other hardware.

## Recorded state

Verified live on **2026-10-03**, Bazzite **44.20260929.0**, Ryzen **7 9800X3D**:
KDE reported `performance`, TuneD reported `throughput-performance-bazzite`, and
CPU 0's energy performance preference was `performance`. No gaming benchmark
was run, and persistence across a reboot was not tested. Recheck after a reboot
or deployment change when reproducing this setup.

References: [KDE Power Management](https://docs.kde.org/stable_kf6/en/powerdevil/kcontrol/powerdevil/index.html)
and [AMD P-State driver documentation](https://cdn.kernel.org/doc/html/latest/admin-guide/pm/amd-pstate.html).

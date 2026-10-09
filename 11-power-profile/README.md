# 11 — Power mode: always Performance

Puts the KDE power mode on **Performance** and keeps it there across reboots.
Out of the box Bazzite boots into Balanced.

## What it changes

| Where | |
|---|---|
| `/etc/tuned/ppd.conf` | `default=balanced` → `default=performance` (one line; the rest is the image's) |
| the active power mode | set to `performance` over D-Bus, which also writes `/etc/tuned/ppd_base_profile` |

No files are copied, so there is no `files/` tree.

## How it works

KDE's Power Mode switch does not talk to `power-profiles-daemon` here. Bazzite
runs **`tuned-ppd`**, which offers the same D-Bus API and maps each mode onto a
TuneD profile (from `ppd.conf`):

| KDE mode | TuneD profile |
|---|---|
| Power Save | `powersave-bazzite` |
| Balanced | `balanced-bazzite` |
| Performance | `throughput-performance-bazzite` |

At boot `tuned-ppd` restores the last mode it was given, from
`/etc/tuned/ppd_base_profile`. `default=` in `ppd.conf` is used only when that file
is empty or missing. So editing `default=` on its own changes nothing on a machine
that has already booted once, which is why the installer also sets the active
mode.

## Traps

* **Both files are in `/etc`, so they are per-deployment.** After
  `rpm-ostree rollback`, re-run this installer.
* **Choosing another mode in KDE overrides this**, and that choice then survives
  reboots in the same way. Re-run the installer to go back.
* **`powerprofilesctl` does not exist here.** Use `tuned-adm active`, or read
  `ActiveProfile` on `org.freedesktop.UPower.PowerProfiles` with `busctl`.
* **What it changes is mostly the CPU.** With amd-pstate, the scaling governor
  goes from `powersave` to `performance` and EPP from `balance_performance` to
  `performance`. It barely changes the GPU, and idle power goes up a little.

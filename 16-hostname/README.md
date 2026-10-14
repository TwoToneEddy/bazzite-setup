# 16 — Hostname

A fixed static hostname, `bazzite`, so the name cannot change while a session is
running. Without it, Steam freezes the whole desktop for about 4 seconds whenever
the mouse moves over it.

```bash
./install.sh                    # or ../install-all.sh 16 - asks for sudo
```

## What it changes

| Where | |
|---|---|
| `/etc/hostname` | `bazzite`, via `sudo hostnamectl hostname bazzite` (the static and live name together) |

No `files/` tree: `hostnamectl` writes the file. To use another name, change
`WANT=` in `install.sh` and `HOSTNAME` in `../machine-profile.conf`.

`/etc` is **per-deployment**: re-run this after an `rpm-ostree rollback`.

## Why: the Steam desktop freeze (2026-10-10)

The symptom was a full-desktop freeze of 3–4 s, only with the mouse over Steam, and
never with Steam closed. KWin logged `The main thread was hanging temporarily!`
after each one. The GPU, memory, CPU and disk were all idle, and nothing was stuck
in the kernel.

A root backtrace of `kwin_wayland` during a freeze showed what the main thread
was waiting on:

```
KWin::Compositor::composite
 └ KWin::X11Window::~X11Window          a Steam tooltip/menu window closing
    └ KWin::ClientMachine::~ClientMachine
       └ KWin::GetAddrInfo::~GetAddrInfo
          └ QFutureInterfaceBase::waitForFinished    getaddrinfo() on the window's hostname
```

KWin resolves every X11 window's `WM_CLIENT_MACHINE` to decide whether the client
is local. If the window is destroyed before the lookup finishes, the destructor
waits for it on the main thread, and the compositor stops until it returns.

Bazzite ships with an **empty `/etc/hostname`**. The boot hostname was `bazzite`,
and 25 s after login NetworkManager set a **transient** one from a reverse-DNS
lookup of the machine's address:

```
NetworkManager: policy: set-hostname: shortened hostname from address lookup
                from 'DESKTOP-0I6MD3A.ts.net\032lan' to 'DESKTOP-0I6MD3A'
```

Steam had already started from autostart, so its windows said
`WM_CLIENT_MACHINE = "bazzite"`. Once the name changed, `bazzite` no longer
resolved: `getent ahosts bazzite` took **4.05 s** to fail. Steam opens and closes
tooltip windows as the mouse moves over it, and each close froze the desktop for
the length of that lookup.

A static hostname takes priority over NetworkManager's transient one, so the name
stays fixed from boot to shutdown and always resolves instantly through
`nss-myhostname`.

## Also: the Hunt / ARC Raiders freezes (2026-10-14)

Together with turning off Steam's *GPU accelerated rendering in web views*
(Settings → Interface), the user reports this fixed the ~5 s in-game freezes in
Hunt: Showdown and ARC Raiders that `tools/hunt-diagnostics/` was investigating.
Before, the router's DHCP was naming the machine. The two changes were not tested
separately.

## Verify

```bash
../status.sh 16
hostnamectl                          # Static hostname: bazzite
time getent ahosts bazzite           # instant, ::1 / link-local
```

## Traps

**Changing the hostname under a running session causes the same freeze.** Any
X11 app started before the change keeps the old name. Reboot after installing
this, or at least fully quit and restart Steam.

**If it ever recurs**, check what name the window is actually carrying against the
live name, and time the lookup:

```bash
hostname; hostnamectl --static
DISPLAY=:0 xwininfo -root -children | grep -i steam      # pick a window id
DISPLAY=:0 xprop -id <id> WM_CLIENT_MACHINE
time getent ahosts <that name>
```

# 15 — Windows drive, mounted at boot

Mounts the Windows partition (`nvme1n1p3`, NTFS, UUID `9AD6814BD6812919`) at
**`/run/media/lee/9AD6814BD6812919`** on every boot — the same path Dolphin's
click-to-mount used, so Steam libraries, shortcuts and `machine-profile.conf`'s
`WIN_MOUNT` keep working without anyone opening Dolphin first.

```bash
./install.sh                    # or ../install-all.sh 15
```

## What it changes

| Where | |
|---|---|
| `/etc/systemd/system/run-media-lee-9AD6814BD6812919.mount` | the mount unit, enabled under `local-fs.target` |

A systemd mount unit rather than an `/etc/fstab` line: Bazzite's fstab is managed
by `bootc-fstab-edit.service`, and a unit is one self-contained file to install or
delete. It is in `/etc`, so **per-deployment** — re-run after an `rpm-ostree rollback`.

If udisks already has the drive mounted, the installer unmounts that and mounts
it via the unit, so this boot matches the next. If something has a file open it
says so and leaves it; reboot or re-run.

Mount options: `ntfs-3g` (the same driver udisks used), `uid=1000,gid=1000,umask=022`
so `lee` owns everything, `windows_names` to refuse filenames Windows cannot open.
It is `WantedBy=local-fs.target`, not `RequiredBy`, so a failed mount never holds
up boot.

## Hardware-specific

The partition UUID and the path are in the unit file, and the file **name** must
match the path (`systemd-escape --path --suffix=mount <path>`). On another machine:

```bash
lsblk -f                         # find the NTFS partition's UUID
```

then edit `What=`, `Where=`, the file name, and `UUID=` in `install.sh`.
`uid=1000` assumes the first user.

## When it does not mount: Windows Fast Startup

If Windows was shut down with **Fast Startup** on (the default) or hibernated,
the volume is left "hibernated" and ntfs-3g refuses to mount it read-write:

```bash
journalctl -u run-media-lee-9AD6814BD6812919.mount     # "Windows is hibernated, refused to mount"
```

Fix it **in Windows**: Control Panel → Power Options → *Choose what the power
buttons do* → untick **Turn on fast startup**. Do not use ntfs-3g's
`remove_hiberfile` — it throws away Windows' saved session and can lose data.
Writing to a hibernated NTFS volume from Linux is how files get corrupted.

## Verify

```bash
../status.sh 15
findmnt /run/media/lee/9AD6814BD6812919        # fuseblk, no uhelper=udisks2 in `mount`
```

Verified on 2026-10-10: mounted by the unit, writable as `lee`.

## Undo

```bash
sudo systemctl disable --now run-media-lee-9AD6814BD6812919.mount
sudo rm /etc/systemd/system/run-media-lee-9AD6814BD6812919.mount
sudo systemctl daemon-reload
```

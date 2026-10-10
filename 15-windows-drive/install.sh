#!/usr/bin/env bash
# Mount the Windows drive at boot, at the path Dolphin's automount used to give it.
#
# A systemd .mount unit rather than an /etc/fstab line: Bazzite's fstab is managed
# by bootc-fstab-edit.service, and a unit file is one self-contained thing to
# install or remove. It is in /etc, so per-deployment: re-run this after an
# rpm-ostree rollback.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

UUID=9AD6814BD6812919
WHERE=/run/media/lee/$UUID
UNIT=$(systemd-escape --path --suffix=mount "$WHERE")

say "the partition"
[ -e "/dev/disk/by-uuid/$UUID" ] \
    || die "no partition with UUID $UUID - find yours with lsblk -f and edit files/ and this script"
ok "found         /dev/disk/by-uuid/$UUID -> $(readlink -f "/dev/disk/by-uuid/$UUID")"
[ "$(id -u)" = 1000 ] || warn "the unit mounts files as uid 1000; you are $(id -u) - edit uid=/gid= in files/"

say "the mount unit"
install_tree
run sudo systemctl daemon-reload
run sudo systemctl enable "$UNIT"

say "mounting it now"
# If udisks (Dolphin) already has it mounted there, systemd treats the unit as
# active but the options are udisks' own. Swap it over so this boot matches the
# next one; if something has a file open, leave it and say so.
# findmnt does not show uhelper=; it lives in libmount's userspace table.
utab=$(grep -F "TARGET=$WHERE " /run/mount/utab 2>/dev/null || true)
if [[ $utab == *uhelper=udisks2* ]]; then
    if run udisksctl unmount -b "/dev/disk/by-uuid/$UUID"; then
        ok "unmounted the udisks automount"
    else
        warn "the udisks mount is busy - close anything using $WHERE and re-run, or reboot"
    fi
fi
if run sudo systemctl start "$UNIT"; then
    [ "${DRY_RUN:-0}" = 1 ] || ok "mounted       $WHERE ($(findmnt -no FSTYPE,OPTIONS "$WHERE" | cut -c1-60))"
else
    warn "the mount failed - journalctl -u $UNIT"
    warn "'volume is hibernated' means Windows Fast Startup is on: turn it off in Windows (README)"
    exit 1
fi

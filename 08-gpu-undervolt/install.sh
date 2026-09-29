#!/usr/bin/env bash
# Install the LACT config (the undervolt), restart the daemon, and add the
# overlay's VOLTAGE row, whose feed reads from that daemon.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

rpm -q lact >/dev/null 2>&1 || die "lact is not layered. See ../04-prerequisites."

# The failure this component exists to prevent: a deployment's own /etc carrying a
# stub config. Say plainly what is about to be replaced.
if [ -r /etc/lact/config.yaml ]; then
    live=$(stat -c%s /etc/lact/config.yaml)
    mine=$(stat -c%s files/system/etc/lact/config.yaml)
    say "existing config is $live bytes; the one here is $mine"
    if ! cmp -s files/system/etc/lact/config.yaml /etc/lact/config.yaml; then
        grep -q '^profiles:' /etc/lact/config.yaml 2>/dev/null \
            && warn "the live config has profiles of its own and they differ from these." \
            || warn "the live config has no profiles - probably a fresh deployment's stub."
        echo "        A backup is kept at /etc/lact/config.yaml.bak-bazzite-setup"
    fi
fi

say "config"
back_up /etc/lact/config.yaml
install_tree

say "daemon"
run sudo systemctl enable --now lactd
run sudo systemctl restart lactd
if [ "${DRY_RUN:-0}" != 1 ]; then
    sleep 2
    # Two different things can be true here, and only one of them is fine:
    # the profile exists in the config, and the profile is the ACTIVE one.
    # current_profile: null means the undervolt is defined and doing nothing.
    cur=$(sudo grep -m1 '^current_profile:' /etc/lact/config.yaml | awk '{print $2}')
    names=$(sudo sed -n '/^profiles:/,/^[a-z]/p' /etc/lact/config.yaml \
            | grep -oE '^  [A-Za-z0-9_-]+:' | tr -d ' :' | tr '\n' ' ')
    ok "profiles defined: ${names:-none}"
    if [ "$cur" = "null" ] || [ -z "$cur" ]; then
        warn "current_profile is null - the undervolt is DEFINED BUT NOT ACTIVE."
        warn "The card is running at stock. To switch one on:"
        warn "  lact cli profile set UV        (or pick it in the LACT GUI)"
        warn "Left alone deliberately: activating a profile changes GPU voltage and"
        warn "clocks, which is not something an installer should do unasked."
    else
        ok "active profile: $cur"
    fi
    if have lact; then
        gid=$(lact cli list-gpus 2>/dev/null | grep -o '10DE:[A-Z0-9:-]*' | head -1 || true)
        [ -n "$gid" ] && lact cli -g "$gid" stats 2>/dev/null \
            | grep -Ei 'core clock|voltage|power' | sed 's/^/        /' || true
    fi
    say "kernel Xid check"
    # 'NVRM: Xid', not a bare 'xid' - the r8169 ethernet driver prints its chip
    # revision as "XID 641" on every boot, which a loose grep reports as a GPU
    # fault that is not there.
    n=$(journalctl -k --no-pager 2>/dev/null | grep -c 'NVRM: Xid' || true)
    [ "${n:-0}" = 0 ] && ok "no NVRM Xid errors this boot" \
        || warn "$n Xid errors - journalctl -k | grep 'NVRM: Xid'"
fi

say "the GPU id gpu-voltage asks LACT for"
gid=$(grep -m1 '^GPU_ID' "$COMPONENT_DIR/files/home/.local/bin/gpu-voltage" | cut -d'"' -f2 || true)
if [ -n "${gid:-}" ] && have lact; then
    if matches "$gid" lact cli list-gpus; then
        ok "GPU_ID=$gid"
    else
        warn "GPU_ID=$gid is not in 'lact cli list-gpus'."
        warn "Set GPU_ID at the top of files/home/.local/bin/gpu-voltage to the right one,"
        warn "or the VOLTAGE row will read the iGPU and be plausibly wrong."
    fi
fi

say "the overlay's VOLTAGE row"
enable_user_units gpu-voltage.service
assemble_mangohud
if [ "${DRY_RUN:-0}" != 1 ]; then
    sleep 2
    if [ -r /dev/shm/gpu-voltage.mv ]; then ok "gpu-voltage.mv = $(cat /dev/shm/gpu-voltage.mv)"
    else warn "/dev/shm/gpu-voltage.mv not written - systemctl --user status gpu-voltage"; fi
fi

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
    mine=$(stat -c%s "$COMPONENT_DIR/files/system/etc/lact/config.yaml")
    say "existing config is $live bytes; the one here is $mine"
    if ! cmp -s "$COMPONENT_DIR/files/system/etc/lact/config.yaml" /etc/lact/config.yaml; then
        grep -q '^profiles:' /etc/lact/config.yaml 2>/dev/null \
            && warn "the live config has profiles of its own and they differ from these." \
            || warn "the live config has no profiles - probably a fresh deployment's stub."
        echo "        A backup is kept at /etc/lact/config.yaml.bak-bazzite-setup"
    fi
fi

# Which profile is active is the user's choice, made in the GUI or with
# gpu-profile, and the copy here always says null. Carry the live choice over,
# so re-running this installer neither switches the undervolt off nor on.
prev=$(grep -m1 '^current_profile:' /etc/lact/config.yaml 2>/dev/null | awk '{print $2}' || true)

say "config"
back_up /etc/lact/config.yaml
install_tree
if [ -n "${prev:-}" ] && [ "$prev" != null ] && [ "${DRY_RUN:-0}" != 1 ]; then
    if grep -q "^  $prev:\$" /etc/lact/config.yaml; then
        run sudo sed -i "s/^current_profile: .*/current_profile: $prev/" /etc/lact/config.yaml
        ok "kept the active profile: $prev"
    else
        warn "the active profile '$prev' is not in the config here - left at null"
    fi
fi
refresh_desktop_caches

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
        warn "  gpu-profile set UV1     (or the tray icon, Ctrl+Alt+P, or the LACT GUI)"
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
run systemctl --user restart gpu-voltage.service
assemble_mangohud
if [ "${DRY_RUN:-0}" != 1 ]; then
    sleep 2
    for f in gpu-voltage.mv gpu-profile.name; do
        if [ -r "/dev/shm/$f" ]; then ok "$f = $(cat "/dev/shm/$f")"
        else warn "/dev/shm/$f not written - systemctl --user status gpu-voltage"; fi
    done
fi

say "the Ctrl+Alt+P binding (next profile)"
rc="$HOME/.config/kglobalshortcutsrc"
sect='^\[services\]\[gpu-profile-next.desktop\]'
if grep -A1 "$sect" "$rc" 2>/dev/null | grep -qx '_launch=Ctrl+Alt+P'; then
    ok "already bound  Ctrl+Alt+P"
elif grep -q "$sect" "$rc" 2>/dev/null; then
    # An older install bound Meta+F12; rebind that section in place.
    back_up "$rc"
    run sed -i "/$sect/,/^\[/ s/^_launch=.*/_launch=Ctrl+Alt+P/" "$rc"
    warn "rebound to Ctrl+Alt+P - takes effect after logging out and back in, or set it"
    warn "now in System Settings -> Shortcuts -> Next GPU profile."
else
    back_up "$rc"
    if [ "${DRY_RUN:-0}" = 1 ]; then
        echo "  would  add [services][gpu-profile-next.desktop] _launch=Ctrl+Alt+P to $rc"
    else
        printf '\n[services][gpu-profile-next.desktop]\n_launch=Ctrl+Alt+P\n' >> "$rc"
        ok "bound         Ctrl+Alt+P -> gpu-profile next"
        # There is no live reload: this Plasma's KGlobalAccel has no reloadConfig
        # method (introspected). The binding also ships as
        # ~/.local/share/kglobalaccel/gpu-profile-next.desktop (X-KDE-Shortcuts),
        # which kglobalacceld reads at login.
        warn "Ctrl+Alt+P takes effect after logging out and back in, or set it now in"
        warn "System Settings -> Shortcuts -> Add New -> Application -> Next GPU profile."
    fi
fi

say "the profile tray icon"
if ! python3 -c 'import PySide6' 2>/dev/null; then
    warn "PySide6 is missing, so the tray icon cannot start - see ../03-dlss-debug-overlay."
elif pgrep -f gpu-profile-tray >/dev/null; then
    ok "already running (pid $(pgrep -f gpu-profile-tray | head -1))"
    echo "        restart it to pick up a new version:"
    echo "          pkill -f gpu-profile-tray; setsid ~/.local/bin/gpu-profile-tray &"
elif [ "${DRY_RUN:-0}" = 1 ]; then
    echo "  would  start ~/.local/bin/gpu-profile-tray"
else
    setsid "$HOME/.local/bin/gpu-profile-tray" >/dev/null 2>&1 &
    sleep 2
    pgrep -f gpu-profile-tray >/dev/null && ok "started" || warn "it did not stay running"
fi

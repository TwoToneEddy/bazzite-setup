#!/usr/bin/env bash
# health-check.sh - confirm every component is actually running, not just installed.
#
# Prints one line per check. Nothing here changes anything.
set -u
pass() { printf '  \033[32mok\033[0m    %s\n' "$*"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; }
info() { printf '  ..    %s\n' "$*"; }
hdr()  { printf '\n\033[1m%s\033[0m\n' "$*"; }

hdr "driver and kernel"
nvidia-smi --query-gpu=driver_version,name --format=csv,noheader 2>/dev/null \
    && pass "nvidia-smi answers" || fail "nvidia-smi"
info "kernel $(uname -r)"

hdr "00 prerequisites"
for m in nct6775 i2c_dev; do
    lsmod | grep -q "^$m" && pass "module $m loaded" || fail "module $m not loaded"
done
for p in coolercontrol lact; do
    command -v "${p/coolercontrol/coolercontrold}" >/dev/null 2>&1 \
        && pass "$p present" || fail "$p missing (rpm-ostree install $p)"
done

hdr "01 per-pin current"
systemctl is-active --quiet astral-pins && pass "astral-pins active" || fail "astral-pins not active"
if [ -r /dev/shm/astral-pins ]; then
    pass "reading: $(cat /dev/shm/astral-pins)"
else
    fail "/dev/shm/astral-pins missing"
fi
info "alarm level: $(grep -o -- '--warn [0-9.]*' /etc/systemd/system/astral-pins.service 2>/dev/null | head -1)"

hdr "02 overlay"
[ -r "$HOME/.config/MangoHud/MangoHud.conf" ] && pass "MangoHud.conf present" || fail "MangoHud.conf missing"
for u in gpu-peaks gpu-voltage; do
    systemctl --user is-active --quiet "$u" && pass "$u active" || fail "$u not active"
done
for f in /dev/shm/gpu-peaks.temp /dev/shm/gpu-peaks.power /dev/shm/gpu-voltage.mv; do
    [ -r "$f" ] && pass "$(basename "$f") = $(cat "$f")" || fail "$f missing"
done

hdr "03 DLSS"
command -v dlss >/dev/null && dlss status 2>/dev/null | sed 's/^/        /' || fail "dlss command missing"

hdr "04 DLSS overlay tray"
pgrep -f dlss-overlay-tray >/dev/null && pass "tray running (pid $(pgrep -f dlss-overlay-tray | head -1))" \
    || fail "tray not running"

hdr "05 displays"
command -v display-profile >/dev/null && display-profile status 2>/dev/null | sed 's/^/        /' \
    || fail "display-profile missing"

hdr "07 fans"
systemctl is-active --quiet coolercontrold && pass "coolercontrold active" || fail "coolercontrold not active"
sensors 2>/dev/null | grep -q nct6799 && pass "board fan sensors visible" || fail "no nct6799 in sensors"

hdr "08 undervolt"
systemctl is-active --quiet lactd && pass "lactd active" || fail "lactd not active"
if sudo test -r /etc/lact/config.yaml; then
    sudo grep -q 'profiles:' /etc/lact/config.yaml && pass "profiles present in config" \
        || fail "no profiles in /etc/lact/config.yaml - this deployment's /etc may have reset"
    cur=$(sudo grep -m1 '^current_profile:' /etc/lact/config.yaml | awk '{print $2}')
    if [ "$cur" = "null" ] || [ -z "$cur" ]; then
        fail "current_profile is null - the undervolt is defined but NOT active"
    else
        pass "active profile: $cur"
    fi
else
    fail "/etc/lact/config.yaml missing"
fi
n=$(journalctl -k --no-pager 2>/dev/null | grep -c 'NVRM: Xid' || true)
[ "${n:-0}" = 0 ] && pass "no NVRM Xid errors this boot" || fail "$n NVRM Xid errors"

hdr "system"
info "$(systemd-analyze 2>/dev/null | tail -1)"
n=$(systemctl --failed --no-legend | wc -l)
[ "$n" = 0 ] && pass "no failed units" || fail "$n failed units"

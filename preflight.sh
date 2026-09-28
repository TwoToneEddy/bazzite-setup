#!/usr/bin/env bash
# preflight.sh - compare this machine against machine-profile.conf and print an
# adaptation plan. Read-only: it changes nothing, installs nothing.
#
# Run this FIRST on a new machine, before any installer. Everything it reports as
# a difference is a value some component hardcodes, and the line it prints tells
# you which file to edit.
#
#   ./preflight.sh              human-readable report
#   ./preflight.sh --brief      just the differences, for an agent to act on
# No pipefail here, deliberately. Every check in this file is `command | grep`,
# and with pipefail a `grep -q` that matches early kills the writer with SIGPIPE
# and the pipeline reports failure - which made this script declare a correctly
# configured machine to be three things it was not.
set -u
cd "$(dirname "$0")"

# kscreen-doctor colours its output, so every value has escape codes around it.
kd_plain() { kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g'; }
. ./machine-profile.conf

BRIEF=0; [ "${1:-}" = "--brief" ] && BRIEF=1
DIFFS=0

g=$'\033[32m'; y=$'\033[33m'; r=$'\033[31m'; b=$'\033[1m'; o=$'\033[0m'
same() { [ "$BRIEF" = 1 ] || printf '  %sok%s     %s\n' "$g" "$o" "$*"; }
diff_() { DIFFS=$((DIFFS+1)); printf '  %sDIFF%s   %s\n' "$y" "$o" "$*"; }
gone()  { DIFFS=$((DIFFS+1)); printf '  %sABSENT%s %s\n' "$r" "$o" "$*"; }
note()  { [ "$BRIEF" = 1 ] || printf '         %s\n' "$*"; }
hdr()   { [ "$BRIEF" = 1 ] || printf '\n%s%s%s\n' "$b" "$*" "$o"; }
fix()   { printf '         %s-> %s%s\n' "$y" "$*" "$o"; }

[ "$BRIEF" = 1 ] || cat <<BANNER
Comparing this machine against profile "$PROFILE_NAME" ($PROFILE_DATE).
Nothing is changed. Each DIFF or ABSENT names the file that hardcodes the value.
BANNER

hdr "operating system"
live_os=$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")
note "recorded: $OS"
note "live:     $live_os"
if command -v rpm-ostree >/dev/null; then
    same "rpm-ostree system - /etc is per-deployment, see README"
else
    diff_ "not an rpm-ostree system"
    fix "the per-deployment /etc warnings in the READMEs do not apply; ignore them"
fi
if command -v kscreen-doctor >/dev/null; then
    same "KDE Plasma present"
else
    gone "kscreen-doctor - components 05 and 06 are KDE-only and will not work"
    fix "on GNOME or another desktop, 05 and 06 need rewriting against that desktop"
fi

hdr "CPU and motherboard"
live_cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')
live_mb=$(cat /sys/class/dmi/id/board_name 2>/dev/null)
# Substring, not equality: /proc/cpuinfo says "AMD Ryzen 7 9800X3D 8-Core Processor"
# where the profile records the model on its own.
case "$live_cpu" in *"$CPU"*) same "CPU $live_cpu" ;; *) { diff_ "CPU: recorded '$CPU', live '$live_cpu'"; \
    fix "07-fan-control uses '$CPU_TEMP_SENSOR' as the CPU temperature source - on Intel it is coretemp"; } ;;
esac
case "$MOTHERBOARD" in *"$live_mb"*) same "motherboard $live_mb" ;; *)
    diff_ "motherboard: recorded '$MOTHERBOARD', live '$live_mb'"
    fix "00-prerequisites loads the nct6775 module for the $SUPERIO. Check yours:"
    fix "  sudo sensors-detect --auto   then edit files/system/etc/modules-load.d/" ;;
esac

hdr "GPU"
live_vga=$(lspci -Dnn 2>/dev/null | grep -iE 'VGA|3D controller' | grep -i nvidia | head -1)
if [ -z "$live_vga" ]; then
    gone "no NVIDIA GPU found. Components 01, 02, 03, 04, 08 and 10 are all NVIDIA-specific."
else
    live_pci=${live_vga%% *}
    live_id=$(grep -oE '\[10de:[0-9a-f]{4}\]' <<<"$live_vga" | tr -d '[]' | head -1)
    note "live: $live_vga"
    [ "$live_pci" = "$GPU_PCI" ] && same "PCI address $live_pci" || {
        diff_ "PCI address: recorded $GPU_PCI, live $live_pci"
        fix "02-mangohud-overlay/files/home/.config/MangoHud/MangoHud.conf -> pci_dev=$live_pci"
        fix "  (get it wrong and MangoHud silently drops the GPU and VRAM rows)"; }
    [ "$live_id" = "$GPU_PCI_ID" ] && same "GPU model $live_id" \
        || diff_ "GPU model: recorded $GPU_PCI_ID, live $live_id"
    # The subsystem id is what makes this an Astral, which 01 depends on.
    live_sub=$(lspci -Dnnvm -s "$live_pci" 2>/dev/null | awk -F'\t' '/^SVendor|^SDevice/{print $2}' | tr '\n' ' ')
    if grep -qi 'asus\|1043' <<<"${live_sub:-}"; then
        same "ASUS board partner - the Astral pin sensor may be present"
    else
        diff_ "not an ASUS card ($live_sub)"
        fix "01-per-pin-current is ROG Astral-only. Skip it, or run 'sudo astral-pins --probe'"
        fix "  after building, and remove the 12V PINS rows from MangoHud.conf if absent"
    fi
fi
if command -v lact >/dev/null; then
    live_lact=$(lact cli list-gpus 2>/dev/null | grep -oE '10DE:[A-Z0-9.:-]+' | head -1)
    if [ "$live_lact" = "$GPU_LACT_ID" ]; then
        same "LACT id $live_lact"
    else
        diff_ "LACT id: recorded $GPU_LACT_ID, live ${live_lact:-none}"
        fix "02-mangohud-overlay/files/home/.local/bin/gpu-voltage -> GPU_ID=\"$live_lact\""
        fix "  (with the wrong id, 'lact cli' reads the iGPU and prints plausible nonsense)"
    fi
else
    note "lact not installed yet - re-run this after 00-prerequisites to check the LACT id"
fi

hdr "displays"
if command -v kscreen-doctor >/dev/null; then
    live_outs=$(kd_plain | grep -oE '^Output: [0-9]+ [A-Za-z0-9-]+' | awk '{print $3}')
    note "connected: $(tr '\n' ' ' <<<"$live_outs")"
    for pair in "AOC_OUT:$AOC_OUT:$AOC_MODE" "DELL_OUT:$DELL_OUT:$DELL_MODE" "TV_OUT:$TV_OUT:$TV_MODE"; do
        var=${pair%%:*}; rest=${pair#*:}; out=${rest%%:*}; mode=${rest#*:}
        if grep -qx "$out" <<<"$live_outs"; then
            if kd_plain | grep -q "$mode"; then
                same "$var=$out, mode $mode available"
            else
                diff_ "$var=$out is connected but has no $mode mode"
                fix "05-display-switching/files/home/.local/bin/display-profile -> $var / mode"
                fix "  list what it does have: kscreen-doctor -o"
            fi
        else
            diff_ "$var=$out is not connected on this machine"
            fix "05-display-switching/files/home/.local/bin/display-profile -> set $var"
            fix "  connector names move with port and cable; match on the EDID id instead"
        fi
    done
else
    note "skipped - no kscreen-doctor"
fi

hdr "fans"
sensors_out=$(sensors 2>/dev/null)
if grep -qi "${SUPERIO%D}" <<<"$sensors_out"; then
    same "$SUPERIO sensors visible"
    live_fans=$(grep -oE '^fan[0-9]+' <<<"$sensors_out" | tr '\n' ' ')
    note "channels: $live_fans"
    for f in $FAN_MIX $FAN_GPU $FAN_PUMP; do
        grep -qw "$f" <<<"$live_fans" || { diff_ "channel $f not present"; \
            fix "07-fan-control/files/home/.local/share/gaming-setup/apply-fan-curves.py"; }
    done
else
    diff_ "no $SUPERIO sensors. Either nct6775 is not loaded, or this board has another chip."
    fix "sudo modprobe nct6775, then re-run. Otherwise: sudo sensors-detect --auto"
    fix "and set the right module in 00-prerequisites/files/system/etc/modules-load.d/"
fi

hdr "undervolt"
note "recorded profile '$UV_PROFILE': $UV_TARGET (max_core_clock $UV_MAX_CORE_CLOCK)"
note "stock curve on the recorded card: $STOCK_CURVE"
if [ "${live_id:-}" = "$GPU_PCI_ID" ]; then
    note "same GPU model - but an undervolt is silicon-specific, not model-specific:"
    fix "install 08 for the tool and the profile, then VALIDATE before relying on it"
    fix "  watch for faults: journalctl -k | grep 'NVRM: Xid'"
else
    diff_ "different GPU - do not adopt this V/F curve"
    fix "install 08 for LACT itself, then build a curve for the new card"
fi

hdr "external sources"
[ -d "$WIN_MOUNT" ] && same "the Windows install is mounted at $WIN_MOUNT" \
    || note "Windows install not mounted - only needed to re-derive curves and layouts"
if [ -d "$HOME/nvtruehdr/.git" ]; then
    same "nvtruehdr repo present at ~/nvtruehdr"
else
    diff_ "nvtruehdr not cloned"
    fix "git clone $NVTRUEHDR_REPO ~/nvtruehdr   (10-nvtruehdr/install.sh offers to)"
fi

printf '\n'
if [ "$DIFFS" = 0 ]; then
    printf '%sThis machine matches the profile.%s Install in order: ./install-all.sh\n' "$g" "$o"
else
    printf '%s%s differences.%s Edit the files named above FIRST, then ./install-all.sh\n' "$y" "$DIFFS" "$o"
    printf 'Components with no DIFF against them need no changes.\n'
fi

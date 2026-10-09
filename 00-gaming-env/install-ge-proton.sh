#!/usr/bin/env bash
# Download the newest GE-Proton into Steam's compatibilitytools.d.
#
# PROTON_ENABLE_WAYLAND, PROTON_ENABLE_HDR and PROTON_DLSS_UPGRADE in
# 95-gaming.conf do nothing under stock Valve Proton, so GE has to be present.
# Idempotent: if the newest release is already unpacked, nothing is downloaded.
# Older GE versions are left alone - games may be pinned to them.
#
# Choosing it per game (or as Steam's default) is still done in Steam.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

say "GE-Proton"
DEST="$HOME/.local/share/Steam/compatibilitytools.d"
API=https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest

have curl || die "curl is needed to download GE-Proton"

# A failed lookup (offline, rate limited) is a warning, not a failed install.
if ! release=$(curl -fsSL "$API"); then
    warn "could not reach GitHub - GE-Proton not checked"
    exit 0
fi
tag=$(printf '%s' "$release" | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)
# GE-Proton 11+ ships one build per architecture (<tag>-x86_64, <tag>-aarch64);
# older releases ship a single <tag>.tar.gz. Taking the first .tar.gz listed got
# the aarch64 build, which will not run here.
arch=$(uname -m)
urls=$(printf '%s' "$release" | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4)
name=$tag-$arch
case $'\n'$urls$'\n' in *"/$name.tar.gz"$'\n'*) ;; *) name=$tag ;; esac
tar_url=$(printf '%s\n' "$urls" | grep -m1 "/$name\.tar\.gz$" || true)
sum_url=$(printf '%s\n' "$urls" | grep -m1 "/$name\.sha512sum$" || true)
[ -n "$tag" ] || { warn "unexpected GitHub response - GE-Proton not checked"; exit 0; }
[ -n "$tar_url" ] || { warn "$tag has no $arch build - GE-Proton not installed"; exit 0; }

# The tarball unpacks to the asset's name: <tag> or <tag>-<arch>.
if [ -d "$DEST/$name" ]; then skip "unchanged     $name (newest)"; exit 0; fi

if [ "${DRY_RUN:-0}" = 1 ]; then
    printf '  would  download %s into %s\n' "$name" "$DEST"
    exit 0
fi

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
tarball="$tmp/$(basename "$tar_url")"
curl -fL --progress-bar -o "$tarball" "$tar_url" || die "download of $tag failed"

if [ -n "$sum_url" ]; then
    curl -fsSL -o "$tmp/sum" "$sum_url" || die "could not fetch the checksum for $tag"
    ( cd "$tmp" && sha512sum -c --status sum ) || die "checksum mismatch for $tag - not installed"
else
    warn "release has no .sha512sum - installing unverified"
fi

mkdir -p "$DEST"
tar -xzf "$tarball" -C "$DEST" || die "unpacking $tag failed"
ok "installed     $name"
echo "  Restart Steam to see it, then pick it under Properties → Compatibility,"
echo "  or as the default in Settings → Compatibility."

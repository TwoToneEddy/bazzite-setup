#!/usr/bin/env bash
# Clone RHI (ReShade HDR Installer) to ~/RHI, build it, and add its menu entry.
# RHI owns DLSS presets and DLL versions, and the RenoDX / Luma HDR mods.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

REPO_SSH="git@github.com:TwoToneEddy/RHI.git"
REPO_HTTPS="https://github.com/TwoToneEddy/RHI.git"
BRANCH="linux_port"
DIR="$HOME/RHI"

say "the RHI source"
if [ -d "$DIR/.git" ]; then
    ok "repo at ~/RHI (branch $(git -C "$DIR" branch --show-current 2>/dev/null))"
    ok "origin $(git -C "$DIR" remote get-url origin 2>/dev/null)"
elif [ "${DRY_RUN:-0}" = 1 ]; then
    echo "  would  git clone --branch $BRANCH $REPO_SSH ~/RHI"
else
    # SSH first so the checkout can push. A fresh machine often has no key yet,
    # and "Permission denied (publickey)" reads like the repo is missing - so fall
    # back to HTTPS and point origin at SSH for later.
    say "cloning $REPO_SSH"
    if GIT_SSH_COMMAND="ssh -o BatchMode=yes" git clone --branch "$BRANCH" "$REPO_SSH" "$DIR"; then
        ok "cloned        ~/RHI"
    elif git clone --branch "$BRANCH" "$REPO_HTTPS" "$DIR"; then
        git -C "$DIR" remote set-url origin "$REPO_SSH"
        ok "cloned        ~/RHI over HTTPS (no SSH key); origin set to $REPO_SSH"
    else
        die "clone failed. Do it by hand, then re-run: git clone --branch $BRANCH $REPO_SSH ~/RHI"
    fi
fi

say "building RHI"
BIN="$DIR/artifacts/linux-x64/RHI.Linux"
if [ "${DRY_RUN:-0}" = 1 ]; then
    echo "  would  ~/RHI/scripts/build-linux.sh   (first build fetches a user-local .NET SDK - several minutes)"
elif [ -x "$BIN" ]; then
    skip "already built - rebuild after a pull with: ~/RHI/scripts/build-linux.sh"
else
    RHI_SKIP_DESKTOP_PROMPT=1 "$DIR/scripts/build-linux.sh" 2>&1 | sed 's/^/        /' \
        || die "the build failed - run ~/RHI/scripts/build-linux.sh by hand for the full output"
    [ -x "$BIN" ] && ok "built         $BIN" || die "build finished but $BIN is missing"
fi

say "menu entry"
MENU="$HOME/.local/share/applications/rhi-linux.desktop"
if [ "${DRY_RUN:-0}" = 1 ]; then
    echo "  would  ~/RHI/scripts/install-linux-desktop.sh --no-desktop"
elif [ -e "$MENU" ] && grep -q "$DIR/run-linux.sh" "$MENU"; then
    skip "unchanged     $MENU"
else
    "$DIR/scripts/install-linux-desktop.sh" --no-desktop | sed 's/^/        /'
    ok "installed     $MENU"
fi

refresh_desktop_caches

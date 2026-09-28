#!/usr/bin/env bash
# Install the nvtruehdr settings; the layer itself is built from its own repo.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

say "settings"
back_up "$HOME/.config/nvtruehdr/nvtruehdr.conf"
install_tree

REPO="https://github.com/TwoToneEddy/nvtruehdr"

say "the layer source"
if [ -d "$HOME/nvtruehdr/.git" ]; then
    ok "repo at ~/nvtruehdr (branch $(git -C "$HOME/nvtruehdr" branch --show-current 2>/dev/null))"
    ok "origin $(git -C "$HOME/nvtruehdr" remote get-url origin 2>/dev/null)"
elif [ "${DRY_RUN:-0}" = 1 ]; then
    echo "  would  git clone $REPO ~/nvtruehdr"
else
    # HTTPS, not SSH: a fresh machine has no key and the SSH clone fails with
    # "Permission denied (publickey)", which reads like the repo is missing.
    say "cloning $REPO"
    if git clone "$REPO.git" "$HOME/nvtruehdr"; then
        ok "cloned        ~/nvtruehdr"
    else
        warn "clone failed. Do it by hand, then re-run:"
        warn "  git clone $REPO.git ~/nvtruehdr"
    fi
fi

say "building the layer"
if [ -x "$HOME/nvtruehdr/install.sh" ] && [ "${DRY_RUN:-0}" != 1 ]; then
    if [ -e "$HOME/.local/bin/nvtruehdr" ]; then
        skip "already built - rebuild with: cd ~/nvtruehdr && ./install.sh"
    else
        ( cd "$HOME/nvtruehdr" && ./install.sh ) 2>&1 | sed 's/^/        /' \
            || warn "the repo's install.sh failed - run it by hand for the full output"
    fi
else
    [ "${DRY_RUN:-0}" = 1 ] && echo "  would  cd ~/nvtruehdr && ./install.sh"
fi

for f in "$HOME/.local/bin/nvtruehdr" \
         "$HOME/.local/share/vulkan/implicit_layer.d/nvtruehdr_64.json"; do
    [ -e "$f" ] && ok "installed     $f" || warn "not built     $f"
done

say "layer order"
if ls "$HOME/.config/vulkan/implicit_layer.d/"MangoHud.*.json >/dev/null 2>&1; then
    ok "MangoHud is pinned above nvtruehdr"
else
    warn "the MangoHud ordering symlinks are missing - the overlay will be tone-mapped"
    warn "along with the game. See the README."
fi

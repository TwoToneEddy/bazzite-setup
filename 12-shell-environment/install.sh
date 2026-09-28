#!/usr/bin/env bash
# Install the shell aliases and the git prompt, then report which alias targets
# are actually present on this machine.
set -euo pipefail
. "$(dirname "$0")/../common/lib.sh"

say "aliases and prompt"
install_tree

# Fedora's stock ~/.bashrc sources ~/.bashrc.d/* already. Confirm it, rather than
# assuming - a .bashrc carried over from another distribution usually does not.
say "is ~/.bashrc.d sourced?"
if grep -q 'bashrc.d' "$HOME/.bashrc" 2>/dev/null; then
    ok "~/.bashrc already sources ~/.bashrc.d/*"
else
    warn "~/.bashrc does NOT source ~/.bashrc.d/, so nothing here will load."
    warn "Add this to the end of ~/.bashrc:"
    cat <<'SNIP'
        if [ -d ~/.bashrc.d ]; then
            for rc in ~/.bashrc.d/*; do [ -f "$rc" ] && . "$rc"; done
            unset rc
        fi
SNIP
fi

# An alias pointing at a command that is not installed is not an error - it is a
# thing that will fail the first time you use it and leave you wondering why. Say
# which ones now.
say "alias targets on this machine"
missing=0
check_target() {
    local alias_name="$1" cmd="$2" note="${3:-}"
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$(printf '%-8s -> %s' "$alias_name" "$cmd")"
    else
        missing=$((missing+1))
        warn "$(printf '%-8s -> %s is NOT installed' "$alias_name" "$cmd")"
        [ -n "$note" ] && warn "             $note"
    fi
}
check_target gs   git
check_target gk   gitk
check_target cf   socat
check_target pi   ssh

# g is a resolver, not a fixed alias: report which editor it will actually pick.
editor=""
for e in kate kwrite gnome-text-editor gedit; do
    if command -v "$e" >/dev/null 2>&1; then editor="$e"; break; fi
done
if [ -n "$editor" ]; then
    ok "$(printf '%-8s -> %s' g "$editor")"
else
    missing=$((missing+1))
    warn "g        -> no GUI editor found (kate, kwrite, gnome-text-editor, gedit)"
    warn "             sudo rpm-ostree install kate, or flatpak a text editor"
fi

if [ -e "$HOME/common/scripts/commit.sh" ]; then
    ok "$(printf '%-8s -> %s' b "~/common/scripts/commit.sh")"
else
    missing=$((missing+1))
    warn "b        -> ~/common/scripts/commit.sh is NOT present"
fi

say "branch names"
# pull and push name master explicitly. Say which way round this machine is, rather
# than assuming: git only switched its own default recently, and GitHub defaults
# new repositories to main.
here=$(git -C "$COMPONENT_DIR" branch --show-current 2>/dev/null || true)
default=$(git config --get init.defaultBranch || echo master)
if [ -n "$here" ] && [ "$here" != master ]; then
    warn "the 'pull' and 'push' aliases hardcode 'master', but this repo is on '$here'."
    warn "They fail here with \"couldn't find remote ref master\". The file has"
    warn "branch-agnostic replacements commented out if you want them."
else
    ok "this repo is on 'master', so 'pull' and 'push' work here"
    note_default="$default"
    echo "        init.defaultBranch is '$note_default'. GitHub defaults NEW repos to"
    echo "        'main', so those two aliases will fail on anything cloned from there."
fi

if [ "$missing" -gt 0 ]; then
    echo
    echo "  $missing alias target(s) are not on this machine. The aliases are still"
    echo "  installed - they were asked for verbatim - and each one has a comment in"
    echo "  ~/.bashrc.d/50-bazzite-setup.sh saying what the local equivalent is."
fi

echo
echo "  Open a new shell, or run:  source ~/.bashrc     (aliased to 'reload')"

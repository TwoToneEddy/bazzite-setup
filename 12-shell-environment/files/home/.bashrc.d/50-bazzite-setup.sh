# 50-bazzite-setup.sh - aliases, git prompt and shell shortcuts.
#
# Installed by ~/bazzite-setup/12-shell-environment. Fedora's default ~/.bashrc
# already sources every file in ~/.bashrc.d/, so nothing appends to .bashrc - drop
# this file in and open a new shell. `reload` re-reads it.
#
# Interactive shells only: a login shell running a script has no use for aliases,
# and defining them can break scripts that expect the real command.
case $- in *i*) ;; *) return ;; esac

# ---------------------------------------------------------------------------
# Git prompt
# ---------------------------------------------------------------------------
# The prompt shows user@host:dir (branch) $, with the branch in green when the
# working tree is clean and red when it is dirty.
#
# The colour variables and both parse_git_branch functions are defined here
# because the PS1 line on its own references them without providing them - an
# unset $ps1_green silently gives you an uncoloured prompt, and a missing
# parse_git_branch prints "bash: parse_git_branch: command not found" before every
# single prompt.
#
# \[ \] around a non-printing escape is not decoration: without them bash counts
# the escape bytes as visible width, and long command lines wrap over themselves.
ps1_white='\[\033[00m\]'
ps1_green='\[\033[01;32m\]'
ps1_blue='\[\033[01;34m\]'
ps1_red='\[\033[01;31m\]'
ps1_yellow='\[\033[01;33m\]'

# parse_git_branch - " (branch)" when inside a repo, nothing otherwise.
parse_git_branch() {
    local branch
    branch=$(git branch --show-current 2>/dev/null) || return 0
    if [ -z "$branch" ]; then
        # Detached HEAD, mid-rebase or a fresh repo with no commit yet.
        branch=$(git rev-parse --short HEAD 2>/dev/null) || return 0
        [ -n "$branch" ] && printf ' (%s)' "detached $branch"
        return 0
    fi
    printf ' (%s)' "$branch"
}

# parse_git_branch_color - green for a clean tree, red for a dirty one.
# `git status --porcelain` is the cheap check; it stays quiet when there is nothing
# to report. It still costs a fork on every prompt, so in a very large repository
# this is what to remove first if the prompt starts feeling slow.
parse_git_branch_color() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        printf '%s' $'\033[01;31m'      # dirty
    else
        printf '%s' $'\033[01;32m'      # clean
    fi
}

export PS1="$ps1_green\u@\h:$ps1_white\W\[\$(parse_git_branch_color)\]\$(parse_git_branch) $ps1_blue\$$ps1_white "

# ---------------------------------------------------------------------------
# Git
# ---------------------------------------------------------------------------
alias gs='git status -s'
alias gk='gitk --all &'
alias pull='git pull origin master'
alias push='git push origin master'
alias commit='git commit -m "Updates"'
alias add='git add *'
alias gr='git remote -v'
alias prune='git fetch --all --tags --prune'
alias tag='git describe --tags $(git rev-list --tags --max-count=1)'
alias tagl='git describe --tags $(git rev-list --tags --max-count=100)'

# NOTE: pull and push name `master` explicitly. Repositories created in the last
# few years default to `main` - including bazzite-setup itself - so on those two
# they fail with "couldn't find remote ref master". These are kept verbatim
# because that is what was asked for; the branch-agnostic versions, if you ever
# want them:
#     alias pull='git pull origin "$(git branch --show-current)"'
#     alias push='git push origin "$(git branch --show-current)"'
#
# `add` is `git add *`, which is shell globbing, not git's own matching: it skips
# dotfiles and obeys nothing about the repository root. `git add -A` from anywhere
# in the tree is the one that stages everything including deletions.

# ---------------------------------------------------------------------------
# Editors and remote machines
# ---------------------------------------------------------------------------
# g - open something in a GUI editor.
#
# A function rather than an alias, for two reasons. It picks whichever editor the
# machine actually has, so this file survives moving between KDE, GNOME and a bare
# install; and it detaches the editor from the terminal, so `g file` hands the
# prompt straight back instead of tying up the shell until you close the window.
#
# On this KDE system that resolves to kate. Order is deliberate: kate first, then
# its lighter sibling kwrite, then the GNOME editors under both their old and new
# names, then $VISUAL/$EDITOR if one is set to something graphical.
g() {
    local ed
    for ed in kate kwrite gnome-text-editor gedit "${VISUAL:-}" "${EDITOR:-}"; do
        [ -n "$ed" ] || continue
        if command -v "$ed" >/dev/null 2>&1; then
            # setsid + nohup so the editor survives the shell closing, and both
            # streams go nowhere so its Qt/GTK chatter does not litter the prompt.
            setsid nohup "$ed" "$@" >/dev/null 2>&1 &
            return 0
        fi
    done
    echo "g: no GUI editor found (tried kate, kwrite, gnome-text-editor, gedit)" >&2
    return 1
}

alias pi='ssh pi@raspberrypi'

# ---------------------------------------------------------------------------
# Serial ports, 3D printing, microcontrollers
# ---------------------------------------------------------------------------
# WARNING: $H is almost certainly meant to be $HOME. As written, with $H unset,
# PTY,link resolves to "/dev/ttyACM0" - the real device node path - so socat tries
# to create its pseudo-terminal link on top of a kernel device node. Kept verbatim
# because that is what was asked for. The intended version:
#   alias cf="sudo socat PTY,link=$HOME/dev/ttyACM0,raw,echo=0 EXEC:'ssh pi@octopi.local socat - /dev/ttyUSB0'"
alias cf="sudo socat PTY,link=$H/dev/ttyACM0,raw,echo=0  EXEC:'ssh pi@octopi.local socat - /dev/ttyUSB0'"

alias com='sudo chmod 777 /dev/ttyACM0'
alias com1='sudo chmod 777 /dev/ttyACM1'
alias com2='sudo chmod 777 /dev/ttyACM2'
alias com3='sudo chmod 777 /dev/ttyACM3'
alias com4='sudo chmod 777 /dev/ttyACM4'
alias com5='sudo chmod 777 /dev/ttyACM5'
alias ports="ls /dev | grep ttyACM"

# The lasting fix for serial permissions, instead of chmod 777 after every replug:
#   sudo usermod -aG dialout,uucp $USER      # then log out and back in
# On Fedora the group is usually dialout; check with: ls -l /dev/ttyACM0

# ---------------------------------------------------------------------------
# System
# ---------------------------------------------------------------------------
alias usbw='grep . /sys/bus/usb/devices/*/power/wakeup'
alias reload='source ~/.bashrc'
alias b='/home/lee/common/scripts/commit.sh'

# Dropped from the previous machine's set, because their targets do not exist here
# and an alias that only fails when you use it is worse than no alias:
#
#   mm       platformio run -e sanguino_atmega1284p
#            platformio is not installed. On an immutable system run it from a
#            toolbox container rather than layering it.
#   windows  sudo /opt/reboot-into-windows
#            that script was Debian-era. The equivalent here needs no script:
#              systemctl reboot --boot-loader-entry=<id>     # bootctl list
#   cura     an AppImage in /opt with an Ubuntu libstdc++ preload
#              flatpak install flathub com.ultimaker.cura

# 50-bazzite-setup.fish - the fish twin of ~/.bashrc.d/50-bazzite-setup.sh.
#
# Installed by ~/bazzite-setup/12-shell-environment. CachyOS logs in to fish, and
# fish reads every file in ~/.config/fish/conf.d/ by itself, so nothing is added
# to config.fish. Keep the two files in step: the comments on each alias's traps
# (pull/push hardcode master, add is a glob, cf uses $H) live in the bash file.
#
# No prompt here: fish's default prompt already shows the git branch and whether
# the tree is dirty, which is what the bash PS1 was rebuilding by hand.
status is-interactive; or return

# Git
alias gs='git status -s'
alias gk='gitk --all &'
alias pull='git pull origin master'
alias push='git push origin master'
alias commit='git commit -m "Updates"'
alias add='git add *'
alias gr='git remote -v'
alias prune='git fetch --all --tags --prune'
alias tag='git describe --tags (git rev-list --tags --max-count=1)'
alias tagl='git describe --tags (git rev-list --tags --max-count=100)'

# g - open something in a GUI editor, detached from the terminal. See the bash
# file for why this is a function and the order editors are tried in.
function g
    for ed in kate kwrite gnome-text-editor gedit $VISUAL $EDITOR
        if command -q $ed
            setsid nohup $ed $argv >/dev/null 2>&1 &
            disown
            return 0
        end
    end
    echo "g: no GUI editor found (tried kate, kwrite, gnome-text-editor, gedit)" >&2
    return 1
end

alias pi='ssh pi@raspberrypi'

# Serial ports, 3D printing. $H is kept from the original, and is almost certainly
# meant to be $HOME - see the warning in the bash file.
alias cf="sudo socat PTY,link=$H/dev/ttyACM0,raw,echo=0  EXEC:'ssh pi@octopi.local socat - /dev/ttyUSB0'"
alias com='sudo chmod 777 /dev/ttyACM0'
alias com1='sudo chmod 777 /dev/ttyACM1'
alias com2='sudo chmod 777 /dev/ttyACM2'
alias com3='sudo chmod 777 /dev/ttyACM3'
alias com4='sudo chmod 777 /dev/ttyACM4'
alias com5='sudo chmod 777 /dev/ttyACM5'
alias ports='ls /dev | grep ttyACM'

# System
alias usbw='grep . /sys/bus/usb/devices/*/power/wakeup'
alias reload='source ~/.config/fish/config.fish'
alias b='/home/lee/common/scripts/commit.sh'

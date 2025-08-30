#!/bin/zsh
# Times the screen off and puts it to background
# swayidle \
#    timeout 1 'swaymsg "output * dpms off"' \
#    timeout 3 'systemctl suspend' \
#    resume 'swaymsg "output * dpms on"' \
#    before-sleep 'swaylock -c 3cb371'
# Locks the screen immediately
# swaylock -c 3cb371

systemctl suspend

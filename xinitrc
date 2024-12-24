#! /bin/bash

# starting xterm
    xrdb -merge $HOME/.Xresources
    xterm &
# starting networkmanager 
    NetworkManager
# starting pulseaudio
    pulseaudio --start
    pulseaudio --kill
    pulseaudio -D
# fixing keyboard layout
    setxkbmap -layout us -variant intl
# fixing keyboard speed
    xset r rate 130 35
# fixing touchpad
    touchpad=$(xinput list --id-only "SYNA3602:00 0911:5288 Touchpad")
    xinput set-prop $touchpad 350 0
    xinput set-prop $touchpad 359 1 1 1 1 1 1 1
    xinput set-prop $touchpad 360 1 2 3
# avoinding sleep/suspend
    xset s off
    xset -dpms
    xset s noblank
# starting i3
    exec i3
# loading .bashrc
    source $HOME/.bashrc

#!/bin/bash

mode="$1"

case "$mode" in
    menu)
        rofi -show drun -theme "$HOME/.config/rofi/theme.rasi" -show-icons
        ;;
    file)
        nemo
        ;;
    clipman)
        xfce4-clipman-history
        ;;
    lock)
        slock -m "Single is simple, double is double."
        ;;
calc)
        rofi -show calc -modi calc -no-show-match -no-sort -terse -calc-command "echo -n '{result}' | xclip -selection clipboard" -show drun -theme "$HOME/.config/rofi/theme.rasi"
        ;;
esac
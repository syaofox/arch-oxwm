#!/bin/bash

mode="$1"

case "$mode" in
    clip)
        maim -s | xclip -selection clipboard -t image/png && dunstify -r 9988 -t 2000 '截图已保存到剪贴板' || dunstify -r 9988 -t 2000 '截图失败'
        ;;
    save)
        mkdir -p "$HOME/Pictures/Screenshots"
        filepath="$HOME/Pictures/Screenshots/screenshot_$(date +%Y%m%d_%H%M%S).png"
        maim -s "$filepath" && dunstify -r 9988 -t 2000 "截图已保存: $filepath" || dunstify -r 9988 -t 2000 '截图失败'
        ;;
esac
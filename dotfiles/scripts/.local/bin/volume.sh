#!/bin/bash

mode="$1"

get_volume() {
    pactl get-sink-volume @DEFAULT_SINK@ | head -n1 | awk '{print $5}' | sed 's/%//'
}

case "$mode" in
    up)
        pactl set-sink-volume @DEFAULT_SINK@ +5%
        vol=$(get_volume)
        dunstify -r 9988 -t 1000 "Volume ${vol}%"
        ;;
    down)
        pactl set-sink-volume @DEFAULT_SINK@ -5%
        vol=$(get_volume)
        dunstify -r 9988 -t 1000 "Volume ${vol}%"
        ;;
    mute)
        pactl set-sink-mute @DEFAULT_SINK@ toggle
        if pactl get-sink-mute @DEFAULT_SINK@ | grep -q yes; then
            dunstify -r 9988 -t 1000 "Muted"
        else
            vol=$(get_volume)
            dunstify -r 9988 -t 1000 "Volume ${vol}%"
        fi
        ;;
esac
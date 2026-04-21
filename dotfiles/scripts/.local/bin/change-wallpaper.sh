#!/bin/bash

WALLPAPER_DIR="$HOME/.config/walls"
WALLPAPER_CONF="$HOME/.config/oxwm/wallpaper.conf"

if [[ ! -d "$WALLPAPER_DIR" ]]; then
    notify-send "change-wallpaper" "Wallpaper directory not found: $WALLPAPER_DIR"
    exit 1
fi

mapfile -t wallpapers < <(find -L "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) | sort)

if [[ ${#wallpapers[@]} -eq 0 ]]; then
    notify-send "change-wallpaper" "No wallpapers found"
    exit 1
fi

current=""
if [[ -f "$WALLPAPER_CONF" ]]; then
    current="$(cat "$WALLPAPER_CONF")"
fi

next_index=0
if [[ -n "$current" ]]; then
    for i in "${!wallpapers[@]}"; do
        if [[ "$(realpath "${wallpapers[$i]}")" == "$(realpath "$current")" ]]; then
            next_index=$(( (i + 1) % ${#wallpapers[@]} ))
            break
        fi
    done
fi

next_wallpaper="${wallpapers[$next_index]}"

if xwallpaper --zoom "$next_wallpaper"; then
    echo "$next_wallpaper" > "$WALLPAPER_CONF"
    # notify-send "change-wallpaper" "$(basename "$next_wallpaper")"
else
    notify-send "change-wallpaper" "Failed: xwallpaper error"
fi
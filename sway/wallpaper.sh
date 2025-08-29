#!/bin/bash
WALLPAPER_DIR="$HOME/Pictures/kotomi"
INTERVAL=28800

while true; do
    # 用 null 分隔避免空格/特殊字符问题
    mapfile -d '' -t files < <(find "$WALLPAPER_DIR" -type f -print0)
    (( ${#files[@]} )) || { echo "No wallpapers"; exit 1; }

    RANDOM_WALLPAPER=${files[RANDOM % ${#files[@]}]}
    pkill swaybg
    swaybg -i "$RANDOM_WALLPAPER" -m fill &
    sleep $INTERVAL
done

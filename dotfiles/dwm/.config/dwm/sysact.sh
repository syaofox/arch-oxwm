#!/bin/bash
# 使用 dmenu/rofi 显示系统电源菜单

# 定义选项
lock="  Lock"
reboot="  Reboot"
shutdown="  Shutdown"

# 根据安装情况选择菜单工具 (优先 rofi，其次 dmenu)
if command -v rofi &> /dev/null; then
    menu_cmd="rofi -dmenu -i -p System -theme theme"
else
    menu_cmd="dmenu -i -p System:"
fi

# 显示菜单
options="$lock\n$reboot\n$shutdown"
selected="$(echo -e "$options" | $menu_cmd)"

# 执行操作
case "$selected" in
    "$shutdown")
        systemctl poweroff
        ;;
    "$reboot")
        systemctl reboot
        ;;
    "$lock")
        slock
        ;;
esac


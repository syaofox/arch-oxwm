#!/bin/bash
# 复制选中文件/文件夹的名称到剪贴板（不包含路径）

# 检查是否有参数
if [ -z "$1" ]; then
    exit 0
fi

# 收集所有文件名，每行一个
NAMES=""
for path in "$@"; do
    # 只获取文件名（basename）
    FILENAME=$(basename "$path")
    if [ -n "$NAMES" ]; then
        NAMES="$NAMES"$'\n'"$FILENAME"
    else
        NAMES="$FILENAME"
    fi
done

# 尝试使用 wl-clipboard (Wayland)
if command -v wl-copy &> /dev/null; then
    echo -n "$NAMES" | wl-copy
    exit 0
fi

# 尝试使用 xclip (X11)
if command -v xclip &> /dev/null; then
    echo -n "$NAMES" | xclip -selection clipboard
    exit 0
fi

# 如果都没有，尝试使用 xsel (X11 备选)
if command -v xsel &> /dev/null; then
    echo -n "$NAMES" | xsel --clipboard --input
    exit 0
fi

# 如果都没有安装，显示错误信息
zenity --error --text="未找到剪贴板工具！\n请安装 wl-clipboard (Wayland) 或 xclip/xsel (X11)"
exit 1

#!/bin/bash
if [ -z "$1" ]; then exit 0; fi

# 未选中任何文件时，会传入目录，比较 inode
TARGET="$1"
if [ -d "$TARGET" ]; then
    TARGET_INODE=$(stat -c '%i' "$TARGET")
    TARGET_DIR=$(dirname "$TARGET")
    PARENT_INODE=$(stat -c '%i' "$TARGET_DIR")
    # 当前目录的 inode 等于父目录的 inode
    if [ "$TARGET_INODE" = "$PARENT_INODE" ]; then
        zenity --error --text="未选中任何文件，无法操作！"
        exit 1
    fi
fi

BASE_DIR=$(dirname "$TARGET")

# 弹出输入框
NEW_NAME=$(zenity --entry --title="新建文件夹" --text="输入新文件夹名称:" --entry-text="New Folder")

# 如果取消或为空则退出
if [ -z "$NEW_NAME" ]; then exit 0; fi

TARGET_DIR="$BASE_DIR/$NEW_NAME"

# 检查重名
if [ -d "$TARGET_DIR" ]; then
    zenity --error --text="文件夹 \"$NEW_NAME\" 已存在！\n操作已取消。"
    exit 1
fi

# 创建目录并移动
mkdir -p "$TARGET_DIR"
for file in "$@"; do
    if [ -e "$file" ] && [ "$file" != "$BASE_DIR" ]; then
        mv "$file" "$TARGET_DIR/"
    fi
done


#!/bin/bash

# DWM 快捷键帮助脚本
# 使用 rofi 显示快捷键列表

KEYS=$(cat <<'EOF'
基础操作
Super + Space         启动应用菜单 (rofi)
Super + Return        打开终端 (kitty)
Super + e             打开文件管理器 (nemo)
Super + w             打开浏览器 (Brave)
Super + Shift + w     切换壁纸
Super + v             打开剪贴板管理器
Super + s             截图 (复制到剪贴板)
Super + Shift + s     截图 (保存到文件)
Super + Shift + l     锁屏
Super + Shift + /     显示快捷键帮助
Super + Shift + q     退出 DWM
窗口操作
Super + j             聚焦下一个窗口
Super + k             聚焦上一个窗口
Super + q             关闭当前窗口
Super + Shift + Return 交换主窗口 (Zoom)
Super + f             切换到浮动布局
Super + m             切换到 Monocle 布局
Super + Shift + space 切换窗口置顶
布局调整
Super + t             切换到 Tile 布局
Super + b             切换状态栏显示
Super + i             增加主区域客户端数
Super + d             减少主区域客户端数
Super + ,             减小主窗口区域
Super + .             增大主窗口区域
间距调整
Super + equal         增加窗口间隙
Super + Shift + equal 减少窗口间隙
Super + g             切换间隙启用/禁用
Super + Shift + g     重置为默认间隙
标签操作
Super + 1-9           切换到指定标签
Super + Ctrl + 1-9   切换显示指定标签
Super + Alt + 1-9    将窗口移动到指定标签
Super + Ctrl + Alt + 1-9 移动窗口并切换到该标签
Super + Tab           切换到下一个标签
Super + Shift + Tab  切换到上一个标签
鼠标操作
Super + 鼠标左键拖动   移动窗口
Super + 鼠标中键       切换浮动
Super + 鼠标右键拖动  调整窗口大小
Super + 标签栏左键    切换到该标签
Super + 标签栏右键    移动窗口并切换到该标签
Super + 布局图标左键  循环切换布局
Super + 布局图标右键  反向循环切换布局
系统操作
Ctrl + Alt + Delete  电源菜单
EOF
)

echo "$KEYS" | rofi -dmenu -i -no-fixed-num-lines -p "快捷键" -theme theme "listview { columns: 3; } window { width: 50%; height: 70%; }"
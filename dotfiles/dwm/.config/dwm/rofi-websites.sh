#!/usr/bin/env bash

# Rofi 网页启动器 - 改进版
# 配置文件位置: ~/.config/rofi/websites.txt
# 文件格式: 显示名称|URL
# 示例:
#   Google|https://www.google.com
#   GitHub|https://github.com

# set -euo pipefail  # 严格模式

export LANGUAGE=zh_CN
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8

CONFIG_FILE="${HOME}/.config/rofi/websites.txt"
declare -A SITE_URLS=()
declare -a SITE_NAMES=()

# 1. 加载网站列表
if [[ -f "$CONFIG_FILE" ]]; then
    while IFS='|' read -r name url; do
        [[ -z "$name" || -z "$url" ]] && continue
        SITE_URLS["$name"]="$url"
        SITE_NAMES+=("$name")
    done < "$CONFIG_FILE"
else
    # 默认内置列表（当配置文件不存在时使用）
    SITE_URLS=(
        ["Google"]="https://www.google.com"
        ["GitHub"]="https://github.com"        
        ["Arch Wiki"]="https://wiki.archlinux.org"
        ["HomePage"]="http://10.10.10.6:8888"
    )
    SITE_NAMES=("Google" "GitHub" "Arch Wiki" "HomePage")
fi

# 2. 生成显示给 Rofi 的列表（按配置文件顺序）
menu_items=$(printf "%s\n" "${SITE_NAMES[@]}")

# 3. 调用 Rofi 获取用户选择
selected=$(echo "$menu_items" | rofi -dmenu -p " Open website" -i -l 10 -theme theme)

# 4. 如果用户没有选择（ESC 或取消），则退出
if [[ -z "$selected" ]]; then
    exit 0
fi

# 5. 获取对应的 URL
url="${SITE_URLS[$selected]}"
if [[ -z "$url" ]]; then
    echo "错误: 未找到 '$selected' 对应的 URL" >&2
    exit 1
fi

# 6. 检测浏览器是否已运行的函数
is_browser_running() {
    local browser_process="$1"
    pgrep -x "$browser_process" > /dev/null 2>&1
}

# 7. 智能打开网页函数
open_url() {
    local url="$1"
    local browser_cmd=""

    local brave_processes="brave-browser-stable brave-browser"
    local chrome_processes="google-chrome-stable google-chrome chrome chromium chromium-browser"
    local firefox_processes="firefox"

    local brave_running=false
    local chrome_running=false
    local firefox_running=false

    for proc in $brave_processes; do
        if is_browser_running "$proc"; then
            brave_running=true
            break
        fi
    done

    for proc in $chrome_processes; do
        if is_browser_running "$proc"; then
            chrome_running=true
            break
        fi
    done

    for proc in $firefox_processes; do
        if is_browser_running "$proc"; then
            firefox_running=true
            break
        fi
    done

    if $brave_running; then
        browser_cmd="brave --new-tab"
    elif $chrome_running; then
        browser_cmd="google-chrome-stable"
    elif $firefox_running; then
        browser_cmd="firefox --new-tab"
    else
        local default_browser=$(xdg-mime query default x-scheme-handler/https | cut -d '.' -f1)
        case "$default_browser" in
            brave-browser)
                browser_cmd="brave --new-tab"
                ;;
            google-chrome|chrome|chromium|chromium-browser)
                browser_cmd="$default_browser"
                ;;
            firefox)
                browser_cmd="firefox --new-tab"
                ;;
            *)
                browser_cmd="xdg-open"
                ;;
        esac
    fi

    if [[ "$browser_cmd" == *" "* ]]; then
        sh -c "$browser_cmd '$url'"
    else
        $browser_cmd "$url"
    fi
}

# 调用函数打开网页
open_url "$url"
#!/bin/bash
# 默认程序设置脚本 (Arch Linux)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

[[ "$EUID" -eq 0 ]] && { echo -e "${RED}请勿使用 root 运行${NC}"; exit 1; }

BROWSER="brave.desktop"
IMAGE="gpicview.desktop"
VIDEO="mpv.desktop"
AUDIO="mpv.desktop"
PDF="brave.desktop"
TEXT="code.desktop"

show_current() {
    echo -e "\n${CYAN}当前默认程序:${NC}"
    echo -e "  浏览器: ${YELLOW}$(xdg-mime query default x-scheme-handler/http 2>/dev/null || echo '未设置')${NC}"
    echo -e "  图片:   ${YELLOW}$(xdg-mime query default image/jpeg 2>/dev/null || echo '未设置')${NC}"
    echo -e "  视频:   ${YELLOW}$(xdg-mime query default video/mp4 2>/dev/null || echo '未设置')${NC}"
    echo -e "  音乐:   ${YELLOW}$(xdg-mime query default audio/mpeg 2>/dev/null || echo '未设置')${NC}"
    echo -e "  PDF:    ${YELLOW}$(xdg-mime query default application/pdf 2>/dev/null || echo '未设置')${NC}"
    echo -e "  文本:   ${YELLOW}$(xdg-mime query default text/plain 2>/dev/null || echo '未设置')${NC}"
}

apply() {
    echo -e "\n${GREEN}[设置中...]${NC}"

    xdg-mime default "$BROWSER" x-scheme-handler/http x-scheme-handler/https x-scheme-handler/ftp
    xdg-mime default "$IMAGE" image/jpeg image/png image/gif image/bmp image/webp
    xdg-mime default "$VIDEO" video/mp4 video/x-matroska video/webm video/avi video/quicktime video/x-msvideo video/x-flv video/3gpp video/mpeg
    xdg-mime default "$AUDIO" audio/mpeg audio/ogg audio/flac audio/wav
    xdg-mime default "$PDF" application/pdf
    xdg-mime default "$TEXT" \
        text/plain text/html text/css application/json \
        text/x-python text/x-csrc text/x-c++src text/x-java \
        text/x-go text/x-rust text/x-ruby text/x-php \
        text/x-shellscript text/x-lua text/x-sql text/x-perl \
        text/x-haskell text/x-elixir text/x-erlang text/x-csharp \
        text/x-swift text/x-kotlin text/x-scala text/x-r \
        text/markdown text/x-toml text/x-yaml text/x-ini \
        application/xml application/x-yaml

    echo -e "${GREEN}[完成]${NC}"
}

show_current
apply
show_current

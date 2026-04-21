#!/usr/bin/env bash

# 优先顺序: Brave APT > Brave Flatpak > Chrome > Firefox

set -e

BRAVE_APT="/usr/bin/brave-browser-stable"
BRAVE_FLATPAK_ID="com.brave.Browser"
CHROME_APT="/usr/bin/google-chrome-stable"
CHROME_FLATPAK_ID="com.google.Chrome"
FIREFOX_APT="/usr/bin/firefox"
FIREFOX_FLATPAK_ID="org.mozilla.firefox"

export LANGUAGE=zh_CN
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8

EXTRA_ARGS=(--unsafely-treat-insecure-origin-as-secure=http://10.10.10.6:8080/)

if [ -x "$BRAVE_APT" ]; then
    exec "$BRAVE_APT" "${EXTRA_ARGS[@]}" "$@"
fi

if command -v flatpak >/dev/null 2>&1 && flatpak info "${BRAVE_FLATPAK_ID}" >/dev/null 2>&1; then
    exec flatpak run "${BRAVE_FLATPAK_ID}" "${EXTRA_ARGS[@]}" "$@"
fi

if [ -x "$CHROME_APT" ]; then
    exec "$CHROME_APT" "${EXTRA_ARGS[@]}" "$@"
fi

if command -v flatpak >/dev/null 2>&1 && flatpak info "${CHROME_FLATPAK_ID}" >/dev/null 2>&1; then
    exec flatpak run "${CHROME_FLATPAK_ID}" "${EXTRA_ARGS[@]}" "$@"
fi

if [ -x "$FIREFOX_APT" ]; then
    exec "$FIREFOX_APT" "${EXTRA_ARGS[@]}" "$@"
fi

if command -v flatpak >/dev/null 2>&1 && flatpak info "${FIREFOX_FLATPAK_ID}" >/dev/null 2>&1; then
    exec flatpak run "${FIREFOX_FLATPAK_ID}" "${EXTRA_ARGS[@]}" "$@"
fi

notify-send "未找到浏览器" "未找到浏览器" || true
exit 1


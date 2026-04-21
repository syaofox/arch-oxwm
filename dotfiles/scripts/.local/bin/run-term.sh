#!/bin/sh

# 優先順序：wezterm → st → x-terminal-emulator

if command -v wezterm >/dev/null 2>&1; then
    exec wezterm "$@"
elif command -v st >/dev/null 2>&1; then
    exec st "$@"
elif command -v /usr/bin/x-terminal-emulator >/dev/null 2>&1; then
    exec /usr/bin/x-terminal-emulator "$@"
else
    # 真的都找不到時的最後手段（通常不會走到這裡）
    echo "Error: No terminal emulator found!" >&2
    exit 1
fi
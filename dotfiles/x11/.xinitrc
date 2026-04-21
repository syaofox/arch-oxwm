#!/bin/bash
# ============================================================
# OXWM 会话启动脚本 (Arch 版)
# ============================================================

# ---------- 辅助函数 ----------
log()    { echo "[$(date +'%H:%M:%S')] $*"; }
err()    { echo "[$(date +'%H:%M:%S')] ERROR: $*" >&2; }

# 安全等待服务就绪
wait_for_service() {
    local name="$1"; local check_cmd="$2"; local timeout="${3:-5}"
    for ((i=0; i<timeout; i++)); do
        if eval "$check_cmd" &>/dev/null; then
            return 0
        fi
        sleep 1
    done
    err "$name 启动超时 (${timeout}s)"
    return 1
}

# 将 X 环境导入 systemd 用户会话（关键）
systemctl --user import-environment DISPLAY XAUTHORITY 2>/dev/null || true

# ---------- 环境变量 ----------
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export PATH="$HOME/.local/bin:$PATH"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DISPLAY=:0
export XAUTHORITY=$HOME/.Xauthority

export QT_QPA_PLATFORMTHEME=gtk3
export _JAVA_AWT_WM_NONREPARENTING=1

export LANG=en_US.UTF-8
export XMODIFIERS=@im=fcitx
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export SDL_IM_MODULE=fcitx
export SESSION_MANAGER="${SESSION_MANAGER:-local/$(hostname):$$:oxwm}"
export TERMINAL=wezterm

# ---------- 会话锁（防止重复 startx） ----------
SESSION_LOCK="/tmp/oxwm-session-${USER}.lock"
if [ -f "$SESSION_LOCK" ]; then
    OLD_PID=$(cat "$SESSION_LOCK" 2>/dev/null)
    if kill -0 "$OLD_PID" 2>/dev/null; then
        log "终止残留 OXWM 会话 (PID: $OLD_PID)..."
        kill -TERM "$OLD_PID" 2>/dev/null || true
        sleep 1
        kill -KILL "$OLD_PID" 2>/dev/null || true
    fi
    rm -f "$SESSION_LOCK"
fi
echo $$ > "$SESSION_LOCK"
trap 'rm -f "$SESSION_LOCK"' EXIT


# 加载用户环境配置
[ -f "$HOME/.profile" ] && . "$HOME/.profile"




# ---------- 日志 ----------
LOGDIR="$HOME/.local/share/oxwm"
LOGFILE="$LOGDIR/oxwm.log"
mkdir -p "$LOGDIR"
[ -f "$LOGFILE" ] && [ "$(stat -c%s "$LOGFILE")" -gt 1048576 ] && mv "$LOGFILE" "$LOGFILE.old"
exec > >(tee -a "$LOGFILE") 2>&1
log "=== OXWM session starting (PID: $$) ==="

# ---------- 清理用户级残留进程 ----------
log "清理旧会话残留的用户进程..."
CLEANUP_LIST="picom dunst fcitx5 slstatus pasystray xfce4-clipman"
for proc in $CLEANUP_LIST; do
    pkill -x "$proc" 2>/dev/null || true
done
pkill -9 -f "dbus-launch" 2>/dev/null || true
sleep 1

# ---------- X 基础设置 ----------
xset -dpms &
xset s off &
xset s noblank &

# ---------- Xresources 主题 ----------
# nord tokyonight gruvbox mint-y-teal dwm 2b
THEME="nord"
if [ -f "$HOME/.Xresources.d/${THEME}" ]; then
   xrdb -merge "$HOME/.Xresources.d/${THEME}"
fi

# ---------- WezTerm 主题 ----------
ln -sf "$HOME/.config/wezterm/themes/${THEME}.lua" "$HOME/.config/wezterm/theme.lua" 2>/dev/null || true

# ---------- Rofi 主题 ----------
ln -sf "$HOME/.config/rofi/${THEME}.rasi" "$HOME/.config/rofi/theme.rasi" 2>/dev/null || true

# ---------- Dunst 主题 ----------
ln -sf "$HOME/.config/dunst/${THEME}" "$HOME/.config/dunst/dunstrc" 2>/dev/null || true

# ---------- Yazi 主题 ----------
ln -sf "$HOME/.config/yazi/themes/${THEME}.toml" "$HOME/.config/yazi/theme.toml" 2>/dev/null || true

# ---------- OXWM 主题 ----------
ln -sf "$HOME/.config/oxwm/themes/${THEME}.lua" "$HOME/.config/oxwm/colors.lua" 2>/dev/null || true

# ---------- 显示器设置 ----------
if command -v xrandr >/dev/null; then
    PRIMARY=$(xrandr --listmonitors 2>/dev/null | awk 'NR==2{print $4}' | cut -d+ -f1)
    if [ -n "$PRIMARY" ] && [ "$PRIMARY" != "Virtual-1" ]; then
        PREFERRED=$(xrandr --query 2>/dev/null | sed -n "/^$PRIMARY connected/,/^[^ ]/p" | grep '+' | head -1 | awk '{print $1}')
        [ -n "$PREFERRED" ] && xrandr --output "$PRIMARY" --mode "$PREFERRED" &
    fi
fi

# ---------- D-Bus 会话（强制新建） ----------
if command -v dbus-launch >/dev/null; then
    pkill -9 -f "dbus-launch" 2>/dev/null || true
    sleep 0.5
    eval "$(dbus-launch --sh-syntax --exit-with-session)"
    log "新建 D-Bus 会话: $DBUS_SESSION_BUS_ADDRESS"
fi

# ---------- 认证代理 (polkit-gnome) ----------
if command -v /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 >/dev/null && ! pgrep -x "polkit-gnome-aut" >/dev/null; then
    /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
fi

# ---------- 音频服务（由 systemd 管理） ----------
log "音频服务: $(pactl info 2>/dev/null | grep 'Server Name' | cut -d: -f2)"

# ---------- 辅助组件 ----------
log "启动辅助组件..."

# 合成器
picom --config "$HOME/.config/picom/picom.conf" -b &

# 通知守护进程
dunst -conf "$HOME/.config/dunst/dunstrc" &

# 壁纸 
if command -v xwallpaper >/dev/null; then
    xwallpaper --zoom "$HOME/.config/walls/black-nord.png" &
fi

# # 状态栏
# slstatus &

# # 网络托盘图标 (NetworkManager)
# nm-applet --indicator &

# # 音量托盘图标
# pasystray &

# 剪贴板历史
xfce4-clipman &

# 更新用户目录（桌面、下载等）
xdg-user-dirs-update &

# ---------- 输入法 ----------
fcitx5 -d &
sleep 1

# ---------- 启动 OXWM ----------
log "所有组件就绪，启动 OXWM..."
exec oxwm

#!/bin/bash
# Arch Linux DWM Installer (Pure Bash Version)
# Run as normal user, uses sudo only when needed

set -uo pipefail

# ----------------------------------------------------------------------
# 颜色输出
# ----------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "\n${CYAN}==> $1${NC}"; }

# ----------------------------------------------------------------------
# 日志系统
# ----------------------------------------------------------------------
if [[ -z "${DWM_INSTALL_LOG:-}" ]]; then
    export DWM_INSTALL_LOG=1
    LOG_DIR="$HOME/.dwm_install_logs"
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/install_$(date +%Y%m%d_%H%M%S).log"

    clean_for_log() {
        sed 's/\x1b\[[0-9;]*m//g; s/\x1b(B//g; s/\x1b\[[0-9;]*[A-Za-z]//g; s/\r/\n/g'
    }

    exec > >(tee /dev/tty | clean_for_log >> "$LOG_FILE") 2>&1

    echo "=========================================="
    echo "DWM Installation Log (plain text)"
    echo "Log file: $LOG_FILE"
    echo "=========================================="
fi

finish_log() {
    echo -e "\n[INFO] Full log (plain text) saved to: $LOG_FILE"
}
trap finish_log EXIT

# 清理函数
cleanup() {
    log_info "Cleaning up temporary files..."
    local dir
    for dir in "${TEMP_DIRS[@]}"; do
        rm -rf "/tmp/$dir" 2>/dev/null || true
    done
    rm -f /tmp/JetBrainsMono.tar.xz 2>/dev/null || true
}
trap cleanup INT TERM

# ----------------------------------------------------------------------
# 全局变量
# ----------------------------------------------------------------------
SELECTIVE_MODE=false
INTERACTIVE_MODE=true
DOTFILES_PACKAGES=(oxwm scripts dunst picom rofi nemo x11 fontconfig wezterm yazi bashrc)
TEMP_DIRS=(oxwm bulky)

[[ "$EUID" -eq 0 ]] && { echo -e "${RED}Do not run this script as root${NC}"; exit 1; }

REAL_USER="$(whoami)"
USER_HOME="$HOME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

STATE_FILE="$HOME/.oxwm_install_state"
declare -A STEP_STATUS

if [[ -f "$STATE_FILE" ]]; then
    while IFS='=' read -r key value; do
        STEP_STATUS["$key"]="$value"
    done < "$STATE_FILE"
fi

save_state() {
    > "$STATE_FILE"
    for key in "${!STEP_STATUS[@]}"; do
        echo "$key=${STEP_STATUS[$key]}" >> "$STATE_FILE"
    done
}

reset_state() {
    log_info "Resetting all step states..."
    STEP_STATUS=()
    rm -f "$STATE_FILE"
    log_info "State reset, full installation will be performed"
}

check_project_structure() {
    local missing=()
    [[ ! -d "$PROJECT_DIR/dotfiles" ]] && missing+=("dotfiles")
    [[ ! -d "$PROJECT_DIR/walls" ]] && missing+=("walls")
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Project missing required directories/files: ${missing[*]}"
        echo -e "\nProject structure error. The following required items are missing:"
        echo "  ${missing[*]}"
        echo ""
        echo "Please ensure the full project is downloaded."
        read -p "Press Enter to exit..."
        exit 1
    fi
}

# 简单的 yes/no 交互
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local yn
    while true; do
        if [[ "$default" == "y" ]]; then
            read -p "$prompt [Y/n]: " yn
        else
            read -p "$prompt [y/N]: " yn
        fi
        yn=${yn:-$default}
        case $yn in
            y|Y) return 0 ;;
            n|N) return 1 ;;
        esac
    done
}

# 显示步骤列表供选择
select_steps() {
    for ((i=0; i<TOTAL_STEPS; i++)); do
        local status="[ ]"
        if [[ "${STEP_STATUS[$i]:-pending}" == "done" ]]; then
            status="[x]"
        fi
        printf "%2d %s %s\n" "$i" "$status" "${STEP_NAMES[$i]}"
    done
}

clone_with_retry() {
    local repo="$1" dest="$2"
    
    # 确保目标目录的父目录存在并且可访问
    local dest_parent=$(dirname "$dest")
    if [[ ! -d "$dest_parent" ]]; then
        mkdir -p "$dest_parent" || return 1
    fi
    
    # 如果目标目录已存在，先删除
    if [[ -d "$dest" ]]; then
        log_info "Removing existing directory: $dest"
        rm -rf "$dest"
    fi
    
    # 切换到安全的工作目录
    local old_pwd="$PWD"
    cd /tmp || return 1
    
    for i in {1..3}; do
        log_info "Cloning $repo (attempt $i/3)..."
        if git clone --depth 1 "$repo" "$dest" 2>&1; then
            cd "$old_pwd"
            return 0
        fi
        log_warn "Clone failed, retry ${i}/3..."
        sleep 2
        # 清理失败的克隆尝试
        rm -rf "$dest" 2>/dev/null || true
    done
    
    cd "$old_pwd"
    log_error "Failed to clone $repo after 3 attempts"
    return 1
}

# ============================================================
# 步骤函数定义
# ============================================================

step_locale() {
    log_step "1/10 Enable Chinese locale (zh_CN.UTF-8)..."

    local LOCALE_GEN="/etc/locale.gen"

    if [[ ! -f "$LOCALE_GEN" ]]; then
        log_error "locale.gen not found: $LOCALE_GEN"
        return 1
    fi

    if grep -q "^#.*zh_CN.UTF-8 UTF-8" "$LOCALE_GEN"; then
        sudo sed -i 's/^#.*zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' "$LOCALE_GEN"
        log_info "Enabled zh_CN.UTF-8 in locale.gen"
    elif grep -q "^zh_CN.UTF-8 UTF-8" "$LOCALE_GEN"; then
        log_info "zh_CN.UTF-8 already enabled in locale.gen"
    fi

    log_info "Generating locales..."
    sudo locale-gen || return 1

    log_info "Setting system locale to English (keep UI in English)..."
    echo "LANG=en_US.UTF-8" | sudo tee /etc/locale.conf > /dev/null

    log_info "Chinese locale enabled, system stays in English"
    return 0
}

step_deps() {
    log_step "2/10 Install system dependencies (Arch Linux)..."

    # 确保系统已更新
    log_info "Updating system package database..."
    sudo pacman -Sy --noconfirm || return 1

    # 安装 paru (AUR helper) 如果尚未安装
    if ! command -v paru >/dev/null; then
        log_info "Installing paru (AUR helper)..."
        local old_pwd="$PWD"
        cd /tmp || return 1
        sudo pacman -S --needed --noconfirm base-devel git || return 1
        git clone https://aur.archlinux.org/paru.git
        cd paru || return 1
        makepkg -si --noconfirm || return 1
        cd "$old_pwd"
        rm -rf /tmp/paru
    fi

    local pacman_packages=(
        # X11/桌面环境基础
        xorg-server xorg-xinit xorg-xrandr xorg-xsetroot xorg-xrdb
        xdotool dbus libnotify

        # 构建工具
        base-devel cmake meson ninja curl wget pkg-config
        zig libx11 libxft freetype2 fontconfig libxinerama

        # 系统工具
        btrfs-progs nvim git rsync

        # 桌面组件
        dunst lxappearance network-manager-applet polkit-gnome

        # 启动器/工具
        rofi rofi-calc qalculate-gtk maim xclip xsel xfce4-clipman-plugin xwallpaper picom

        # 配置管理
        xdg-user-dirs dconf fastfetch zenity

        # 终端/文件管理
        wezterm htop timeshift mpv gpicview bash-completion trash-cli
        # pasystray

        # 音频
        pavucontrol pamixer pipewire pipewire-pulse pipewire-alsa pipewire-jack

        # 中文输入法
        fcitx5 fcitx5-chinese-addons fcitx5-gtk fcitx5-qt fcitx5-configtool fcitx5-material-color

        # 字体
        noto-fonts-cjk wqy-zenhei ttf-jetbrains-mono-nerd terminus-font noto-fonts-emoji

        # 文件管理器
        nemo nemo-fileroller ffmpegthumbnailer tumbler bulky

        # 网络/存储
        gvfs mtools smbclient cifs-utils unzip udisks2 nfs-utils

        # Qt 配置
        qt5ct qt6ct

        # CLI 工具
        yazi ffmpeg 7zip jq poppler fd ripgrep fzf zoxide resvg imagemagick
    )

    log_info "Installing official packages..."
    if ! sudo pacman -S --needed --noconfirm "${pacman_packages[@]}"; then
        log_error "Failed to install some official packages"
        return 1
    fi

    log_info "System dependencies installation complete"
    return 0
}

step_flathub() {
    log_step "3/10 Configure Flathub..."

    if ! command -v flatpak >/dev/null; then
        log_info "Installing flatpak..."
        sudo pacman -S --needed --noconfirm flatpak || return 1
    fi

    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || log_warn "Flathub configuration failed (may already exist)"

    log_info "Setting flatpak theme access..."
    flatpak override --user --filesystem=~/.themes:ro
    flatpak override --user --filesystem=~/.icons:ro
    flatpak override --user --env=GTK_THEME=Mint-Y-Teal

    log_info "Flathub configuration complete"
    return 0
}

step_network_config() {
    log_step "4/10 Configure NetworkManager..."

    # 启用并启动 NetworkManager 服务
    log_info "Enabling and starting NetworkManager..."
    sudo systemctl enable NetworkManager --now

    local NM_CONF="/etc/NetworkManager/NetworkManager.conf"

    # 备份原配置文件（如果存在）
    if [[ -f "$NM_CONF" ]]; then
        sudo cp "$NM_CONF" "${NM_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
        log_info "Backed up existing NetworkManager.conf"
    fi

    # 确保 [main] 段存在
    if ! grep -q "^\[main\]" "$NM_CONF" 2>/dev/null; then
        echo "[main]" | sudo tee -a "$NM_CONF" > /dev/null
        echo "plugins=ifupdown,keyfile" | sudo tee -a "$NM_CONF" > /dev/null
    fi

    # 关键修复：确保 [ifupdown] 段中 managed=true
    if grep -q "^\[ifupdown\]" "$NM_CONF" 2>/dev/null; then
        # 如果 [ifupdown] 存在但 managed 不为 true，则修改
        if ! grep -q "^managed=true" "$NM_CONF" 2>/dev/null; then
            sudo sed -i '/^\[ifupdown\]/,/^\[/ s/^managed=.*/managed=true/' "$NM_CONF"
            # 如果替换失败（可能没有 managed= 行），则追加
            if ! grep -q "^managed=true" "$NM_CONF"; then
                sudo sed -i '/^\[ifupdown\]/a managed=true' "$NM_CONF"
            fi
            log_info "Set managed=true in [ifupdown] section"
        fi
    else
        # 没有 [ifupdown] 段，则添加
        echo "" | sudo tee -a "$NM_CONF" > /dev/null
        echo "[ifupdown]" | sudo tee -a "$NM_CONF" > /dev/null
        echo "managed=true" | sudo tee -a "$NM_CONF" > /dev/null
        log_info "Added [ifupdown] section with managed=true"
    fi

    # 确保 [device] 段存在（用于漫游扫描，非必须但保持兼容）
    if ! grep -q "^\[device\]" "$NM_CONF" 2>/dev/null; then
        echo "" | sudo tee -a "$NM_CONF" > /dev/null
        echo "[device]" | sudo tee -a "$NM_CONF" > /dev/null
        echo "scan-roaming=no" | sudo tee -a "$NM_CONF" > /dev/null
        log_info "Added [device] section"
    fi

    # 设置以太网设备为托管模式（确保 nmcli 接管）
    local DEVICES=$(ls /sys/class/net/ 2>/dev/null | grep -E "^(eth|enp|ens|eno|enx)" || true)
    if [[ -n "$DEVICES" ]]; then
        log_info "Setting ethernet devices to managed mode..."
        for dev in $DEVICES; do
            sudo nmcli device set "$dev" managed yes 2>/dev/null || true
            log_info "  $dev -> managed"
        done
    fi

    # 重启 NetworkManager 服务
    log_info "Restarting NetworkManager..."
    sudo systemctl restart NetworkManager
    sleep 2

    # 显示当前网络设备状态（调试用）
    log_info "Network devices status:"
    nmcli device | head -10

    log_info "NetworkManager configuration complete (managed=true set)"
    return 0
}

step_oxwm() {
    log_step "5/10 Compile and install owxm..."
    local OXWM_REPO="https://github.com/syaofox/oxwm.git"
    local OXWM_SRC="/tmp/oxwm"

    if [[ -d "$OXWM_SRC/.git" ]]; then
        log_warn "OXWM 源码已存在，执行 git pull..."
        if ! git -C "$OXWM_SRC" pull; then
            log_error "OXWM git pull 失败"
            return 1
        fi
    else
        log_info "克隆 OXWM 仓库..."
        if ! git clone "$OXWM_REPO" "$OXWM_SRC"; then
            log_error "OXWM 克隆失败"
            return 1
        fi
    fi

    (
        cd "$OXWM_SRC" || { log_error "无法进入 $OXWM_SRC"; return 1; }

        log_info "构建 OXWM (ReleaseSmall)..."
        if ! zig build -Doptimize=ReleaseSmall; then
            log_error "OXWM 构建失败"
            return 1
        fi

        log_info "安装 OXWM 到 /usr..."
        if ! sudo zig build -Doptimize=ReleaseSmall --prefix /usr install; then
            log_error "OXWM 安装失败"
            return 1
        fi
    ) || return 1

    log_info "OXWM 安装完成"
    return 0
}



create_symlink() {
    local src="$1" dst="$2"
    local src_dir
    src_dir="$(dirname "$dst")"
    mkdir -p "$src_dir"

    if [[ -L "$dst" ]]; then
        local existing_target
        existing_target="$(readlink -f "$dst" 2>/dev/null || true)"
        if [[ "$existing_target" == "$src" ]]; then
            return 0
        fi
        log_warn "  Overwriting old symlink: $dst"
        rm -f "$dst"
    elif [[ -e "$dst" ]]; then
        local basename
        basename="$(basename "$dst")"
        log_warn "  Backing up existing file: $basename"
        cp -a "$dst" "${dst}.bak.$(date +%Y%m%d%H%M%S)"
        rm -f "$dst"
    fi

    ln -sf "$src" "$dst"
}

stow_package() {
    local pkg="$1"
    local pkg_dir="$PROJECT_DIR/dotfiles/$pkg"
    [[ ! -d "$pkg_dir" ]] && { log_error "Package directory does not exist: $pkg_dir"; return 1; }

    log_info "Deploying $pkg ..."
    while IFS= read -r rel_path; do
        rel_path="${rel_path#./}"
        local target="$USER_HOME/$rel_path"
        create_symlink "$PROJECT_DIR/dotfiles/$pkg/$rel_path" "$target"
    done < <(cd "$pkg_dir" && find . -type f -o -type l | grep -v '^\./\.git' | grep -v '^\./\.svn')

    find "$pkg_dir" -name "*.sh" -type f -exec chmod +x {} \;
    return 0
}

step_dotfiles() {
    log_step "6/10 Deploy configuration files (stow symlink)..."

    local pkg
    for pkg in "${DOTFILES_PACKAGES[@]}"; do
        [[ "$pkg" == "bashrc" ]] && continue
        stow_package "$pkg" || return 1
    done

log_info "Refreshing font cache..."
    fc-cache -fv "$HOME/.config/fontconfig" 2>/dev/null || true

    log_info "Setting wezterm as default terminal for Nemo..."
    gsettings set org.cinnamon.desktop.default-applications.terminal exec wezterm 2>/dev/null || true

    return 0
}

step_bashrc() {
    log_step "7/10 Configure Bash environment..."

    stow_package "bashrc" || return 1

    local BASHRC="$USER_HOME/.bashrc"
    local need_bashrc_entry=false
    if [[ ! -f "$BASHRC" ]]; then
        need_bashrc_entry=true
    else
        if ! grep -q '~/.bashrc.d' "$BASHRC" 2>/dev/null; then
            need_bashrc_entry=true
        fi
    fi

    if [[ "$need_bashrc_entry" == "true" ]]; then
        cat >> "$BASHRC" << 'EOF'

# Load all .sh files from ~/.bashrc.d/
if [ -d "$HOME/.bashrc.d" ]; then
    for file in "$HOME/.bashrc.d"/*.sh; do
        [ -r "$file" ] && source "$file"
    done
    unset file
fi
EOF
        log_info "Added ~/.bashrc.d loading code"
    else
        log_info "~/.bashrc already contains ~/.bashrc.d loading code"
    fi

    log_info "Bash environment configuration completed"
    return 0
}

step_desktop() {
    log_step "8/10 Configure startx startup method..."
    local XINITRC_SRC="$PROJECT_DIR/dotfiles/x11/.xinitrc"
    local XINITRC_DST="$USER_HOME/.xinitrc"

    if [[ ! -f "$XINITRC_SRC" ]]; then
        log_error "xinitrc source file missing: $XINITRC_SRC"
        return 1
    fi

    cp -f "$XINITRC_SRC" "$XINITRC_DST"
    chmod +x "$XINITRC_DST"

    # 禁用任何可能存在的 DM
    for dm in lightdm gdm sddm lxdm; do
        if systemctl is-active --quiet "$dm" 2>/dev/null; then
            sudo systemctl disable "$dm" 2>/dev/null && log_info "Disabled $dm"
            sudo systemctl mask "$dm" 2>/dev/null
        fi
    done

    log_info "startx configuration complete"
    return 0
}

step_wallpaper() {
    log_step "9/10 Deploy wallpaper files (symlink)..."
    local WALLPAPER_DIR="$USER_HOME/.config/walls"
    mkdir -p "$(dirname "$WALLPAPER_DIR")"

    if [[ ! -d "$PROJECT_DIR/walls" ]]; then
        log_warn "walls directory missing, skipping wallpaper deployment"
        return 2
    fi

    local count=0
    while IFS= read -r rel_path; do
        local wallpaper
        wallpaper="$(basename "$rel_path")"
        create_symlink "$PROJECT_DIR/walls/$wallpaper" "$WALLPAPER_DIR/$wallpaper"
        ((count++))
    done < <(find "$PROJECT_DIR/walls" -maxdepth 1 -type f ! -name ".*")

    if [[ $count -eq 0 ]]; then
        log_warn "No wallpaper files found in walls directory, skipping"
        return 2
    fi

    log_info "Deployed $count wallpapers to $WALLPAPER_DIR"
    return 0
}

step_autologin() {
    log_step "10/10 Configure TTY auto-login..."

    local CURRENT_USER="$REAL_USER"
    local AUTOLOGIN_DIR="/etc/systemd/system/getty@tty1.service.d"
    local AUTOLOGIN_CONF="$AUTOLOGIN_DIR/autologin.conf"

    log_info "Configuring TTY1 auto-login..."
    if [[ ! -f "$AUTOLOGIN_CONF" ]]; then
        sudo mkdir -p "$AUTOLOGIN_DIR"
        sudo tee "$AUTOLOGIN_CONF" > /dev/null << EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $CURRENT_USER --noclear %I \$TERM
EOF
        log_info "TTY1 auto-login configured"
    else
        log_info "Auto-login already configured, skipping"
    fi

    log_info "Creating password verification script..."
    local BIN_DIR="$HOME/.local/bin"
    local SCRIPT_PATH="$BIN_DIR/tty-lock-and-startx.sh"
    mkdir -p "$BIN_DIR"

    cat > "$SCRIPT_PATH" << 'EOF'
#!/bin/bash
MAX_ATTEMPTS=3
ATTEMPT=0

get_password_hash() {
    sudo cat /etc/shadow 2>/dev/null | grep "^$USER:" | cut -d: -f2
}

echo "----------------------------------------"
echo "  Welcome, $USER"
echo "  Please enter your password to start DWM"
echo "----------------------------------------"

PASSWD_HASH=$(get_password_hash)

if [ -z "$PASSWD_HASH" ]; then
    echo "WARNING: Cannot read password hash. Proceeding without verification."
    exec startx
fi

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    read -s -p "Password: " INPUT_PW
    echo
    if echo "$INPUT_PW" | su - "$USER" -c "exit" 2>/dev/null; then
        echo "Login successful. Starting DWM..."
        exec startx
    else
        echo "Login incorrect."
        ATTEMPT=$((ATTEMPT + 1))
        if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
            echo "Attempts left: $((MAX_ATTEMPTS - ATTEMPT))"
        fi
    fi
done

echo "Too many failed attempts. Returning to shell."
exit 1
EOF
    chmod +x "$SCRIPT_PATH"
    log_info "Password verification script created: $SCRIPT_PATH"

    log_info "Configuring ~/.bash_profile..."
    local BASH_PROFILE="$HOME/.bash_profile"
    if ! grep -q "tty-lock-and-startx.sh" "$BASH_PROFILE" 2>/dev/null; then
        cat >> "$BASH_PROFILE" << 'EOF'

if [ -z "${DISPLAY}" ] && [ "${XDG_VTNR}" -eq 1 ]; then
if [ -f "$HOME/.local/bin/tty-lock-and-startx.sh" ]; then
            exec "$HOME/.local/bin/tty-lock-and-startx.sh"
    fi
fi
EOF
        log_info "Added startup entry to ~/.bash_profile"
    else
        log_info "~/.bash_profile already configured"
    fi

    log_info "Configuring sudo for passwordless shadow read..."
    local SUDOERS_FILE="/etc/sudoers.d/tty-lock-startx-$CURRENT_USER"
    local SUDOERS_ENTRY="$CURRENT_USER ALL=(ALL) NOPASSWD: /bin/cat /etc/shadow"

    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        echo ""
        echo "The script needs sudo to read /etc/shadow for password verification."
        echo "Choose:"
        echo "  1) Auto-configure passwordless sudo (recommended)"
        echo "  2) Manual config"
        echo "  3) Skip (password verification may fail)"
        echo ""

        local choice
        read -p "Choose [1/2/3]: " choice

        case $choice in
            1)
                if [[ ! -f "$SUDOERS_FILE" ]]; then
                    echo "$SUDOERS_ENTRY" | sudo tee "$SUDOERS_FILE" > /dev/null
                    sudo chmod 0440 "$SUDOERS_FILE"
                    log_info "Passwordless sudo rule added"
                else
                    log_info "sudoers file already exists, skipping"
                fi
                ;;
            2)
                log_info "Please manually run: sudo visudo -f $SUDOERS_FILE"
                ;;
            3)
                log_warn "Skipping sudo config"
                ;;
        esac
    else
        if [[ ! -f "$SUDOERS_FILE" ]]; then
            echo "$SUDOERS_ENTRY" | sudo tee "$SUDOERS_FILE" > /dev/null
            sudo chmod 0440 "$SUDOERS_FILE"
            log_info "Passwordless sudo rule added (auto mode)"
        else
            log_info "sudoers file already exists, skipping"
        fi
    fi

    log_info "Auto-login configuration complete"
    return 0
}

# ============================================================
# 步骤元数据
# ============================================================
STEP_FUNCS=(
    step_locale
    step_deps
    step_flathub
    step_network_config
    step_oxwm
    step_dotfiles
    step_bashrc
    step_desktop
    step_wallpaper
    step_autologin
)
STEP_NAMES=(
    "Enable Chinese locale (zh_CN.UTF-8)"
    "Install system dependencies"
    "Configure Flathub"
    "Configure NetworkManager"
    "Compile and install oxwm"
    "Compile and install slstatus"
    "Compile and install slock"
    "Deploy configuration files"
    "Configure Bash environment"
    "Configure startx startup"
    "Deploy wallpaper files"
    "Configure TTY auto-login"
)
TOTAL_STEPS=${#STEP_FUNCS[@]}

# ============================================================
# 执行单个步骤
# ============================================================
run_step() {
    local idx=$1
    local name="${STEP_NAMES[$idx]}"
    local func="${STEP_FUNCS[$idx]}"

    # 检查是否已完成（仅在非强制模式且非选择性安装时跳过）
    if [[ "$SELECTIVE_MODE" != "true" ]] && [[ "${STEP_STATUS[$idx]:-pending}" == "done" ]]; then
        log_info "Step $((idx+1))/$TOTAL_STEPS ($name) already completed, skipping"
        return 0
    fi

    while true; do
        echo ""
        log_info "Running: $name ..."
        $func
        local ret=$?
        
        case $ret in
            0)
                # 仅在非选择性模式下标记为完成
                if [[ "$SELECTIVE_MODE" != "true" ]]; then
                    STEP_STATUS[$idx]="done"
                    save_state
                fi
                echo ""
                log_info "Step $((idx+1))/$TOTAL_STEPS: $name completed successfully"
                return 0
                ;;
            2)
                echo ""
                log_warn "Step $((idx+1))/$TOTAL_STEPS: $name skipped"
                # 仅在非选择性模式下标记为完成
                if [[ "$SELECTIVE_MODE" != "true" ]]; then
                    STEP_STATUS[$idx]="done"
                    save_state
                fi
                return 0
                ;;
            *)
                echo ""
                log_error "Step $((idx+1))/$TOTAL_STEPS: $name failed!"
                echo ""
                echo "Please check the terminal output for detailed error messages."
                echo "Full log is available at: $LOG_FILE"
                echo ""
                if confirm "Retry this step?" "y"; then
                    continue
                else
                    return 1
                fi
                ;;
        esac
    done
}

# ============================================================
# 主菜单
# ============================================================
main_menu() {
    while true; do
        echo ""
        echo "=============================================="
        echo "       DWM Installation Wizard (Arch Linux)"
        echo "=============================================="
        echo ""
        echo "Please select an operation mode:"
        echo ""
        echo "  1) Full installation (execute all steps in order)"
        echo "  2) Selective installation (run only selected steps)"
        echo "  3) Redeploy dotfiles and wallpapers"
        echo "  4) Exit"
        echo ""
        read -p "Enter your choice [1-4]: " opt
        echo ""

        case $opt in
            1) full_install ;;
            2) selective_install ;;
            3) redeploy_dotfiles ;;
            4) exit 0 ;;
            *) log_error "Invalid choice, please enter 1-4" ;;
        esac
    done
}

full_install() {
    log_info "Starting full installation..."
    SELECTIVE_MODE=false
    INTERACTIVE_MODE=false
    
    for ((i=0; i<TOTAL_STEPS; i++)); do
        run_step $i || { log_error "Installation interrupted at step $((i+1))"; exit 1; }
    done

    echo ""
    echo "=============================================="
    echo "       Installation Complete!"
    echo "=============================================="
    echo ""
    echo "All steps completed successfully!"
    echo ""
    echo "* Wallpapers symlinked to ~/.config/walls/"
    echo "* File manager: Nemo"
    echo "* To switch TTY: Ctrl+Alt+F1~F6"
    echo "* To exit DWM: pkill dwm or Mod+Shift+Q"
    echo "* Config files are symlinks; after modifying project files, run:"
    echo "  bash install.sh --redeploy-dotfiles"
    echo ""
    echo "IMPORTANT: Please reboot your system for display manager changes to take effect."
    echo "After reboot, if auto-login is configured, DWM will start automatically;"
    echo "otherwise, log in on TTY1 and run startx manually."
    echo ""
    echo "Full log saved to: $LOG_FILE"
}

selective_install() {
    echo "Available steps:"
    echo ""
    select_steps
    echo ""
    echo "Enter step numbers to execute (separated by spaces, e.g.: 0 2 4)"
    echo "Or press Enter to cancel"
    echo ""
    read -p "Selection: " selection

    if [[ -z "$selection" ]]; then
        log_info "No steps selected"
        return 0
    fi

    local selected=()
    for c in $selection; do
        if [[ "$c" =~ ^[0-9]+$ ]] && [[ "$c" -ge 0 ]] && [[ "$c" -lt "$TOTAL_STEPS" ]]; then
            selected+=("$c")
        fi
    done

    if [[ ${#selected[@]} -eq 0 ]]; then
        log_error "No valid steps selected"
        return 0
    fi

    # 设置选择性安装模式
    SELECTIVE_MODE=true
    
    # 按顺序执行选中的步骤（去重）
    local sorted_unique=($(printf '%s\n' "${selected[@]}" | sort -nu))
    
    for idx in "${sorted_unique[@]}"; do
        if [[ "${STEP_STATUS[$idx]:-pending}" == "done" ]]; then
            unset STEP_STATUS[$idx]
            save_state
        fi
        
        if ! run_step "$idx"; then
            log_error "Step ${STEP_NAMES[$idx]} failed"
            if ! confirm "Continue with remaining steps?" "n"; then
                log_info "Installation cancelled by user"
                SELECTIVE_MODE=false
                return 1
            fi
        fi
    done
    
    # 恢复模式
    SELECTIVE_MODE=false

    echo ""
    log_info "Selected steps have been executed"
}



redeploy_dotfiles() {
    log_step "Redeploy dotfiles (stow symlink)..."
    local pkg
    for pkg in "${DOTFILES_PACKAGES[@]}"; do
        if stow_package "$pkg"; then
            log_info "  $pkg: done"
        else
            log_error "  $pkg: failed"
        fi
    done
    step_bashrc || true
    step_wallpaper || true

    log_info "Setting default applications..."
    xdg-mime default brave.desktop x-scheme-handler/http x-scheme-handler/https x-scheme-handler/ftp
    xdg-mime default gpicview.desktop image/jpeg image/png image/gif image/bmp image/webp
    xdg-mime default mpv.desktop video/mp4 video/x-matroska video/webm video/avi video/quicktime video/x-msvideo video/x-flv video/3gpp video/mpeg
    xdg-mime default mpv.desktop audio/mpeg audio/ogg audio/flac audio/wav
    xdg-mime default brave.desktop application/pdf
    xdg-mime default code.desktop text/plain text/html text/css application/json text/x-python text/x-csrc text/x-c++src text/x-java text/x-go text/x-rust text/x-ruby text/x-php text/x-shellscript text/x-lua text/x-sql text/x-perl text/x-haskell text/x-elixir text/x-erlang text/x-csharp text/x-swift text/x-kotlin text/x-scala text/r text/markdown text/x-toml text/x-yaml text/x-ini application/xml application/x-yaml
    xdg-mime default wezterm.desktop x-scheme-handler/terminal application/x-terminal

    log_info "Refreshing font cache..."
    fc-cache -fv "$HOME/.config/fontconfig" 2>/dev/null || true

    echo ""
    log_info "Dotfiles redeployed"
    exit 0
}

# ============================================================
# 入口
# ============================================================

if [[ "${1:-}" == "--redeploy-dotfiles" ]]; then
    redeploy_dotfiles
    exit 0
fi

check_project_structure

# for cmd in git make wget xz; do
#     if ! command -v $cmd &>/dev/null; then
#         log_error "$cmd not installed, please install it first: sudo pacman -S $cmd"
#         exit 1
#     fi
# done

main_menu
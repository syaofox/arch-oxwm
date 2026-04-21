#!/bin/bash
# 主题安装脚本 - 为 DWM 环境安装 GTK 主题和图标 (Arch Linux 适配版)
# 支持: Mint-Y / Nordic 主题 + lxappearance 配置工具

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "\n${CYAN}==> $1${NC}"; }

[[ "$EUID" -eq 0 ]] && { echo -e "${RED}请勿使用 root 运行此脚本${NC}"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="/tmp/mint-theme-install-$(date +%s)"
mkdir -p "$WORK_DIR"
trap "rm -rf '$WORK_DIR'" EXIT

# -------------------- 辅助交互函数 --------------------
press_enter() {
    echo ""
    read -p "按回车键继续..."
}

yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local ans
    while true; do
        if [[ "$default" == "y" ]]; then
            read -p "$prompt [Y/n]: " ans
        else
            read -p "$prompt [y/N]: " ans
        fi
        ans=${ans:-$default}
        case "$ans" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "请输入 y 或 n" ;;
        esac
    done
}

# 多选菜单（逗号分隔编号或 all）
select_items() {
    local title="$1"
    shift
    local items=("$@")
    
    echo ""
    echo "========================================"
    echo "  $title"
    echo "========================================"
    for i in "${!items[@]}"; do
        printf "  %2d) %s\n" $((i+1)) "${items[$i]}"
    done
    echo "----------------------------------------"
    echo "  输入编号选择 (多个用逗号分隔，如 1,3,4)，输入 'all' 全选，直接回车取消"
    echo "----------------------------------------"
    read -p "你的选择: " choice
    
    if [[ -z "$choice" ]]; then
        return 1
    fi
    
    if [[ "$choice" == "all" ]]; then
        for ((i=0; i<${#items[@]}; i++)); do
            echo "$((i+1))"
        done
        return 0
    fi
    
    echo "$choice" | tr ',' '\n' | while read -r num; do
        num=$(echo "$num" | xargs)
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#items[@]} ]; then
            echo "$num"
        fi
    done
}

# -------------------- 安装函数 --------------------
install_mint_themes_from_tarball() {
    log_step "安装 Mint-Y 主题 (系统级)..."

    local tarball="$SCRIPT_DIR/themes/mint-themes.tar.gz"
    if [[ ! -f "$tarball" ]]; then
        log_error "主题包不存在: $tarball"
        return 1
    fi

    sudo mkdir -p /usr/share/themes
    sudo tar -xzf "$tarball" -C /usr/share/themes/
    sudo fc-cache -f -v /usr/share/themes 2>/dev/null || true
    log_info "Mint-Y 主题安装完成"
}

install_mint_icons_from_aur() {
    log_step "安装 Mint-Y 图标 (从 AUR)..."

    # 确保 paru 可用
    if ! command -v paru &>/dev/null; then
        log_error "未找到 paru，请先安装 AUR helper"
        return 1
    fi

    paru -S --noconfirm mint-y-icons || {
        log_error "Mint-Y 图标安装失败"
        return 1
    }
    fc-cache -f -v "$HOME/.local/share/icons" 2>/dev/null || true
    log_info "Mint-Y 图标安装完成"
}

install_nordic_icons_from_tarball() {
    log_step "安装 Nordic 图标 (系统级)..."

    local tarball="$SCRIPT_DIR/icons/Nordzy.tar.gz"
    if [[ ! -f "$tarball" ]]; then
        log_error "图标包不存在: $tarball"
        return 1
    fi

    sudo mkdir -p /usr/share/icons
    sudo tar -xzf "$tarball" -C /usr/share/icons/
    sudo fc-cache -f -v /usr/share/icons 2>/dev/null || true
    log_info "Nordic 图标安装完成"
}

install_nordic_themes_from_tarball() {
    log_step "安装 Nordic 主题 (系统级)..."

    local tarball="$SCRIPT_DIR/themes/Nordic-v40.tar.xz"
    if [[ ! -f "$tarball" ]]; then
        log_error "主题包不存在: $tarball"
        return 1
    fi

    sudo mkdir -p /usr/share/themes
    sudo tar -xJf "$tarball" -C /usr/share/themes/
    sudo fc-cache -f -v /usr/share/themes 2>/dev/null || true
    log_info "Nordic 主题安装完成"
}

install_lxappearance() {
    log_step "安装 lxappearance..."

    if command -v lxappearance &>/dev/null; then
        log_warn "lxappearance 已安装, 跳过"
        return
    fi

    sudo pacman -S --noconfirm lxappearance || {
        log_error "lxappearance 安装失败"
        return 1
    }
    log_info "lxappearance 安装完成"
}

# -------------------- GTK 配置相关 --------------------
get_available_themes() {
    local themes=()
    if [[ -d /usr/share/themes ]]; then
        for dir in /usr/share/themes/*; do
            [[ -d "$dir" ]] && themes+=("$(basename "$dir")")
        done
    fi
    if [[ -d "$HOME/.local/share/themes" ]]; then
        for dir in "$HOME/.local/share/themes"/*; do
            [[ -d "$dir" ]] && themes+=("$(basename "$dir")")
        done
    fi
    if [[ -d "$HOME/.themes" ]]; then
        for dir in "$HOME/.themes"/*; do
            [[ -d "$dir" ]] && themes+=("$(basename "$dir")")
        done
    fi
    printf '%s\n' "${themes[@]}" | sort -u
}

get_available_icons() {
    local icons=()
    if [[ -d /usr/share/icons ]]; then
        for dir in /usr/share/icons/*; do
            [[ -d "$dir" ]] && icons+=("$(basename "$dir")")
        done
    fi
    if [[ -d "$HOME/.local/share/icons" ]]; then
        for dir in "$HOME/.local/share/icons"/*; do
            [[ -d "$dir" ]] && icons+=("$(basename "$dir")")
        done
    fi
    if [[ -d "$HOME/.icons" ]]; then
        for dir in "$HOME/.icons"/*; do
            [[ -d "$dir" ]] && icons+=("$(basename "$dir")")
        done
    fi
    printf '%s\n' "${icons[@]}" | sort -u
}

configure_gtk_manual() {
    log_step "配置 GTK 设置..."

    mapfile -t themes < <(get_available_themes)
    mapfile -t icons < <(get_available_icons)

    if [[ ${#themes[@]} -eq 0 ]]; then
        log_warn "未找到已安装的主题"
        return 1
    fi

    if [[ ${#icons[@]} -eq 0 ]]; then
        log_warn "未找到已安装的图标"
        return 1
    fi

    # 选择主题
    echo ""
    echo "可用主题列表:"
    for i in "${!themes[@]}"; do
        printf "  %2d) %s\n" $((i+1)) "${themes[$i]}"
    done
    echo "----------------------------------------"
    read -p "请选择主题编号 (直接回车跳过): " theme_idx
    if [[ -z "$theme_idx" ]]; then
        log_warn "未选择主题，跳过 GTK 配置"
        return 0
    fi
    if [[ ! "$theme_idx" =~ ^[0-9]+$ ]] || [ "$theme_idx" -lt 1 ] || [ "$theme_idx" -gt ${#themes[@]} ]; then
        log_error "无效选择"
        return 1
    fi
    local theme_choice="${themes[$((theme_idx-1))]}"

    # 选择图标
    echo ""
    echo "可用图标列表:"
    for i in "${!icons[@]}"; do
        printf "  %2d) %s\n" $((i+1)) "${icons[$i]}"
    done
    echo "----------------------------------------"
    read -p "请选择图标主题编号 (直接回车跳过): " icon_idx
    if [[ -z "$icon_idx" ]]; then
        log_warn "未选择图标，跳过 GTK 配置"
        return 0
    fi
    if [[ ! "$icon_idx" =~ ^[0-9]+$ ]] || [ "$icon_idx" -lt 1 ] || [ "$icon_idx" -gt ${#icons[@]} ]; then
        log_error "无效选择"
        return 1
    fi
    local icon_choice="${icons[$((icon_idx-1))]}"

    log_info "应用主题: $theme_choice"
    log_info "应用图标: $icon_choice"

    mkdir -p "$HOME/.config/gtk-3.0"
    mkdir -p "$HOME/.config/gtk-4.0"

    cat > "$HOME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-theme-name = $theme_choice
gtk-icon-theme-name = $icon_choice
gtk-font-name = Sans 10
gtk-cursor-theme-name = Adwaita
gtk-button-images = 0
gtk-menu-images = 0
gtk-toolbar-icon-size = GTK_ICON_SIZE_LARGE
gtk-enable-event-sounds = 1
gtk-enable-input-feedback-sounds = 0
gtk-xft-antialias = 1
gtk-xft-hinting = 1
gtk-xft-hintstyle = hintslight
gtk-xft-rgba = rgb
gtk-decoration-layout = :minimize,maximize,close
EOF
    log_info "GTK3 设置已更新"

    cat > "$HOME/.gtkrc-2.0" <<EOF
gtk-theme-name = "$theme_choice"
gtk-icon-theme-name = "$icon_choice"
gtk-font-name = "Sans 10"
EOF
    log_info "GTK2 设置已更新"

    cat > "$HOME/.config/gtk-4.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=$theme_choice
gtk-icon-theme-name=$icon_choice
gtk-font-name=Sans 10
gtk-cursor-theme-name=Adwaita
EOF
    log_info "GTK4 设置已更新"

    if command -v gtk-update-icon-cache &>/dev/null; then
        for theme_dir in "$HOME/.local/share/themes"/* "$HOME/.themes"/*; do
            [[ -d "$theme_dir" ]] && gtk-update-icon-cache -f -t "$theme_dir" 2>/dev/null || true
        done
        for icon_dir in "$HOME/.local/share/icons"/* "$HOME/.icons"/*; do
            [[ -d "$icon_dir" ]] && gtk-update-icon-cache -f -t "$icon_dir" 2>/dev/null || true
        done
    fi

    log_info "GTK2/3/4 配置完成: 主题=$theme_choice, 图标=$icon_choice"
}

set_nemo_default() {
    log_step "设置 Nemo 为默认文件管理器..."

    if command -v nemo &>/dev/null; then
        xdg-mime default nemo.desktop inode/directory application/x-gnome-saved-search
        log_info "Nemo 已设置为默认文件管理器"
    else
        log_warn "Nemo 未安装, 跳过"
    fi
}

# -------------------- 交互菜单 --------------------
interactive_menu() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       主题安装 (DWM 环境 - Arch)${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""

    # === 稳健的路径解析 ===
    # 优先使用 BASH_SOURCE，回退到 $0
    local script_path="${BASH_SOURCE[0]:-$0}"
    # 解析真实路径（如果是软链接）
    if command -v realpath &>/dev/null; then
        SCRIPT_DIR="$(realpath "$(dirname "$script_path")")"
    else
        SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd -P)"
    fi

    log_info "脚本真实目录: $SCRIPT_DIR"

    # 定义可选操作及其描述
    local operations=(
        "mint-themes:安装 Mint-Y 主题 (本地 tarball)"
        "mint-y-icons:安装 Mint-Y 图标 (AUR)"
        "nordic-icons:安装 Nordic 图标 (本地 tarball)"
        "nordic-themes:安装 Nordic 主题 (本地 tarball)"
        "lxappearance:安装 lxappearance 主题配置工具"
        "gtk-config:配置 GTK 主题和图标"
        "nemo-default:设置 Nemo 为默认文件管理器"
    )

    local available_ops=()
    local available_keys=()

    echo ""
    echo "检查本地主题包:"
    
    # 检查 Mint 主题
    local mint_theme_file="$SCRIPT_DIR/themes/mint-themes.tar.gz"
    if [[ -f "$mint_theme_file" ]]; then
        echo "  ✓ 找到: $mint_theme_file"
        available_ops+=("Mint-Y 主题 (本地)")
        available_keys+=("mint-themes")
    else
        echo "  ✗ 未找到: $mint_theme_file"
    fi

    # 检查 Nordic 图标
    local nordic_icon_file="$SCRIPT_DIR/icons/Nordzy.tar.gz"
    if [[ -f "$nordic_icon_file" ]]; then
        echo "  ✓ 找到: $nordic_icon_file"
        available_ops+=("Nordic 图标 (本地)")
        available_keys+=("nordic-icons")
    else
        echo "  ✗ 未找到: $nordic_icon_file"
    fi

    # 检查 Nordic 主题
    local nordic_theme_file="$SCRIPT_DIR/themes/Nordic-v40.tar.xz"
    if [[ -f "$nordic_theme_file" ]]; then
        echo "  ✓ 找到: $nordic_theme_file"
        available_ops+=("Nordic 主题 (本地)")
        available_keys+=("nordic-themes")
    else
        echo "  ✗ 未找到: $nordic_theme_file"
    fi

    # 添加不依赖本地文件的操作
    available_ops+=(
        "Mint-Y 图标 (AUR)"
        "lxappearance 配置工具"
        "GTK 主题配置"
        "Nemo 默认文件管理器"
    )
    available_keys+=(
        "mint-y-icons"
        "lxappearance"
        "gtk-config"
        "nemo-default"
    )

    echo ""
    echo "========================================"
    echo "  可选操作列表"
    echo "========================================"
    for i in "${!available_ops[@]}"; do
        printf "  %2d) %s\n" $((i+1)) "${available_ops[$i]}"
    done
    echo "----------------------------------------"
    echo "  输入编号选择 (多个用逗号分隔，如 1,3,4)"
    echo "  输入 'all' 全选，直接回车退出"
    echo "----------------------------------------"
    read -p "你的选择: " choice

    if [[ -z "$choice" ]]; then
        log_info "未选择任何操作，退出"
        return 0
    fi

    local selected_indices=()
    if [[ "$choice" == "all" ]]; then
        for ((i=0; i<${#available_keys[@]}; i++)); do
            selected_indices+=($((i+1)))
        done
    else
        IFS=',' read -ra nums <<< "$choice"
        for num in "${nums[@]}"; do
            num=$(echo "$num" | xargs)
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#available_keys[@]} ]; then
                selected_indices+=("$num")
            fi
        done
    fi

    if [[ ${#selected_indices[@]} -eq 0 ]]; then
        log_error "没有有效的选择"
        return 1
    fi

    local selected_keys=()
    for idx in "${selected_indices[@]}"; do
        selected_keys+=("${available_keys[$((idx-1))]}")
    done

    echo ""
    echo "即将执行以下操作:"
    for key in "${selected_keys[@]}"; do
        echo "  - $key"
    done

    if ! yes_no "确认继续？" "y"; then
        log_info "已取消"
        return 0
    fi

    for key in "${selected_keys[@]}"; do
        case "$key" in
            mint-themes)    install_mint_themes_from_tarball ;;
            mint-y-icons)   install_mint_icons_from_aur ;;
            nordic-icons)   install_nordic_icons_from_tarball ;;
            nordic-themes)  install_nordic_themes_from_tarball ;;
            lxappearance)   install_lxappearance ;;
            gtk-config)     configure_gtk_manual ;;
            nemo-default)   set_nemo_default ;;
        esac
    done

    log_step "所有操作完成!"
    press_enter
}

# -------------------- 主入口 --------------------
main() {
    if [[ "${1:-}" == "--help" ]]; then
        echo "用法: $0 [选项]"
        echo ""
        echo "选项:"
        echo "  --help     显示此帮助信息"
        echo "  --auto     自动安装 (不显示交互菜单)"
        echo "  --gui      打开 lxappearance 图形界面"
        exit 0
    fi

    if [[ "${1:-}" == "--gui" ]]; then
        log_info "启动 lxappearance..."
        exec lxappearance
    fi

    if [[ "${1:-}" == "--auto" ]]; then
        install_lxappearance
        install_mint_themes_from_tarball
        install_mint_icons_from_aur
        install_nordic_icons_from_tarball
        install_nordic_themes_from_tarball
        configure_gtk_manual
    else
        interactive_menu
    fi
}

main "$@"
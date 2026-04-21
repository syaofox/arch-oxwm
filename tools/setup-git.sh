#!/bin/bash

# Git 配置脚本 (Arch Linux 适配版)
# 用于在 Linux 环境下配置 Git 的常用设置

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 Git 是否已安装
if ! command -v git &> /dev/null; then
    print_error "Git 未安装，请先安装 Git"
    exit 1
fi

echo -e "${BLUE}=== Git 配置脚本 ===${NC}\n"

# 1. 配置用户身份信息
echo -e "${BLUE}1. 配置用户身份信息${NC}"

# 检查是否已有配置
CURRENT_NAME=$(git config --global user.name 2>/dev/null || echo "")
CURRENT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

if [ -n "$CURRENT_NAME" ] && [ -n "$CURRENT_EMAIL" ]; then
    print_info "当前配置："
    echo "  用户名: $CURRENT_NAME"
    echo "  邮箱: $CURRENT_EMAIL"
    read -r -p "是否要更新？(y/N): " update_identity
    if [[ ! "$update_identity" =~ ^[Yy]$ ]]; then
        print_info "跳过身份信息配置"
    else
        CURRENT_NAME=""
        CURRENT_EMAIL=""
    fi
fi

if [ -z "$CURRENT_NAME" ] || [ -z "$CURRENT_EMAIL" ]; then
    # 从命令行参数获取或提示用户输入
    if [ -n "$1" ] && [ -n "$2" ]; then
        USER_NAME="$1"
        USER_EMAIL="$2"
        print_info "使用命令行参数：$USER_NAME <$USER_EMAIL>"
    else
        read -r -p "请输入您的姓名: " USER_NAME
        read -r -p "请输入您的邮箱: " USER_EMAIL
    fi
    
    if [ -z "$USER_NAME" ] || [ -z "$USER_EMAIL" ]; then
        print_error "姓名和邮箱不能为空"
        exit 1
    fi
    
    git config --global user.name "$USER_NAME"
    git config --global user.email "$USER_EMAIL"
    print_success "已配置用户身份信息"
fi

# 2. 配置文本编辑器
echo -e "\n${BLUE}2. 配置文本编辑器${NC}"

CURRENT_EDITOR=$(git config --global core.editor 2>/dev/null || echo "")

if [ -n "$CURRENT_EDITOR" ]; then
    print_info "当前编辑器: $CURRENT_EDITOR"
    read -r -p "是否要更改？(y/N): " change_editor
    if [[ ! "$change_editor" =~ ^[Yy]$ ]]; then
        print_info "跳过编辑器配置"
    else
        CURRENT_EDITOR=""
    fi
fi

if [ -z "$CURRENT_EDITOR" ]; then
    echo -e "${BLUE}请选择文本编辑器：${NC}"
    echo ""
    echo "  1) nvim     (Neovim - 现代 Vim 替代品)"
    echo "  2) vim      (Vim - 经典编辑器)"
    echo "  3) nano     (Nano - 简单易用)"
    echo "  4) code     (VS Code - 图形编辑器)"
    echo "  5) kate     (Kate - KDE 高级编辑器)"
    echo "  6) gedit    (Gedit - GNOME 文本编辑器)"
    echo "  7) 自定义"
    echo ""
    
    read -r -p "请选择 [1-7]: " editor_choice
    
    case "$editor_choice" in
        1) USER_EDITOR="nvim" ;;
        2) USER_EDITOR="vim" ;;
        3) USER_EDITOR="nano" ;;
        4) USER_EDITOR="code" ;;
        5) USER_EDITOR="kate" ;;
        6) USER_EDITOR="gedit" ;;
        7)
            read -r -p "请输入编辑器命令: " USER_EDITOR
            ;;
        *)
            # 自动检测：优先 nvim > vim > code > nano > vi
            if command -v nvim &> /dev/null; then
                USER_EDITOR="nvim"
            elif command -v vim &> /dev/null; then
                USER_EDITOR="vim"
            elif command -v code &> /dev/null; then
                USER_EDITOR="code"
            elif command -v nano &> /dev/null; then
                USER_EDITOR="nano"
            else
                USER_EDITOR="vi"
            fi
            ;;
    esac
    
    if command -v "$USER_EDITOR" &> /dev/null; then
        git config --global core.editor "$USER_EDITOR"
        print_success "已配置编辑器: $USER_EDITOR"
    else
        print_error "编辑器 '$USER_EDITOR' 未安装"
        exit 1
    fi
fi

# 3. 配置别名
echo -e "\n${BLUE}3. 配置常用别名${NC}"

# 定义别名数组
declare -A ALIASES=(
    ["st"]="status"
    ["co"]="checkout"
    ["br"]="branch"
    ["ci"]="commit"
    ["lg"]="log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
)

for alias in "${!ALIASES[@]}"; do
    cmd="${ALIASES[$alias]}"
    CURRENT_ALIAS=$(git config --global "alias.$alias" 2>/dev/null || echo "")
    
    if [ -n "$CURRENT_ALIAS" ]; then
        if [ "$CURRENT_ALIAS" != "$cmd" ]; then
            print_warning "别名 '$alias' 已存在但不同，跳过"
        else
            print_info "别名 '$alias' 已存在"
        fi
    else
        git config --global "alias.$alias" "$cmd"
        print_success "已配置别名: git $alias -> git $cmd"
    fi
done

# 4. 配置终端颜色
echo -e "\n${BLUE}4. 配置终端颜色${NC}"

CURRENT_COLOR=$(git config --global color.ui 2>/dev/null || echo "")

if [ -z "$CURRENT_COLOR" ] || [ "$CURRENT_COLOR" != "auto" ]; then
    git config --global color.ui auto
    print_success "已启用终端颜色输出"
else
    print_info "终端颜色已配置"
fi

# 5. 配置换行符处理
echo -e "\n${BLUE}5. 配置换行符处理${NC}"

CURRENT_AUTOCRLF=$(git config --global core.autocrlf 2>/dev/null || echo "")

if [ -z "$CURRENT_AUTOCRLF" ] || [ "$CURRENT_AUTOCRLF" != "input" ]; then
    git config --global core.autocrlf input
    print_success "已配置换行符处理 (Linux/macOS 推荐设置)"
else
    print_info "换行符处理已配置"
fi

# 显示配置摘要
echo -e "\n${BLUE}=== 配置摘要 ===${NC}"
echo -e "${GREEN}已完成的配置：${NC}"
echo "  - 用户身份信息"
echo "  - 文本编辑器"
echo "  - 常用别名 (st, co, br, ci, lg)"
echo "  - 终端颜色"
echo "  - 换行符处理"

echo -e "\n${BLUE}当前全局配置：${NC}"
git config --global --list | sed 's/^/  /'

echo -e "\n${GREEN}配置完成！${NC}"
echo -e "\n${BLUE}提示：${NC}"
echo "  - 使用 'git st' 代替 'git status'"
echo "  - 使用 'git lg' 查看美化的提交历史"
echo "  - 使用 'git config --global --list' 查看所有配置"
echo "  - 使用 'git config --global --unset <key>' 删除某个配置"
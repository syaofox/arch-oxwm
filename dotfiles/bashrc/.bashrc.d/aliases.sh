# 常用别名和环境变量设置
export EDITOR='nvim'
export VISUAL='nvim'


# 常用别名
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'

alias trash='trash-put -v'
alias rm='trash-put -v'


# 系统更新快捷命令
alias update='sudo pacman -Syyu'
alias upgrade='sudo paru'

# 按大小排序查看当前目录文件
alias diskspace='du -sh * | sort -h'

# 快速进入常用目录
alias dl='cd ~/Downloads'
alias docs='cd ~/Documents'
alias desk='cd ~/Desktop'
alias pics='cd ~/Pictures'
alias vids='cd ~/Videos'
alias dnas='cd /mnt/dnas'
alias data='cd /mnt/data'
alias dev='cd /mnt/github'

# 常用工具快捷命令
alias lzd='lazydocker'
alias dcp='docker compose'


# 防止误删除
alias rm='rm -i'

# 网络相关
alias myip='curl -s ifconfig.me'
# 查看哪个进程占用了某个端口
alias port='sudo ss -tulnp | grep'

# 软件
alias comfyup='cd /mnt/github/comfyui-docker; touch ./custom_nodes/.update; docker compose restart; cd -'
#!/bin/bash
# Zsh 一键安装配置脚本 —— Ubuntu 20.04 (focal)
# 用法：bash ~/Desktop/install_zsh_ubuntu2004.sh
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[x]${NC} $1"; }

# 用 sudo 跑会把 root 的登录 shell 改掉，这里直接拦住
if [ "$(id -u)" -eq 0 ]; then
    err "不要用 sudo / root 运行本脚本（会改错用户的登录 shell）"
    exit 1
fi

. /etc/os-release
if [ "$VERSION_ID" != "20.04" ]; then
    warn "本脚本针对 Ubuntu 20.04，当前系统是 $VERSION_ID，继续执行可能出问题。"
fi
log "系统版本：Ubuntu $VERSION_ID"

# ── 1. 安装 Zsh 和依赖 ─────────────────────────
log "更新软件源..."
sudo apt update

log "安装 Zsh、git、curl、command-not-found..."
# 20.04 源里是 zsh 5.8，22.04 是 5.8.1；对配置文件没影响，不用管版本号
sudo apt install -y zsh git curl command-not-found
log "Zsh 版本：$(zsh --version)"

# ── 2. 安装 Oh My Zsh ──────────────────────────
if [ -d "$HOME/.oh-my-zsh" ]; then
    warn "Oh My Zsh 已存在，跳过安装"
else
    log "安装 Oh My Zsh..."
    # KEEP_ZSHRC=yes：不覆盖已有 ~/.zshrc；RUNZSH/CHSH：安装器不要自己乱跳
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# ── 3. 安装插件 ────────────────────────────────
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    log "安装 zsh-autosuggestions..."
    git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
        "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
else
    warn "zsh-autosuggestions 已存在，跳过"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    log "安装 zsh-syntax-highlighting..."
    git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
else
    warn "zsh-syntax-highlighting 已存在，跳过"
fi

# ── 4. 写入 .zshrc ─────────────────────────────
# 已有 Oh My Zsh 配置就别动它：里面通常混着 conda/ROS/代理等一堆东西，
# 直接覆盖会静默把这些搞没。想强制重写，先把旧文件挪走再跑。
if [ -f "$HOME/.zshrc" ] && grep -q 'oh-my-zsh.sh' "$HOME/.zshrc"; then
    warn "~/.zshrc 已经是 Oh My Zsh 配置，跳过写入（避免覆盖 conda/ROS/代理等设置）"
else
    if [ -f "$HOME/.zshrc" ]; then
        backup="$HOME/.zshrc.bak.$(date +%Y%m%d%H%M%S)"
        cp "$HOME/.zshrc" "$backup"
        log "已备份原配置到 $backup"
    fi
    log "写入 ~/.zshrc ..."
    cat > "$HOME/.zshrc" << 'ZSH_EOF'
# ── 基础 ──────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    colored-man-pages
    command-not-found
)

source "$ZSH/oh-my-zsh.sh"

# ── 历史记录优化 ──────────────────────────────
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY

# ── 智能补全（Oh My Zsh 已经跑过 compinit，这里只加样式）──
zstyle ':completion:*' menu select

# ── 自动纠错 ──────────────────────────────────
setopt CORRECT
# setopt CORRECT_ALL   # 连命令参数都会被"纠正"，太激进，要用自己打开

# ── 别名 ──────────────────────────────────────
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias update='sudo apt update && sudo apt upgrade'
ZSH_EOF
    log "~/.zshrc 配置完成"
fi

# ── 5. 切换默认 Shell ──────────────────────────
current_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
if [ "$current_shell" = "$(command -v zsh)" ]; then
    warn "默认 Shell 已经是 Zsh，跳过切换"
else
    log "切换默认 Shell 为 Zsh（会要求输入密码）..."
    if chsh -s "$(command -v zsh)"; then
        log "默认 Shell 已切换为 Zsh"
    else
        warn "切换失败，手动执行：chsh -s $(command -v zsh)"
    fi
fi

# ── 6. 自检 ────────────────────────────────────
log "检查 ~/.zshrc 能否正常加载..."
if zsh -n "$HOME/.zshrc" && timeout 20 zsh -i -c true >/dev/null 2>&1; then
    log "~/.zshrc 加载正常"
else
    err "~/.zshrc 加载有问题，用 zsh -i 进去看报错，或从备份恢复"
fi

cat <<'NOTE'

==========================================
  Zsh 安装配置完成
==========================================
  当前会话继续用 Bash，新开终端或直接输入 zsh 生效

  恢复原配置： cp ~/.zshrc.bak.<时间戳> ~/.zshrc
  切回 Bash：  chsh -s $(command -v bash)

注意：
1) GitHub 拉不动时先配代理再跑；raw.githubusercontent.com 国内经常超时。
2) Ubuntu 20.04 标准支持已结束（2025-04），长期用建议升到 22.04/24.04。
3) 如果终端软件（VSCode 内置终端等）设了"自定义命令"，要改成 zsh 才会跟着切。
NOTE

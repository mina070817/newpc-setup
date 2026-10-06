#!/bin/bash
# 护眼模式（redshift 蓝光过滤）一键配置
# Ubuntu 20.04 / 22.04 通用（两份配置完全一样，没必要拆）
# 用法：bash ~/Desktop/install_redshift_eyecare.sh
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[x]${NC} $1"; }

if [ "$(id -u)" -eq 0 ]; then
    err "不要用 sudo 运行：配置要写进你自己的 ~/.config，root 跑会写错地方"
    exit 1
fi

# redshift 的 randr 方式只在 X11 下有效；Wayland 得换成 wayland 方式
case "${XDG_SESSION_TYPE:-未知}" in
    x11)     log "会话类型：X11，用 adjustment-method=randr" ;;
    wayland) warn "当前是 Wayland 会话，下面配置里的 adjustment-method 建议改成 wayland" ;;
    *)       warn "看不出会话类型（\$XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-未设置}），按 X11 配置" ;;
esac

# ── 1. 安装 redshift ───────────────────────────
log "安装 redshift + 托盘程序..."
sudo apt update
sudo apt install -y redshift redshift-gtk
log "redshift 版本：$(redshift -V 2>&1 | head -1)"

# ── 2. 写 ~/.config/redshift.conf ──────────────
mkdir -p "$HOME/.config"
if [ -f "$HOME/.config/redshift.conf" ]; then
    backup="$HOME/.config/redshift.conf.bak.$(date +%Y%m%d%H%M%S)"
    cp "$HOME/.config/redshift.conf" "$backup"
    log "已备份原配置到 $backup"
fi

log "写入 ~/.config/redshift.conf ..."
cat > "$HOME/.config/redshift.conf" << 'EOF'
[redshift]
; 白天和夜间色温统一设为 4500
temp-day=4500
temp-night=4500
; 关闭平滑过渡，锁定色温
transition=0
brightness-day=0.95
brightness-night=0.8
gamma=0.95:0.95:0.95
location-provider=manual
adjustment-method=randr

[manual]
; 上海。换城市就改这两个数字（北纬/东经）
lat=31.23
lon=121.47
EOF

# ── 3. 开机自启 ────────────────────────────────
mkdir -p "$HOME/.config/autostart"
log "写入开机自启项..."
cat > "$HOME/.config/autostart/redshift.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Redshift
Exec=redshift-gtk
Comment=Adjust screen color temperature
X-GNOME-Autostart-enabled=true
EOF

# ── 4. 立即生效 ────────────────────────────────
log "重启 redshift 让它马上生效..."
pkill -x redshift-gtk 2>/dev/null || true
pkill -x redshift 2>/dev/null || true
sleep 1
setsid -f redshift-gtk >/dev/null 2>&1 < /dev/null || true

# ── 5. 自检 ────────────────────────────────────
log "当前生效的色温/亮度："
sleep 1
redshift -p 2>&1 | sed 's/^/    /'

cat <<'NOTE'

==========================================
  护眼模式配置完成
==========================================
  色温 4500K 常亮，白天亮度 0.95 / 夜间 0.8，gamma 0.95
  立即生效，且已加入开机自启

  临时改用别的色温：  redshift -O 4000
  暂停/继续：         pkill -x redshift-gtk   /   setsid -f redshift-gtk
  改配置：            vim ~/.config/redshift.conf
  恢复原配置：        cp ~/.config/redshift.conf.bak.<时间戳> ~/.config/redshift.conf

注意：
1) 你机器上 GNOME 自带夜灯也是开着的（3700K，0:00-23:59 全天），
   和 redshift 叠加等于两层滤镜，屏幕会更黄更暗。建议二选一：
     关掉夜灯只留 redshift：
       gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled false
     或反过来关掉 redshift 只用夜灯：
       gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature uint32 4500
2) GNOME 42 没有系统托盘，redshift-gtk 图标可能看不到，但滤镜照常生效。
3) Wayland 会话下 randr 方式会失效，把调色方式改成 wayland 即可。
NOTE

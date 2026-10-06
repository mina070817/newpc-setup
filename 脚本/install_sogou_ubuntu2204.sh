#!/bin/bash
# 搜狗输入法自动安装脚本 —— Ubuntu 22.04 (jammy)
# 用法：把本脚本和 sogoupinyin_*.deb 放在同一目录，然后执行 bash 本脚本
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEB_FILE="$(find "$SCRIPT_DIR" -maxdepth 1 -name 'sogoupinyin_*.deb' -print -quit)"
if [ -z "$DEB_FILE" ]; then
    echo "错误：未在本脚本目录找到 sogoupinyin_*.deb"
    echo "请把 deb 包和本脚本放在同一目录（如桌面）后重新运行。"
    exit 1
fi

. /etc/os-release
if [ "$VERSION_ID" != "22.04" ]; then
    echo "警告：本脚本针对 Ubuntu 22.04，当前系统是 $VERSION_ID，继续执行可能出问题。"
fi

echo "=== 1/4 安装 fcitx 4 框架 ==="
# 22.04 默认预装了 fcitx5 和 ibus，但搜狗只认 fcitx 4；
# 框架都装上不影响，最后用 im-config 指定用哪个。
sudo apt update
sudo apt install -y fcitx fcitx-config-gtk fcitx-frontend-gtk3 fcitx-frontend-qt5

echo "=== 2/4 安装搜狗输入法 deb ==="
sudo apt install -y "$DEB_FILE"

echo "=== 3/4 把默认输入法框架设为 fcitx ==="
# ~/.xinputrc 被手动改过时 im-config 会拒绝写入，先备份再清掉
if [ -f "$HOME/.xinputrc" ] && ! grep -q '^run_im' "$HOME/.xinputrc"; then
    cp -a "$HOME/.xinputrc" "$HOME/.xinputrc.bak.$(date +%s)"
    rm -f "$HOME/.xinputrc"
fi
im-config -n fcitx

echo "=== 4/4 检查 ==="
grep -q '^run_im' "$HOME/.xinputrc" \
    && echo "默认输入法框架：$(grep '^run_im' "$HOME/.xinputrc")" \
    || echo "警告：~/.xinputrc 里没有 run_im 行，需要手动检查"
fcitx-remote >/dev/null 2>&1 \
    && echo "fcitx 正在运行" \
    || echo "fcitx 未运行（注销重新登录后会自动启动）"

cat <<'NOTE'

==============================
安装完成，请注销后重新登录（或重启）。
登录后右上角出现输入法图标，Ctrl+Space 切换中英文；
在 fcitx 配置里把「搜狗拼音」加到输入法列表第一位。
==============================
注意：
1) 搜狗输入法只在 Xorg 会话下稳定，Wayland 下经常调不出来。
   简单办法：注销后，在登录界面点右下角齿轮 → 选 “Ubuntu on Xorg” → 再登录。
   彻底办法：sudo sed -i 's/^#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf && sudo systemctl restart gdm3
2) 不要同时启用 ibus / fcitx5，否则会互相抢输入法。
NOTE

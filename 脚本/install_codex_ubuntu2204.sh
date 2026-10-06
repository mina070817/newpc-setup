#!/bin/bash
# Codex CLI 安装 + DeepSeek 接入 —— Ubuntu 22.04 (jammy)
# 用法：bash ~/Desktop/install_codex_ubuntu2204.sh
set -euo pipefail

. /etc/os-release
if [ "$VERSION_ID" != "22.04" ]; then
    echo "警告：本脚本针对 Ubuntu 22.04，当前系统是 $VERSION_ID，继续执行可能出问题。"
fi

echo "=== 1/4 安装 Codex CLI（官方 standalone 安装脚本）==="
command -v curl >/dev/null || { echo "缺少 curl，请先执行 sudo apt install -y curl"; exit 1; }
# 下的是 *-unknown-linux-musl 静态二进制，不依赖 glibc 和 node，
# 所以 22.04 也不需要装 Node.js。别用 sudo，装到 ~/.local/bin 即可。
curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh

echo "=== 2/4 让当前终端立刻能用 codex ==="
# 不能写 source ~/.bashrc：Ubuntu 的 .bashrc 开头是
#   case $- in *i*) ;; *) return;; esac
# 非交互执行时直接 return，PATH 根本不会生效。直接 export 才有效。
export PATH="$HOME/.local/bin:$PATH"
hash -r
if ! command -v codex >/dev/null 2>&1; then
    echo "错误：codex 仍不在 PATH，检查 ~/.local/bin/codex 是否存在、以及 shell 启动文件里的 PATH 配置"
    exit 1
fi
codex --version

echo "=== 3/4 接入 DeepSeek（会弹出交互菜单）==="
echo "菜单选项：1 = deepseek-flash（便宜快，推荐）  2 = deepseek-v4-pro（最强）  9 = 恢复默认配置"
bash <(curl -fsSL https://cdn.deepseek.com/api-docs/codex-deepseek-setup-en.sh)

echo "=== 4/4 验证 ==="
grep -m1 '^model' "$HOME/.codex/config.toml" 2>/dev/null \
    && echo "配置已写入 ~/.codex/config.toml" \
    || echo "没找到 model 行，运行 codex 看横幅是否显示 deepseek-flash"

cat <<'NOTE'

==============================
完成。新开一个终端，运行 codex，横幅应显示：model: deepseek-flash high
==============================
注意：
1) 如果系统里已经有别的 codex（比如 /usr/local/bin/codex），PATH 顺序决定跑哪个。
   用 `command -v codex` 确认拿到的是 ~/.local/bin/codex。
2) api.deepseek.com 国内可直连；如果开了代理反而变慢：
   unset https_proxy http_proxy all_proxy
3) 自动更新会自动切换 ~/.codex/packages/standalone/current 软链接，不用手动重建。
NOTE

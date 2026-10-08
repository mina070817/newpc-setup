#!/bin/bash
# 安装 reuse-first skill（动手写东西前，先搜 GitHub 有没有现成方案）。
# 用法：bash ~/Desktop/newpc-setup/脚本/install_reuse_skill.sh
#
# 干两件事：
#   1. 把 skills/reuse-first/ 整个复制到 ~/.codex/skills/reuse-first/
#   2. 打印触发方式和自检命令
# 不要用 sudo 跑，否则会装到 /root/.codex。
set -euo pipefail

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skill_src="$src_dir/skills/reuse-first"
skill_dst="$HOME/.codex/skills/reuse-first"

if [ ! -f "$skill_src/SKILL.md" ]; then
    echo "错误：找不到 $skill_src/SKILL.md，确认脚本和 skills/ 在同一个 newpc-setup 目录下。"
    exit 1
fi

if [ "$(id -u)" = "0" ]; then
    echo "错误：请用普通用户运行（不要 sudo），否则会装到 /root/.codex。"
    exit 1
fi

echo "=== 1/2 安装 $skill_dst ==="
mkdir -p "$HOME/.codex/skills"
if [ -e "$skill_dst" ]; then
    stamp=$(date +%Y%m%d-%H%M%S)
    cp -a "$skill_dst" "$skill_dst.bak-$stamp"
    echo "已备份旧版本到 reuse-first.bak-$stamp"
fi
rm -rf "$skill_dst"
cp -a "$skill_src" "$skill_dst"
find "$skill_dst" -type f | sed "s|$HOME|~|"

echo "=== 2/2 自检 ==="
if [ -f "$skill_dst/SKILL.md" ] && [ -f "$skill_dst/scripts/gh_search.py" ]; then
    echo "文件就位。"
else
    echo "自检失败：SKILL.md 或 scripts/gh_search.py 缺失。"
    exit 1
fi
command -v python3 >/dev/null && echo "python3 可用：$(python3 --version)"

echo
echo "装好了。接下来："
echo "  1. 重启 Codex 后可以用 reuse-first 触发，或者直接说「先找找有没有现成的工具再动手」。"
echo "  2. 搜 GitHub 要联网：先确认 Clash 起来了（ss -lnt | grep 7897），脚本默认走 http://127.0.0.1:7897。"
echo "  3. 想提高 GitHub 速率限制，把只读 token 存到 ~/.codex/github_token（chmod 600），脚本会自动读取。"
echo "  4. 验证：python3 ~/.codex/skills/reuse-first/scripts/gh_search.py repos screen-recorder-x11 --limit 3"

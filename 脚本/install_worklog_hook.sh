#!/bin/bash
# 安装「每次开 Codex 会话自动建工作日志」的 SessionStart 钩子。
# 用法：bash ~/Desktop/newpc-setup/脚本/install_worklog_hook.sh
#
# 干三件事：
#   1. 把 work-log.sh 复制到 ~/.codex/work-log.sh
#   2. 把 SessionStart 钩子写进 ~/.codex/hooks.json（已有内容保留，只追加）
#   3. 在临时目录里自检一遍，确认能正常生成日志文件
# 不要用 sudo 跑，否则会装到 root 家目录。
set -euo pipefail

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
worklog_src="$src_dir/配置/work-log.sh"
hooks_src="$src_dir/配置/hooks.json"

if [ ! -f "$worklog_src" ] || [ ! -f "$hooks_src" ]; then
    echo "错误：找不到 $worklog_src 或 $hooks_src，确认脚本和 配置/ 在同一个 newpc-setup 目录下。"
    exit 1
fi

if [ "$(id -u)" = "0" ]; then
    echo "错误：请用普通用户运行（不要 sudo），否则会装到 /root/.codex。"
    exit 1
fi

codex_dir="$HOME/.codex"
mkdir -p "$codex_dir"
stamp=$(date +%Y%m%d-%H%M%S)

echo "=== 1/3 安装 $codex_dir/work-log.sh ==="
if [ -f "$codex_dir/work-log.sh" ]; then
    cp -p "$codex_dir/work-log.sh" "$codex_dir/work-log.sh.bak-$stamp"
    echo "已备份旧脚本到 work-log.sh.bak-$stamp"
    # 记住本机已经改过的日志目录名，安装后原样恢复，避免把自定义设置冲掉。
    old_note=$(sed -n 's/^note_name="\(.*\)"$/\1/p' "$codex_dir/work-log.sh" | head -1)
fi
cp "$worklog_src" "$codex_dir/work-log.sh"
chmod +x "$codex_dir/work-log.sh"
# 只接受安全的目录名，避免把奇怪字符塞进 sed 表达式。
if [ -n "${old_note:-}" ] && [ "$old_note" != "cyf_note" ] \
   && printf '%s' "$old_note" | grep -qE '^[A-Za-z0-9_-]+$'; then
    sed -i "s|^note_name=\"cyf_note\"$|note_name=\"$old_note\"|" "$codex_dir/work-log.sh"
    echo "保留了本机原有的日志目录名：$old_note"
fi
ls -l "$codex_dir/work-log.sh"

echo "=== 2/3 写入 $codex_dir/hooks.json ==="
if [ -f "$codex_dir/hooks.json" ]; then
    cp -p "$codex_dir/hooks.json" "$codex_dir/hooks.json.bak-$stamp"
    echo "已备份旧配置到 hooks.json.bak-$stamp"
fi

# 用 python3 合并，保证新电脑上原有的钩子不被覆盖。
python3 - "$codex_dir/hooks.json" "$hooks_src" <<'PY'
import json
import os
import sys

target, src = sys.argv[1], sys.argv[2]

with open(src, encoding="utf-8") as f:
    new = json.load(f)

if os.path.exists(target):
    try:
        with open(target, encoding="utf-8") as f:
            cur = json.load(f)
    except json.JSONDecodeError as e:
        sys.exit("现有 hooks.json 不是合法 JSON（%s），已中止，未做任何修改。" % e)
else:
    cur = {}

cur.setdefault("hooks", {}).setdefault("SessionStart", [])


def has_worklog(entries):
    for entry in entries:
        for h in entry.get("hooks", []):
            if "work-log.sh" in h.get("command", ""):
                return True
    return False


if has_worklog(cur["hooks"]["SessionStart"]):
    print("hooks.json 里已经有 work-log 钩子，跳过追加。")
else:
    cur["hooks"]["SessionStart"].extend(new["hooks"]["SessionStart"])
    print("已追加 SessionStart 钩子。")

with open(target, "w", encoding="utf-8") as f:
    json.dump(cur, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

echo "=== 3/3 自检 ==="
tmp_home=$(mktemp -d)
mkdir -p "$tmp_home/Desktop"
if HOME="$tmp_home" bash "$codex_dir/work-log.sh" | python3 -m json.tool >/dev/null; then
    echo "自检通过，模拟 HOME 下生成的文件："
    find "$tmp_home" -type f | sed "s|$tmp_home|~|"
else
    echo "自检失败，请把上面的输出发给配置的人。"
    rm -rf "$tmp_home"
    exit 1
fi
rm -rf "$tmp_home"

echo
echo "装好了。接下来："
echo "  1. 重启 Codex 并新开一个会话，首次会问是否信任这个钩子，选信任/允许。"
echo "  2. 之后每次开新会话，都会自动建好 <日期>/上装/ 目录，并在里面按「最大序号 + 1」新建日志文件："
echo "       首选 ~/Desktop/codex_create_note/<日期>/上装/N.md"
echo "       只有 codex_create_note 目录不存在时才兜底到 ~/Desktop/cyf_note/<日期>/N.md"
echo "  3. 想改位置，编辑 ~/.codex/work-log.sh 顶部的 repo_name / note_subdir / note_name。"

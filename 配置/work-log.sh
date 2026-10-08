#!/usr/bin/env bash
# Codex SessionStart 钩子：每次会话自动在「笔记仓库」里建一个按序号命名的日志文件。
#
# 存放位置（2026-10-08 用户要求固定成这样，以后不用每次交代）：
#   ~/Desktop/codex_create_note/<日期>/上装/N.md      ← 首选，每次自动建好「日期文件夹 / 上装」两级目录
#   ~/Desktop/cyf_note/<日期>/N.md                    ← 兜底：笔记仓库目录不存在时（例如刚装好的新电脑）
#
# 每次会话都会做三件事：
#   1. 建好当天的 <日期>/上装/ 目录；
#   2. 在 上装/ 里取「已有最大编号 + 1」，新建一个空的 N.md 模板（只新建，绝不覆盖已有文件）；
#   3. 把「本次会话该写哪个文件、写什么内容」注入到会话上下文里。
#
# 装法见 newpc-setup/脚本/install_worklog_hook.sh，不要单独跑本脚本（它只负责输出）。
set -u

# ── 可改参数 ────────────────────────────────────────────────────────────────
note_name="cyf_note"            # 兜底目录名（桌面下），只有笔记仓库不存在时才用它
repo_name="codex_create_note"   # 桌面下的笔记仓库目录名
note_subdir="上装"              # 仓库里放本机笔记的子目录（另一台电脑写日期目录根下，别混）

# ── 找桌面目录 ──────────────────────────────────────────────────────────────
# 桌面目录：优先用 XDG 配置，取不到就退回 $HOME/Desktop。
# 中文系统的桌面目录可能是 ~/桌面，靠这一步自动适配。
desktop="${XDG_DESKTOP_DIR:-}"
if [ -z "$desktop" ] && command -v xdg-user-dir >/dev/null 2>&1; then
  desktop=$(xdg-user-dir DESKTOP 2>/dev/null || true)
fi
case "$desktop" in
  *'$HOME'*) desktop=${desktop//'$HOME'/$HOME} ;;
esac
if [ -z "$desktop" ] || [ ! -d "$desktop" ]; then
  desktop="$HOME/Desktop"
fi

day=$(date +%F)

# ── 选目录：首选仓库里的 <日期>/上装/ ───────────────────────────────────────
repo_dir="$desktop/$repo_name"
if [ -d "$repo_dir" ]; then
  dir="$repo_dir/$day/$note_subdir"
else
  dir="$desktop/$note_name/$day"
fi
mkdir -p "$dir" || exit 0

# ── 序号 = 目录里已有的最大编号 + 1 ─────────────────────────────────────────
# 只看文件名开头的 1~3 位数字："7.md" / "7  标题.md" / "7_标题.md" 都算第 7 篇。
# 4 位及以上不算编号，这样 "2026-10-08_启动命令.md" 这种日期前缀的文件不会被误算成 2026。
max=0
for f in "$dir"/*; do
  [ -e "$f" ] || continue
  base=${f##*/}
  n=$(printf '%s' "$base" | sed -n 's/^\([0-9][0-9]*\)\([^0-9].*\)\{0,1\}$/\1/p')
  [ -n "$n" ] || continue
  case "$n" in
    [0-9]|[0-9][0-9]|[0-9][0-9][0-9]) ;;
    *) continue ;;
  esac
  n=$((10#$n))
  [ "$n" -gt "$max" ] && max=$n
done

# 只新建、不覆盖；万一算出重名（并发会话 / 手工占用）就继续往后找。
i=$((max + 1))
file="$dir/$i.md"
while [ -e "$file" ]; do
  i=$((i + 1))
  file="$dir/$i.md"
done

cat > "$file" <<EOF
# 工作日志 · $day · 第 $i 次

## 执行的操作

## 遇到的问题

## 解决方法
EOF

# ── 把日志路径和写法要求注入本次会话（SessionStart 钩子的 additionalContext）──
cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"本次会话的工作日志文件：$file\n所有这类 Codex 笔记都固定放在 ~/Desktop/codex_create_note/<日期>/上装/ 下，不要写到别处，也不用问用户。\n请在本次会话结束前，把内容写进这个文件（中文，只写最终有效的内容）：\n1. 执行的操作：按顺序列出这次实际运行的关键命令或改动，以及各自的目的和结果。\n2. 遇到的问题：说清楚现象、报错原文、触发条件。\n3. 解决方法：写详细的最终解决步骤，别人照着能复现。\n不要写试错的弯路和无效思路，只保留最后真正解决问题的方案。\n写完按 ~/.codex/AGENTS.md 的约定 git pull --rebase 后 push 到 GitHub。"}}
EOF

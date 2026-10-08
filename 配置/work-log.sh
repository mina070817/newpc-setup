#!/usr/bin/env bash
# Codex SessionStart 钩子：每天一个日期文件夹，每次会话一个按序号命名的日志文件。
#
# 效果：每次在 Codex 里开一个新会话，都会自动：
#   1. 在 <桌面>/cyf_note/<今天日期>/ 下创建一个空的 N.md 日志模板；
#   2. 把「本次会话该写哪个文件、写什么内容」注入到会话上下文里，
#      让 Codex 在会话结束前把总结写进去。
#
# 装法见 newpc-setup/脚本/install_worklog_hook.sh，不要单独跑本脚本（它只负责输出）。
set -u

# 日志根目录名，想改成别的（比如 codex_note）只改这一行。
note_name="cyf_note"

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
dir="$desktop/$note_name/$day"
mkdir -p "$dir" || exit 0

# 找到今天第一个没被占用的序号（noclobber 保证不会覆盖已有日志）。
i=1
while :; do
  file="$dir/$i.md"
  if (set -o noclobber; : > "$file") 2>/dev/null; then break; fi
  i=$((i + 1))
done

cat > "$file" <<EOF
# 工作日志 · $day · 第 $i 次

## 执行的操作

## 遇到的问题

## 解决方法
EOF

# 把日志路径和写法要求注入本次会话（SessionStart 钩子的 additionalContext）。
cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"本次会话的工作日志文件：$file\n请在本次会话结束前，把内容写进这个文件（中文，只写最终有效的内容）：\n1. 执行的操作：按顺序列出这次实际运行的关键命令或改动，以及各自的目的和结果。\n2. 遇到的问题：说清楚现象、报错原文、触发条件。\n3. 解决方法：写详细的最终解决步骤，别人照着能复现。\n不要写试错的弯路和无效思路，只保留最后真正解决问题的方案。"}}
EOF

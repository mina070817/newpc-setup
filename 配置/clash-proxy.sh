#!/usr/bin/env bash
#
# clash-proxy.sh - 自动探测 Clash Verge Rev (mihomo) 代理并注入环境变量
#
# 用法：
#   source ~/.codex/clash-proxy.sh        # 在当前 shell export 代理；Clash 未运行时 unset
#   ~/.codex/clash-proxy.sh --print       # 打印 export 语句（用于 eval 或调试）
#   ~/.codex/clash-proxy.sh --env-file    # 只刷新 ~/.codex/.env（桌面端/IDE 读取）
#
# 可覆盖项（环境变量）：
#   CLASH_VERGE_DIR   Verge 配置目录（默认 ~/.local/share/io.github.clash-verge-rev.clash-verge-rev）
#   CLASH_MIXED_PORT  手动指定混合端口（跳过配置读取）
#   CLASH_SOCKS_PORT  手动指定 socks 端口
#   CLASH_HTTP_PORT   手动指定 http 端口

VERGE_DIR="${CLASH_VERGE_DIR:-$HOME/.local/share/io.github.clash-verge-rev.clash-verge-rev}"
CLASH_YAML="$VERGE_DIR/clash-verge.yaml"
VERGE_YAML="$VERGE_DIR/verge.yaml"
ENV_FILE="${CODEX_HOME:-$HOME/.codex}/.env"

# 2026-10-08 用户指定的固定代理端口（不再依赖读 Clash Verge 的 yaml 自动探测）：
#   http/https = http://127.0.0.1:7897
#   socks/all  = socks5://127.0.0.1:7897
# 仍可用环境变量临时覆盖：CLASH_MIXED_PORT / CLASH_SOCKS_PORT / CLASH_HTTP_PORT
MIXED="${CLASH_MIXED_PORT:-7897}"
SOCKS="${CLASH_SOCKS_PORT:-7897}"
HTTP="${CLASH_HTTP_PORT:-7897}"

# 从 yaml 读取数字型配置项
get_val() {
  sed -n "s/^[[:space:]]*$2:[[:space:]]*\([0-9][0-9]*\).*/\1/p" "$1" 2>/dev/null | tail -1
}

if [ -z "$MIXED" ] && [ -f "$VERGE_YAML" ]; then
  MIXED=$(get_val "$VERGE_YAML" verge_mixed_port)
fi
if [ -z "$SOCKS" ] && [ -f "$VERGE_YAML" ]; then
  SOCKS=$(get_val "$VERGE_YAML" verge_socks_port)
fi
if [ -z "$HTTP" ] && [ -f "$VERGE_YAML" ]; then
  HTTP=$(get_val "$VERGE_YAML" verge_port)
fi
if [ -z "$MIXED" ] && [ -f "$CLASH_YAML" ]; then
  MIXED=$(get_val "$CLASH_YAML" mixed-port)
fi
if [ -z "$SOCKS" ] && [ -f "$CLASH_YAML" ]; then
  SOCKS=$(get_val "$CLASH_YAML" socks-port)
fi
if [ -z "$HTTP" ] && [ -f "$CLASH_YAML" ]; then
  HTTP=$(get_val "$CLASH_YAML" port)
fi

MIXED="${MIXED:-7897}"

# 端口是否在监听（Clash 是否真的在跑）
is_port_open() {
  local p="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -tln 2>/dev/null | awk '{print $4}' | grep -q ":${p}$"
  elif command -v nc >/dev/null 2>&1; then
    nc -z -w 1 127.0.0.1 "$p" >/dev/null 2>&1
  elif command -v bash >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
    timeout 1 bash -c "exec 3<>/dev/tcp/127.0.0.1/$p" >/dev/null 2>&1
  else
    return 1
  fi
}

CLASH_UP=0
if is_port_open "$MIXED"; then
  CLASH_UP=1
else
  # 兜底：unix socket API 能响应也算活着
  SOCK="/tmp/verge/verge-mihomo.sock"
  if [ -S "$SOCK" ] && command -v curl >/dev/null 2>&1; then
    curl -s --max-time 2 --unix-socket "$SOCK" http://localhost/version >/dev/null 2>&1 && CLASH_UP=1
  fi
fi

# 默认全部走 mixed 端口（http/socks 同一端口）；仅当配置了独立端口且确实在监听时才使用
HTTP="${HTTP:-$MIXED}"
SOCKS="${SOCKS:-$MIXED}"
if [ "$CLASH_UP" = "1" ]; then
  if [ "$HTTP" != "$MIXED" ] && ! is_port_open "$HTTP"; then
    HTTP="$MIXED"
  fi
  if [ "$SOCKS" != "$MIXED" ] && ! is_port_open "$SOCKS"; then
    SOCKS="$MIXED"
  fi
fi

HTTP_URL="http://127.0.0.1:${HTTP}"
SOCKS_URL="socks5://127.0.0.1:${SOCKS}"
# 注意：no_proxy 必须让机器人流量直连，否则 ROS1 的 Python 工具链
# （roslaunch/rosnode/rostopic/rospy 走 urllib，会读 http_proxy）会把发往
# 机器狗的请求丢给代理。机器狗 master = 192.168.123.1:11311。
#
# ⚠ 关键坑：Python 的 urllib/requests 和 curl(7.68, 20.04 自带) **只做后缀匹配，
#   不解析 CIDR**，所以 "192.168.0.0/16" 这种写法对它们无效，必须写具体 IP。
#   实测：no_proxy 含 192.168.123.1 → urllib.proxy_bypass 返回 True；含 /16 返回 False。
#   CIDR 仍然保留，给 curl>=7.86 / clash 自身等新工具用。
NO_PROXY_VAL="localhost,127.0.0.1,::1,192.168.123.1,192.168.123.18,192.168.123.161,172.16.100.71,172.16.100.180,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12"

apply_exports() {
  if [ "$CLASH_UP" = "1" ]; then
    export http_proxy="$HTTP_URL" https_proxy="$HTTP_URL" all_proxy="$SOCKS_URL"
    export HTTP_PROXY="$HTTP_URL" HTTPS_PROXY="$HTTP_URL" ALL_PROXY="$SOCKS_URL"
    export no_proxy="$NO_PROXY_VAL" NO_PROXY="$NO_PROXY_VAL"
  else
    unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY no_proxy NO_PROXY 2>/dev/null
  fi
}

print_exports() {
  if [ "$CLASH_UP" = "1" ]; then
    printf 'export http_proxy=%q https_proxy=%q all_proxy=%q\n' "$HTTP_URL" "$HTTP_URL" "$SOCKS_URL"
    printf 'export HTTP_PROXY=%q HTTPS_PROXY=%q ALL_PROXY=%q\n' "$HTTP_URL" "$HTTP_URL" "$SOCKS_URL"
    printf 'export no_proxy=%q NO_PROXY=%q\n' "$NO_PROXY_VAL" "$NO_PROXY_VAL"
  else
    printf 'unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY no_proxy NO_PROXY\n'
  fi
}

write_env_file() {
  local tmp="$ENV_FILE.tmp.$$"
  local dir
  dir=$(dirname "$ENV_FILE")
  # 目录不可写（例如沙箱只读挂载）时静默跳过
  [ -w "$dir" ] || return 0
  if [ "$CLASH_UP" = "1" ]; then
    cat > "$tmp" <<EOF
http_proxy=$HTTP_URL
https_proxy=$HTTP_URL
all_proxy=$SOCKS_URL
HTTP_PROXY=$HTTP_URL
HTTPS_PROXY=$HTTP_URL
ALL_PROXY=$SOCKS_URL
no_proxy=$NO_PROXY_VAL
NO_PROXY=$NO_PROXY_VAL
EOF
  else
    : > "$tmp"
  fi
  mv -f "$tmp" "$ENV_FILE"
}

case "${1:-}" in
  --print)
    print_exports
    ;;
  --env-file)
    write_env_file
    ;;
  *)
    apply_exports
    write_env_file
    ;;
esac

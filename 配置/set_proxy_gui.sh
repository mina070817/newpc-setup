#!/bin/bash
sleep 5

INPUT=$(zenity --entry \
    --title="设置代理" \
    --text="粘贴代理环境变量:" \
    --width=800 \
    --entry-text="export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897 all_proxy=socks5://127.0.0.1:7897")

[ -z "$INPUT" ] && exit 1

INPUT="${INPUT#export }"
TMP=$(mktemp)

for pair in $INPUT; do
    key="${pair%%=*}"
    val="${pair#*=}"
    [ -z "$key" ] && continue
    [ "$key" = "$val" ] && continue
    echo "export $key=$val" >> "$TMP"
done

grep -q '^export no_proxy=' "$TMP" || \
    echo "export no_proxy=localhost,127.0.0.1,::1" >> "$TMP"

# 弹图形密码框写入 /etc/profile.d/
pkexec bash -c "cat '$TMP' > /etc/profile.d/proxy.sh && chmod 644 /etc/profile.d/proxy.sh"
rm -f "$TMP"

zenity --info --title="设置完成" --text="已写入 /etc/profile.d/proxy.sh"

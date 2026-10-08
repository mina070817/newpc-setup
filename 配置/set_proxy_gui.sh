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

# no_proxy 一定要覆盖机器狗网段，而且必须写成具体 IP：
# Python 的 urllib/requests（ROS1 的 roslaunch/rostopic/rospy 都走它）和
# Ubuntu 20.04 自带的 curl 7.68 只做后缀匹配、不解析 CIDR，
# 写成 192.168.0.0/16 对它们无效 → 发往 192.168.123.1 的 ROS 流量会被丢给代理而连不上。
# CIDR 保留给 curl>=7.86 等新工具。
NO_PROXY_VAL="localhost,127.0.0.1,::1,192.168.123.1,192.168.123.18,192.168.123.161,172.16.100.71,172.16.100.180,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12"
grep -q '^export no_proxy=' "$TMP" || echo "export no_proxy=$NO_PROXY_VAL" >> "$TMP"
grep -q '^export NO_PROXY=' "$TMP" || echo "export NO_PROXY=$NO_PROXY_VAL" >> "$TMP"

# 弹图形密码框写入 /etc/profile.d/
pkexec bash -c "cat '$TMP' > /etc/profile.d/proxy.sh && chmod 644 /etc/profile.d/proxy.sh"
rm -f "$TMP"

zenity --info --title="设置完成" --text="已写入 /etc/profile.d/proxy.sh"

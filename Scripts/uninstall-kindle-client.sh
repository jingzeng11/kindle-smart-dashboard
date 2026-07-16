#!/bin/zsh

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "用法：$0 KINDLE_IP" >&2
    exit 2
fi

kindle_ip="$1"
kindle_port="${KINDLE_SSH_PORT:-22}"
target="root@$kindle_ip"
remote_dir="/mnt/us/extensions/kindle-smart-dashboard"
ssh_options=(-p "$kindle_port" -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
host_pattern='^[A-Za-z0-9][A-Za-z0-9.-]*$'

if [[ ! "$kindle_ip" =~ $host_pattern || ! "$kindle_port" =~ '^[0-9]+$' ]]; then
    echo "Kindle 地址或 SSH 端口格式无效。" >&2
    exit 2
fi

ssh "${ssh_options[@]}" "$target" \
    "if test -x '$remote_dir/stop.sh'; then '$remote_dir/stop.sh'; fi; rm -rf '$remote_dir'"

echo "Kindle 客户端已停止并卸载。"

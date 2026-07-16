#!/bin/zsh

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "用法：$0 KINDLE_IP [DASHBOARD_URL]" >&2
    exit 2
fi

project_root="${0:A:h:h}"
client_dir="$project_root/KindleClient/kindle-smart-dashboard"
kindle_ip="$1"
kindle_port="${KINDLE_SSH_PORT:-22}"
mac_ip="$(ipconfig getifaddr en0 2>/dev/null || true)"
dashboard_url="${2:-http://$mac_ip:8080/dashboard.png}"
target="root@$kindle_ip"
remote_dir="/mnt/us/extensions/kindle-smart-dashboard"
ssh_options=(-p "$kindle_port" -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
scp_options=(-P "$kindle_port" -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
host_pattern='^[A-Za-z0-9][A-Za-z0-9.-]*$'
url_pattern='^https?://[A-Za-z0-9._:-]+(/[A-Za-z0-9._~/?&=%+-]*)?$'

if [[ -z "$mac_ip" && $# -lt 2 ]]; then
    echo "无法自动确定 Mac 的 en0 地址，请显式传入 DASHBOARD_URL。" >&2
    exit 1
fi

if [[ ! "$kindle_ip" =~ $host_pattern || ! "$kindle_port" =~ '^[0-9]+$' ]]; then
    echo "Kindle 地址或 SSH 端口格式无效。" >&2
    exit 2
fi

if [[ ! "$dashboard_url" =~ $url_pattern ]]; then
    echo "DASHBOARD_URL 格式无效。" >&2
    exit 2
fi

curl --fail --silent --show-error "${dashboard_url%/dashboard.png}/health" >/dev/null

ssh "${ssh_options[@]}" "$target" \
    '(command -v eips >/dev/null 2>&1 || test -x /usr/sbin/eips) && (command -v wget >/dev/null 2>&1 || command -v curl >/dev/null 2>&1) && test -d /mnt/us/extensions'

ssh "${ssh_options[@]}" "$target" \
    "if test -x '$remote_dir/stop.sh'; then '$remote_dir/stop.sh'; fi; rm -rf '$remote_dir'"
scp "${scp_options[@]}" -r "$client_dir" "$target:/mnt/us/extensions/"
printf '%s\n' "DASHBOARD_URL='$dashboard_url'" | \
    ssh "${ssh_options[@]}" "$target" "tee '$remote_dir/config.local.sh' >/dev/null"
ssh "${ssh_options[@]}" "$target" \
    "chmod 755 '$remote_dir'/*.sh && '$remote_dir/start.sh'"

echo "Kindle 客户端已安装并启动。"
echo "设备：$kindle_ip"
echo "数据源：$dashboard_url"
echo "KUAL 菜单：Smart Dashboard"

#!/bin/zsh

set -euo pipefail

volume="${1:-/Volumes/Kindle}"
mac_ip="$(ipconfig getifaddr en0 2>/dev/null || true)"
dashboard_url="${2:-http://$mac_ip:8080/dashboard.png}"
project_root="${0:A:h:h}"
client_dir="$project_root/KindleClient/kindle-smart-dashboard"
target_dir="$volume/extensions/kindle-smart-dashboard"
url_pattern='^https?://[A-Za-z0-9._:-]+(/[A-Za-z0-9._~/?&=%+-]*)?$'

if [[ -z "$mac_ip" && $# -lt 2 ]]; then
    echo "无法自动确定 Mac 的 en0 地址，请显式传入 DASHBOARD_URL。" >&2
    exit 1
fi

if [[ ! "$dashboard_url" =~ $url_pattern ]]; then
    echo "DASHBOARD_URL 格式无效。" >&2
    exit 2
fi

if [[ ! -d "$volume/extensions" ]]; then
    echo "没有在 $volume 找到 extensions 目录；请确认 Kindle 已通过 USB 挂载且 KUAL 已安装。" >&2
    exit 1
fi

curl --fail --silent --show-error "${dashboard_url%/dashboard.png}/health" >/dev/null

rm -rf "$target_dir"
mkdir -p "$target_dir"
cp -R "$client_dir/." "$target_dir/"
printf '%s\n' "DASHBOARD_URL='$dashboard_url'" > "$target_dir/config.local.sh"

echo "Kindle 客户端已复制到：$target_dir"
echo "安全弹出 Kindle 后，在 KUAL 中选择 Smart Dashboard > Start hourly dashboard。"
echo "数据源：$dashboard_url"

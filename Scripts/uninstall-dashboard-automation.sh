#!/bin/zsh

set -euo pipefail

install_root="$HOME/Library/Application Support/KindleSmartDashboard"
agents_dir="$HOME/Library/LaunchAgents"
refresh_label="com.jingzeng.kindle-smart-dashboard.refresh"
server_label="com.jingzeng.kindle-smart-dashboard.server"
domain="gui/$UID"

launchctl bootout "$domain/$refresh_label" 2>/dev/null || true
launchctl bootout "$domain/$server_label" 2>/dev/null || true
rm -f "$agents_dir/$refresh_label.plist" "$agents_dir/$server_label.plist"
rm -rf "$install_root"

echo "Kindle Smart Dashboard 自动化已卸载。天气缓存和日志仍保留。"

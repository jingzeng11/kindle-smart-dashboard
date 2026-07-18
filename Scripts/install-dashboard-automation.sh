#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
install_root="$HOME/Library/Application Support/KindleSmartDashboard"
app_name="Kindle Smart Dashboard Calendar Access.app"
app_path="$install_root/$app_name"
binary_path="$app_path/Contents/MacOS/DashboardCLI"
data_dir="$install_root/data"
log_dir="$HOME/Library/Logs/KindleSmartDashboard"
output_path="$data_dir/dashboard.png"
refresh_log="$log_dir/refresh.log"
server_log="$log_dir/server.log"
error_log="$log_dir/error.log"
agents_dir="$HOME/Library/LaunchAgents"
refresh_label="com.jingzeng.kindle-smart-dashboard.refresh"
server_label="com.jingzeng.kindle-smart-dashboard.server"
refresh_plist="$agents_dir/$refresh_label.plist"
server_plist="$agents_dir/$server_label.plist"
domain="gui/$UID"

run_app_command() {
    local command="$1"
    local expected_pattern="$2"
    shift 2

    : > "$refresh_log"
    : > "$error_log"
    /usr/bin/open -n --stdout "$refresh_log" --stderr "$error_log" "$app_path" --args "$command" "$@"

    local attempt
    for attempt in {1..120}; do
        if grep -Eq "$expected_pattern" "$refresh_log"; then
            return 0
        fi
        if [[ -s "$error_log" ]]; then
            cat "$error_log" >&2
            return 1
        fi
        sleep 1
    done

    echo "等待 $command 权限结果超时。" >&2
    return 1
}

mkdir -p "$install_root" "$data_dir" "$log_dir" "$agents_dir"
touch "$refresh_log" "$server_log" "$error_log"

"$project_root/Scripts/build-calendar-authorizer.sh" >/dev/null
source_app="$project_root/.build/$app_name"

launchctl bootout "$domain/$refresh_label" 2>/dev/null || true
launchctl bootout "$domain/$server_label" 2>/dev/null || true

rm -rf "$app_path"
/usr/bin/ditto "$source_app" "$app_path"

cp "$project_root/Scripts/LaunchAgents/$refresh_label.plist" "$refresh_plist"
/usr/libexec/PlistBuddy -c "Set :ProgramArguments:3 $refresh_log" "$refresh_plist"
/usr/libexec/PlistBuddy -c "Set :ProgramArguments:5 $error_log" "$refresh_plist"
/usr/libexec/PlistBuddy -c "Set :ProgramArguments:6 $app_path" "$refresh_plist"
/usr/libexec/PlistBuddy -c "Set :ProgramArguments:14 $output_path" "$refresh_plist"

cp "$project_root/Scripts/LaunchAgents/$server_label.plist" "$server_plist"
/usr/libexec/PlistBuddy -c "Set :ProgramArguments:0 $binary_path" "$server_plist"
/usr/libexec/PlistBuddy -c "Set :ProgramArguments:7 $output_path" "$server_plist"
plutil -replace StandardOutPath -string "$server_log" "$server_plist"
plutil -replace StandardErrorPath -string "$error_log" "$server_plist"

plutil -lint "$refresh_plist" "$server_plist"
codesign --verify --deep --strict "$app_path"

run_app_command calendar-authorize "authorized|fullAccess"
run_app_command reminder-authorize "authorized|fullAccess"

run_app_command render "已生成：" \
    --source calendar --weather live --output "$output_path"
test -s "$output_path"

launchctl bootstrap "$domain" "$server_plist"
launchctl bootstrap "$domain" "$refresh_plist"

echo "自动化已安装。"
echo "仪表盘：http://127.0.0.1:8080/dashboard.png"
echo "健康检查：http://127.0.0.1:8080/health"
echo "图片：$output_path"
echo "日志：$log_dir"

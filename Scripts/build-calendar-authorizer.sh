#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
cd "$project_root"

swift build --product DashboardCLI
bin_dir="$(swift build --show-bin-path)"
app_path="$project_root/.build/Kindle Smart Dashboard Calendar Access.app"
bundle_identifier="com.jingzeng11.KindleSmartDashboard.CLI"
designated_requirement="=designated => identifier \"$bundle_identifier\""

rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS"
cp "$bin_dir/DashboardCLI" "$app_path/Contents/MacOS/DashboardCLI"
cp "$project_root/Sources/DashboardCLI/Info.plist" "$app_path/Contents/Info.plist"
codesign --force --sign - --requirements "$designated_requirement" "$app_path"

echo "$app_path"

#!/bin/sh

set -eu

project_root=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
client_dir="$project_root/KindleClient/kindle-smart-dashboard"
test_dir=$(mktemp -d /tmp/kindle-dashboard-ui-test.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT INT TERM

export DASHBOARD_DATA_DIR="$test_dir/data"
export DASHBOARD_LOG_FILE="$test_dir/dashboard.log"
export DASHBOARD_EXTENSION_ROOT="$client_dir"
export DASHBOARD_FRAMEBUFFER_DEVICE="$test_dir/framebuffer"
export FAKE_EIPS_LOG="$test_dir/eips.log"
export PATH="$project_root/Tests/KindleClientTests/bin:$PATH"
mkdir -p "$DASHBOARD_DATA_DIR"
printf '%s\n' 'cvm awesome' > "$DASHBOARD_DATA_DIR/ui.state"
printf '%s\n' 'clean stock home pixels' > "$DASHBOARD_FRAMEBUFFER_DEVICE"

. "$client_dir/lib.sh"
capture_stock_framebuffer
printf '%s\n' 'dashboard pixels' > "$DASHBOARD_FRAMEBUFFER_DEVICE"
resume_kindle_ui

grep -qx 'clean stock home pixels' "$DASHBOARD_FRAMEBUFFER_DEVICE"
grep -q 'Stock framebuffer restored' "$DASHBOARD_LOG_FILE"
test ! -e "$DASHBOARD_DATA_DIR/ui.state"
test ! -e "$DASHBOARD_DATA_DIR/stock-framebuffer.bin"

echo "Kindle UI restore simulation passed."

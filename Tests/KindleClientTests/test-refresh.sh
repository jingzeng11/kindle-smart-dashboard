#!/bin/sh

set -eu

project_root=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
client_dir="$project_root/KindleClient/kindle-smart-dashboard"
test_dir=$(mktemp -d /tmp/kindle-dashboard-test.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT INT TERM

export DASHBOARD_DATA_DIR="$test_dir/data"
export DASHBOARD_LOG_FILE="$test_dir/dashboard.log"
export FAKE_EIPS_LOG="$test_dir/eips.log"
export PATH="$project_root/Tests/KindleClientTests/bin:$PATH"
export DASHBOARD_URL="${DASHBOARD_TEST_URL:-http://127.0.0.1:8080/dashboard.png}"

sh "$client_dir/refresh.sh"

test -s "$DASHBOARD_DATA_DIR/dashboard.png"
signature=$(dd if="$DASHBOARD_DATA_DIR/dashboard.png" bs=8 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')
test "$signature" = "89504e470d0a1a0a"
grep -q '^-c$' "$FAKE_EIPS_LOG"
grep -q -- "-g $DASHBOARD_DATA_DIR/dashboard.png" "$FAKE_EIPS_LOG"

before=$(cksum "$DASHBOARD_DATA_DIR/dashboard.png")
export DASHBOARD_URL="http://127.0.0.1:8080/missing.png"
if sh "$client_dir/refresh.sh"; then
    echo "Expected missing image refresh to fail" >&2
    exit 1
fi
after=$(cksum "$DASHBOARD_DATA_DIR/dashboard.png")
test "$before" = "$after"
grep -q 'keeping the current screen' "$DASHBOARD_LOG_FILE"

echo "Kindle refresh simulation passed."

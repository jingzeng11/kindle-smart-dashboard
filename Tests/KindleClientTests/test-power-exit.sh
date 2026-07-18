#!/bin/sh

set -eu

project_root=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
client_dir="$project_root/KindleClient/kindle-smart-dashboard"
test_dir=$(mktemp -d /tmp/kindle-dashboard-power-test.XXXXXX)
target_pid=""

cleanup() {
    if [ -n "$target_pid" ]; then
        kill "$target_pid" 2>/dev/null || true
    fi
    rm -rf "$test_dir"
}
trap cleanup EXIT INT TERM

export PATH="$project_root/Tests/KindleClientTests/bin:$PATH"
export FAKE_LIPC_LOG="$test_dir/lipc.log"

sleep 30 &
target_pid=$!
sh "$client_dir/watch-power-exit.sh" "$target_pid"

if kill -0 "$target_pid" 2>/dev/null; then
    echo "Expected power watcher to terminate dashboard process" >&2
    exit 1
fi
grep -q 'com.lab126.powerd abortSuspend 1' "$FAKE_LIPC_LOG"

target_pid=""
echo "Kindle power exit simulation passed."

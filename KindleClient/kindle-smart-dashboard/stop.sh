#!/bin/sh

set -u

extension_root=$(CDPATH= cd "$(dirname "$0")" && pwd)
. "$extension_root/lib.sh"

if [ -f "$pid_path" ]; then
    running_pid=$(sed -n '1p' "$pid_path")
    kill "$running_pid" 2>/dev/null || true
fi

attempt=0
while [ -f "$pid_path" ] && [ "$attempt" -lt 10 ]; do
    sleep 1
    attempt=$((attempt + 1))
done

if command -v lipc-set-prop >/dev/null 2>&1; then
    lipc-set-prop -- com.lab126.powerd preventScreenSaver 0 >/dev/null 2>&1 || true
fi
if [ -x /etc/init.d/framework ]; then
    /etc/init.d/framework start >/dev/null 2>&1 || true
fi
rm -f "$pid_path"
log_message "Dashboard stop requested"

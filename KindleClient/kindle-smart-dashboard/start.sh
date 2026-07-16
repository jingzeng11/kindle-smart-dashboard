#!/bin/sh

set -u

extension_root=$(CDPATH= cd "$(dirname "$0")" && pwd)
. "$extension_root/lib.sh"

if [ -f "$pid_path" ]; then
    running_pid=$(sed -n '1p' "$pid_path")
    if kill -0 "$running_pid" 2>/dev/null; then
        log_message "Dashboard mode is already running"
        exit 0
    fi
    rm -f "$pid_path"
fi

nohup "$extension_root/run.sh" >> "$log_path" 2>&1 </dev/null &
log_message "Dashboard start requested"

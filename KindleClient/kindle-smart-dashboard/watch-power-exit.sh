#!/bin/sh

set -u

dashboard_pid=${1:-}
[ -n "$dashboard_pid" ] || exit 2
command -v lipc-wait-event >/dev/null 2>&1 || exit 0

lipc-wait-event -m com.lab126.powerd goingToScreenSaver 2>/dev/null | while IFS= read -r event; do
    case "$event" in
        *goingToScreenSaver*)
            if command -v lipc-set-prop >/dev/null 2>&1; then
                lipc-set-prop -i com.lab126.powerd abortSuspend 1 >/dev/null 2>&1 || true
            fi
            kill -TERM "$dashboard_pid" 2>/dev/null || true
            exit 0
            ;;
    esac
done

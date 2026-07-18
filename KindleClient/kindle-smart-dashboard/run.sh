#!/bin/sh

set -u

extension_root=$(CDPATH= cd "$(dirname "$0")" && pwd)
. "$extension_root/lib.sh"

cleanup_done=0
sleeper_pid=""
power_watcher_pid=""
notes_watcher_pid=""

restore_kindle() {
    [ "$cleanup_done" -eq 0 ] || return 0
    cleanup_done=1

    if [ -n "$sleeper_pid" ]; then
        kill "$sleeper_pid" 2>/dev/null || true
    fi
    if [ -n "$power_watcher_pid" ]; then
        kill "$power_watcher_pid" 2>/dev/null || true
    fi
    if [ -n "$notes_watcher_pid" ]; then
        kill "$notes_watcher_pid" 2>/dev/null || true
    fi
    rm -f "$pid_path"
    if command -v lipc-set-prop >/dev/null 2>&1; then
        lipc-set-prop -- com.lab126.powerd preventScreenSaver 0 >/dev/null 2>&1 || true
    fi
    resume_kindle_ui
    log_message "Dashboard mode stopped"
}

trap 'restore_kindle; exit 0' INT TERM
trap restore_kindle EXIT

printf '%s\n' "$$" > "$pid_path"
if command -v lipc-set-prop >/dev/null 2>&1; then
    lipc-set-prop -- com.lab126.powerd preventScreenSaver 1 >/dev/null 2>&1 || true
fi

# Give KUAL enough time to close its menu and return to Home before freezing
# the UI. The next eips draw then remains visible instead of being repainted.
sleep 2
pause_kindle_ui || true

# A short power-button press emits goingToScreenSaver. Treat it as a clean
# dashboard exit, cancel the pending suspend, and restore the Kindle UI.
if command -v lipc-wait-event >/dev/null 2>&1; then
    "$extension_root/watch-power-exit.sh" "$$" >> "$log_path" 2>&1 &
    power_watcher_pid=$!
fi

if [ -x "$notes_bin" ] && [ -r "$TOUCH_DEVICE" ]; then
    "$notes_bin" watch "$TOUCH_DEVICE" "$image_path" "$notes_path" "$$" >> "$log_path" 2>&1 &
    notes_watcher_pid=$!
    log_message "Local handwriting enabled on $TOUCH_DEVICE"
else
    log_message "Local handwriting unavailable"
fi

log_message "Dashboard mode started; refresh interval ${REFRESH_SECONDS}s"

while :; do
    refresh_dashboard || true
    sleep "$REFRESH_SECONDS" &
    sleeper_pid=$!
    wait "$sleeper_pid" || true
    sleeper_pid=""
done

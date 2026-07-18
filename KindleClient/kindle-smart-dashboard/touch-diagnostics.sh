#!/bin/sh

set -u

extension_root=$(CDPATH= cd "$(dirname "$0")" && pwd)
. "$extension_root/lib.sh"

report_path="$data_dir/touch-diagnostics.txt"
raw_path="$data_dir/touch-events.raw"

{
    echo "captured_at=$(date '+%Y-%m-%d %H:%M:%S')"
    echo "uname=$(uname -a 2>/dev/null || true)"
    echo "firmware=$(cat /etc/prettyversion.txt 2>/dev/null || true)"
    echo "framebuffer_virtual_size=$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null || true)"
    echo "framebuffer_bits_per_pixel=$(cat /sys/class/graphics/fb0/bits_per_pixel 2>/dev/null || true)"
    for tool in eips fbset hexdump od lipc-wait-event; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "tool_$tool=$(command -v "$tool")"
        fi
    done
    echo "--- input devices ---"
    cat /proc/bus/input/devices 2>/dev/null || true
    echo "--- framebuffer ---"
    fbset -i 2>/dev/null || true
} > "$report_path"

touch_handler=$(awk '
    BEGIN { RS="" }
    tolower($0) ~ /touch|cyttsp|zforce|elan/ {
        if (match($0, /event[0-9]+/)) {
            print substr($0, RSTART, RLENGTH)
            exit
        }
    }
' /proc/bus/input/devices 2>/dev/null)

if [ -z "$touch_handler" ]; then
    log_message "Touch diagnostics could not find a touchscreen input device"
    echo "touch_device=not_found" >> "$report_path"
    exit 1
fi

touch_device="/dev/input/$touch_handler"
echo "touch_device=$touch_device" >> "$report_path"
rm -f "$raw_path"

# Capture a bounded raw evdev sample while the user taps the four corners and
# draws across the screen. The capture contains no calendar or account data.
dd if="$touch_device" of="$raw_path" bs=16 count=4096 2>/dev/null &
capture_pid=$!
sleep 15
kill "$capture_pid" 2>/dev/null || true
wait "$capture_pid" 2>/dev/null || true

raw_size=$(wc -c < "$raw_path" 2>/dev/null | tr -d ' ')
echo "touch_raw_bytes=${raw_size:-0}" >> "$report_path"
log_message "Touch diagnostics captured ${raw_size:-0} bytes from $touch_device"

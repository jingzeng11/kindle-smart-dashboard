#!/bin/sh

extension_root=$(CDPATH= cd "$(dirname "$0")" && pwd)

. "$extension_root/config.sh"
if [ -f "$extension_root/config.local.sh" ]; then
    . "$extension_root/config.local.sh"
fi

data_dir=${DASHBOARD_DATA_DIR:-"$extension_root/data"}
image_path="$data_dir/dashboard.png"
temporary_path="$data_dir/dashboard.download"
pid_path="$data_dir/dashboard.pid"
ui_state_path="$data_dir/ui.state"
log_path=${DASHBOARD_LOG_FILE:-"$data_dir/dashboard.log"}
notes_path=${DASHBOARD_NOTES_FILE:-"$data_dir/handwriting.bin"}
notes_bin="$extension_root/bin/kindle-notes"

mkdir -p "$data_dir"

log_message() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$log_path"
}

pause_kindle_ui() {
    rm -f "$ui_state_path"
    paused_processes=""

    # On newer 5.x firmware the Java UI is supervised and an init-script stop
    # can be restarted immediately. Suspending cvm keeps the UI from repainting
    # over eips while leaving Wi-Fi and the dashboard worker alive.
    if command -v killall >/dev/null 2>&1 && killall -STOP cvm >/dev/null 2>&1; then
        paused_processes="cvm"
        if killall -STOP awesome >/dev/null 2>&1; then
            paused_processes="$paused_processes awesome"
        fi
        printf '%s\n' "$paused_processes" > "$ui_state_path"
        log_message "Kindle UI paused with $paused_processes"
        return 0
    fi

    if [ -x /etc/init.d/framework ]; then
        /etc/init.d/framework stop >/dev/null 2>&1 || return 1
        printf '%s\n' framework > "$ui_state_path"
        log_message "Kindle UI paused with framework"
        return 0
    fi

    log_message "Unable to pause Kindle UI"
    return 1
}

resume_kindle_ui() {
    pause_method=""
    if [ -f "$ui_state_path" ]; then
        pause_method=$(sed -n '1p' "$ui_state_path")
    fi

    # Remove the dashboard framebuffer before the stock UI starts repainting.
    # Otherwise X may only redraw damaged regions and leave dashboard fragments
    # mixed with Home or Library.
    if command -v eips >/dev/null 2>&1; then
        eips -c >/dev/null 2>&1 || true
    elif [ -x /usr/sbin/eips ]; then
        /usr/sbin/eips -c >/dev/null 2>&1 || true
    fi

    case "$pause_method" in
        cvm*)
            if command -v killall >/dev/null 2>&1; then
                for process_name in $pause_method; do
                    killall -CONT "$process_name" >/dev/null 2>&1 || true
                done
            fi
            ;;
        framework)
            [ -x /etc/init.d/framework ] && /etc/init.d/framework start >/dev/null 2>&1 || true
            ;;
        *)
            # Also recover safely after an interrupted upgrade or stale state.
            if command -v killall >/dev/null 2>&1; then
                killall -CONT awesome >/dev/null 2>&1 || true
                killall -CONT cvm >/dev/null 2>&1 || true
            fi
            ;;
    esac

    sleep 1
    if command -v lipc-set-prop >/dev/null 2>&1; then
        lipc-set-prop -- com.lab126.appmgrd start app://com.lab126.booklet.home >/dev/null 2>&1 || true
    fi

    rm -f "$ui_state_path"
}

find_eips() {
    if command -v eips >/dev/null 2>&1; then
        command -v eips
    elif [ -x /usr/sbin/eips ]; then
        printf '%s\n' /usr/sbin/eips
    else
        return 1
    fi
}

read_battery_level() {
    battery_level=""
    if command -v lipc-get-prop >/dev/null 2>&1; then
        battery_level=$(lipc-get-prop com.lab126.powerd battLevel 2>/dev/null || true)
    elif command -v gasgauge-info >/dev/null 2>&1; then
        battery_level=$(gasgauge-info -c 2>/dev/null || true)
    fi

    battery_level=$(printf '%s' "$battery_level" | tr -cd '0-9')
    [ -n "$battery_level" ] || return 1
    battery_level=$(printf '%s' "$battery_level" | sed 's/^0*//')
    [ -n "$battery_level" ] || battery_level=0
    if [ "$battery_level" -ge 0 ] 2>/dev/null && [ "$battery_level" -le 100 ] 2>/dev/null; then
        printf '%s\n' "$battery_level"
        return 0
    fi
    return 1
}

dashboard_download_url() {
    battery_level=$(read_battery_level) || {
        printf '%s\n' "$DASHBOARD_URL"
        return 0
    }
    case "$DASHBOARD_URL" in
        *\?*) printf '%s&battery=%s\n' "$DASHBOARD_URL" "$battery_level" ;;
        *) printf '%s?battery=%s\n' "$DASHBOARD_URL" "$battery_level" ;;
    esac
}

download_dashboard() {
    rm -f "$temporary_path"
    download_url=$(dashboard_download_url)
    if command -v curl >/dev/null 2>&1; then
        curl -fsS --connect-timeout 15 --max-time 60 -o "$temporary_path" "$download_url"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -T 60 -O "$temporary_path" "$download_url"
    else
        log_message "Neither curl nor wget is available"
        return 1
    fi

    if [ ! -s "$temporary_path" ]; then
        log_message "Downloaded dashboard is empty"
        rm -f "$temporary_path"
        return 1
    fi

    signature=$(dd if="$temporary_path" bs=8 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')
    if [ "$signature" != "89504e470d0a1a0a" ]; then
        log_message "Downloaded dashboard is not a PNG"
        rm -f "$temporary_path"
        return 1
    fi

    mv "$temporary_path" "$image_path"
    return 0
}

display_dashboard() {
    eips_bin=$(find_eips) || {
        log_message "eips is not available"
        return 1
    }
    "$eips_bin" -c
    "$eips_bin" -g "$image_path"
    if [ -x "$notes_bin" ]; then
        "$notes_bin" redraw "$notes_path" >> "$log_path" 2>&1 || \
            log_message "Handwriting redraw failed"
    fi
}

refresh_dashboard() {
    if download_dashboard; then
        if display_dashboard; then
            log_message "Dashboard refreshed"
            return 0
        fi
    fi
    log_message "Refresh failed; keeping the current screen"
    return 1
}

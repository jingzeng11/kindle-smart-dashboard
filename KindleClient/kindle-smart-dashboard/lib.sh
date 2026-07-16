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

mkdir -p "$data_dir"

log_message() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$log_path"
}

pause_kindle_ui() {
    rm -f "$ui_state_path"

    # On newer 5.x firmware the Java UI is supervised and an init-script stop
    # can be restarted immediately. Suspending cvm keeps the UI from repainting
    # over eips while leaving Wi-Fi and the dashboard worker alive.
    if command -v killall >/dev/null 2>&1 && killall -STOP cvm >/dev/null 2>&1; then
        printf '%s\n' cvm > "$ui_state_path"
        log_message "Kindle UI paused with cvm"
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

    case "$pause_method" in
        cvm)
            command -v killall >/dev/null 2>&1 && killall -CONT cvm >/dev/null 2>&1 || true
            ;;
        framework)
            [ -x /etc/init.d/framework ] && /etc/init.d/framework start >/dev/null 2>&1 || true
            ;;
        *)
            # Also recover safely after an interrupted upgrade or stale state.
            command -v killall >/dev/null 2>&1 && killall -CONT cvm >/dev/null 2>&1 || true
            ;;
    esac

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

download_dashboard() {
    rm -f "$temporary_path"
    if command -v curl >/dev/null 2>&1; then
        curl -fsS --connect-timeout 15 --max-time 60 -o "$temporary_path" "$DASHBOARD_URL"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -T 60 -O "$temporary_path" "$DASHBOARD_URL"
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

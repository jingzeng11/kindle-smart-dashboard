#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
source_path="$project_root/KindleClient/native/kindle-notes.c"
output_dir="$project_root/KindleClient/kindle-smart-dashboard/bin"
output_path="$output_dir/kindle-notes"
zig_bin="${ZIG_BIN:-zig}"
export ZIG_GLOBAL_CACHE_DIR="${ZIG_GLOBAL_CACHE_DIR:-$project_root/.build/zig-global-cache}"
export ZIG_LOCAL_CACHE_DIR="${ZIG_LOCAL_CACHE_DIR:-$project_root/.build/zig-local-cache}"

mkdir -p "$output_dir"
"$zig_bin" cc \
    -target arm-linux-musleabihf \
    -mcpu=arm1176jzf_s \
    -Os \
    -static \
    -s \
    "$source_path" \
    -o "$output_path"
chmod 0755 "$output_path"
file "$output_path"

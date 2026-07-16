#!/bin/sh

set -u

extension_root=$(CDPATH= cd "$(dirname "$0")" && pwd)
. "$extension_root/lib.sh"

refresh_dashboard

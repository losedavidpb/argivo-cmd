#!/usr/bin/env bash
#
# log.bash - logging utilities for argivo

set -Eeuo pipefail

# Write a log entry to stdout or a file.
# Usage: argivo::log <status> <message> [<file>]
function argivo::log() {
    (($# >= 2)) || { return 1; }

    local status="$1"
    shift

    local logfile=""
    local message="$*"

    # If the last argument looks like a log file,
    # treat it as the output destination
    if (($# >= 2)); then
        logfile="${!#}"
        message="${*:1:$#-1}"
    fi

    local entry

    # Format the log entry with a timestamp and status
    entry="$(printf '[%s] %s : %s' \
        "$status" \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$message")"

    # If no log file is provided, print the log entry to stdout
    if [[ -z "$logfile" ]]; then
        printf '%s\n' "$entry"
        return 0
    fi

    # Write the log entry to the file
    touch "$logfile" 2>/dev/null || return 1
    printf '%s\n' "$entry" >> "$logfile"
}
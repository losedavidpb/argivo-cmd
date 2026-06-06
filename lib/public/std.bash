#!/usr/bin/env bash
#
# std.bash - standard library for argivo
#
# This library provides a collection of public utility
# functions that are automatically available to all
# argivo scripts.

set -Eeuo pipefail

# Show an error message and exit
# Usage: argivo::error <message>
function argivo::error() {
    (($# >= 1)) || { return 1; }
    echo "error: $*" >&2
    exit 1
}

# Show a warning message
# Usage: argivo::warning <message>
function argivo::warning() {
    (($# >= 1)) || { return 1; }
    echo "warning: $*" >&2
}

# Show an informational message
# Usage: argivo::info <message>
function argivo::info() {
    (($# >= 1)) || { return 1; }
    echo "info: $*" >&2
}

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
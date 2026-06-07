#!/usr/bin/env bash
#
# type.bash - type checking utilities for argivo

set -Eeuo pipefail

# Check whether a value is a valid number
# Usage: argivo::is_number <number>
function argivo::is_number() {
    (($# == 1)) || return 1
    [[ "$1" =~ ^-?[0-9]+([.][0-9]+)?$ ]]
}

# Check whether a value is a boolean
# Usage: argivo::is_boolean <value>
function argivo::is_boolean() {
    (($# == 1)) || return 1

    # Accepted values are based on common
    # boolean representations in Bash
    case "${1,,}" in
        true|false|1|0) return 0 ;;
        *) return 1 ;;
    esac
}

# Check whether a path exists
# Usage: argivo::is_path <path>
function argivo::is_path() {
    (($# == 1)) || return 1
    [[ -e "$1" ]]
}

# Check whether a path is a file
# Usage: argivo::is_file <path>
function argivo::is_file() {
    (($# == 1)) || return 1
    [[ -f "$1" ]]
}

# Check whether a path is a directory
# Usage: argivo::is_directory <path>
function argivo::is_directory() {
    (($# == 1)) || return 1
    [[ -d "$1" ]]
}

# Check whether a command is available
# Usage: argivo::is_command <name>
function argivo::is_command() {
    (($# == 1)) || return 1
    command -v "$1" >/dev/null 2>&1
}
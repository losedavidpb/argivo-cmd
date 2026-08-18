#!/usr/bin/env bash
#
# type.bash - type checking utilities for argivo

set -Eeuo pipefail

# Check whether a value is of a specific type
# Usage: argivo::is_type <value> <type>
function argivo::is_type() {
    (($# == 2)) || return 1

    # Check that the provided type is supported
    argivo::is_valid_type "$2" || return 1

    # Use the appropriate validator function
    # for the specified type
    local validator="argivo::is_$2"
    "$validator" "$1"
}

# Check whether a type is valid
# Usage: argivo::is_valid_type <type>
function argivo::is_valid_type() {
    (($# == 1)) || return 1

    # Only allow safe type names
    [[ $1 =~ ^[a-z][a-z0-9_]*$ ]] || return 1

    # Prevent argivo::is_type from being treated
    # as the validator for a type named "type"
    [[ $1 != "type" ]] || return 1

    declare -F "argivo::is_$1" >/dev/null
}

# Check whether a value is text
# Usage: argivo::is_text <value>
function argivo::is_text() {
    (($# == 1)) || return 1
    return 0
}

# Check whether a value is a valid number
# Usage: argivo::is_number <number>
function argivo::is_number() {
    (($# == 1)) || return 1
    [[ "$1" =~ ^-?[0-9]+([.][0-9]+)?$ ]]
}

# Check whether a value is a natural number
# Usage: argivo::is_natural <value>
function argivo::is_natural() {
    (($# == 1)) || return 1
    [[ "$1" =~ ^[0-9]+$ ]]
}

# Check whether a value is an integer
# Usage: argivo::is_integer <value>
function argivo::is_integer() {
    (($# == 1)) || return 1
    [[ "$1" =~ ^-?[0-9]+$ ]]
}

# Check whether a value is a float
# Usage: argivo::is_float <value>
function argivo::is_float() {
    (($# == 1)) || return 1
    [[ "$1" =~ ^-?[0-9]+\.[0-9]+$ ]]
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
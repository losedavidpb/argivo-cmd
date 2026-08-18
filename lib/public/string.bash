#!/usr/bin/env bash
#
# string.bash - string manipulation utilities for argivo

set -Eeuo pipefail

# Truncate a string to a specified length
# Usage: argivo::truncate <string> <length>
function argivo::truncate() {
    (($# == 2)) || return 1

    # String to truncate and the desired length
    local string="$1"
    local length="$2"

    # Check that the length is a valid number
    if ! argivo::is_natural "$length"; then
        printf 'error: length must be a natural number\n' >&2
        return 1
    fi

    # Truncate the string to the specified length
    printf '%s\n' "${string:0:length}"
}

# Trim leading and trailing whitespace from a string
# Usage: argivo::trim <string>
function argivo::trim() {
    (($# == 1)) || return 1

    local value="${1#"${1%%[![:space:]]*}"}"
    printf '%s\n' "${value%"${value##*[![:space:]]}"}"
}

# Convert a string to lowercase
# Usage: argivo::lower <string>
function argivo::lower() {
    (($# == 1)) || return 1
    printf '%s\n' "${1,,}"
}

# Convert a string to uppercase
# Usage: argivo::upper <string>
function argivo::upper() {
    (($# == 1)) || return 1
    printf '%s\n' "${1^^}"
}

# Capitalize the first letter of a string
# Usage: argivo::capitalize <string>
function argivo::capitalize() {
    (($# == 1)) || return 1
    printf '%s\n' "${1^}"
}

# Uncapitalize the first letter of a string
# Usage: argivo::uncapitalize <string>
function argivo::uncapitalize() {
    (($# == 1)) || return 1
    printf '%s\n' "${1,}"
}

# Check whether a string starts with a specific substring
# Usage: argivo::starts_with <string> <substring>
function argivo::starts_with() {
    (($# == 2)) || return 1
    [[ "$1" == "$2"* ]]
}

# Check whether a string ends with a specific substring
# Usage: argivo::ends_with <string> <substring>
function argivo::ends_with() {
    (($# == 2)) || return 1
    [[ "$1" == *"$2" ]]
}

# Check whether a string contains a substring
# Usage: argivo::contains <string> <substring>
function argivo::contains() {
    (($# == 2)) || return 1
    [[ "$1" == *"$2"* ]]
}

# Replace occurrences of a substring with another substring
# Usage: argivo::replace <string> <old> <new>
function argivo::replace() {
    (($# == 3)) || return 1

    # String to modify, substring to replace,
    # and replacement substring
    local string="$1"
    local old="$2"
    local new="$3"

    # If the substring to replace is empty,
    # return the original string unchanged
    if [[ -z "$old" ]]; then
        printf '%s\n' "$string"
        return 0
    fi

    # Initialize an empty result string
    # and a prefix variable
    local result=''
    local prefix

    # Loop until there are no more occurrences
    # of the substring to replace
    while [[ "$string" == *"$old"* ]]; do
        prefix="${string%%"$old"*}"
        result+="$prefix$new"
        string="${string#*"$old"}"
    done

    printf '%s\n' "$result$string"
}

# Repeat a string a specified number of times
# Usage: argivo::repeat <string> <count>
function argivo::repeat() {
    (($# == 2)) || return 1

    # String to repeat and the number of repetitions
    local string="$1"
    local count="$2"

    # Check that the count is a valid number
    if ! argivo::is_natural "$count"; then
        printf 'error: count must be a natural number\n' >&2
        return 1
    fi

    # Repeat the string the specified number of times
    for ((i = 0; i < count; i++)); do
        printf '%s' "$string"
    done

    printf '\n'
}

# Join multiple strings with a specified separator
# Usage: argivo::join <separator> <string1> [string2 ...]
function argivo::join() {
    (($# >= 2)) || return 1

    # Separator and the initial result string
    local separator="$1"; shift
    local result="$1"; shift

    # Append each string to the result,
    # separated by the specified separator
    for value in "$@"; do
        result+="${separator}${value}"
    done

    printf '%s\n' "$result"
}

# Split a string using a single-character separator
# Usage: argivo::split <separator> <string>
function argivo::split() {
    (($# == 2)) || return 1

    # Separator and the string to split
    local separator="$1"
    local string="$2"

    # The separator must be exactly one non-empty character
    if ((${#separator} != 1)); then
        printf 'error: separator must be a single character\n' >&2
        return 1
    fi

    # Loop until there are no more occurrences of the separator
    while [[ "$string" == *"$separator"* ]]; do
        printf '%s\n' "${string%%"$separator"*}"
        string="${string#*"$separator"}"
    done

    printf '%s\n' "$string"
}

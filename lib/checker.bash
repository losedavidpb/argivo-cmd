#!/usr/bin/env bash
#
# checker.bash - checker script for argivo
#
# This script includes a lightweight command-line checker that
# validates the syntax of an argivo script.
#
# The interpreter checks the following aspects of the script:
#   - The script exists and is readable
#   - The script does use the correct argivo shebang
#   - All command names and aliases are valid and unique
#   - The script defines a main function

set -Eeuo pipefail

# Check the syntax of an argivo script and its commands
function argivo::check() {
    if (($# == 0)); then
        echo "error: no script provided for checking"
        echo "usage: argivo --check <script>"
        exit 1
    fi

    local script="$1"
    shift

    # Verbose mode is disabled by default, as the interpreter uses it
    # when executing a script, and it may be too verbose for regular checks
    local verbose=false

    # Check the verbose mode
    if [[ "${1:-}" == "--verbose" ]]; then
        verbose=true
        shift
    fi

    if [[ "$verbose" == "true" ]]; then
        echo "Checking $(basename "$script")..."
    fi

    # Check that the script exists
    if [[ ! -f "$script" ]]; then
        echo "error: script not found"
        exit 1
    fi

    # Check that the script is readable
    if [[ ! -r "$script" ]]; then
        echo "error: script is not readable"
        exit 1
    fi

    # Check that the script is a valid argivo script
    if ! argivo::is_argivo_script "$script"; then
        exit 1
    fi

    # Check that all functions in the script have unique names
    if ! argivo::check_commands "$script"; then
        echo "error: duplicate functions found"
        exit 1
    fi

    # Check that all command aliases in the script have unique names
    if ! argivo::check_aliases "$script"; then
        echo "error: duplicate command aliases found"
        exit 1
    fi

    # Show syntax validation results
    if [[ "$verbose" == "true" ]]; then
        echo
        echo "✓ Script is readable"
        echo "✓ Script is a valid argivo script"
        echo "✓ All command names are valid"
        echo "✓ All command aliases are unique"

        echo
        echo "No issues found"
    fi

    return 0
}

# Check if a script is a valid argivo script
function argivo::is_argivo_script() {
    local script="$1"

    # Check for the presence of the argivo shebang
    if ! head -n 1 "$script" | grep -q '^#!/usr/bin/env argivo'; then
        echo "error: missing argivo shebang"
        return 1
    fi

    # Check for the presence of the main function
    if ! grep -Eq '^[[:space:]]*(function[[:space:]]+)?main[[:space:]]*(\(\))?' "$script"; then
        echo "error: missing main function"
        return 1
    fi

    # Check for the presence of at least one user-defined command
    if ! grep -Eq '^[[:space:]]*(function[[:space:]]+)?[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(\(\))?' "$script"; then
        echo "error: missing at least one user-defined command"
        return 1
    fi

    return 0
}

# Check that all functions in the script have unique names
function argivo::check_commands() {
    local script="$1"

    local duplicates

    duplicates="$(
        grep -E '^[[:space:]]*function[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)' "$script" |
        sed -E 's/^[[:space:]]*function[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*).*/\1/' |
        sort |
        uniq -d
    )"

    [[ -z "$duplicates" ]]
}

# Check that all command aliases in the script have unique names
function argivo::check_aliases() {
    local script="$1"

    local duplicates

    duplicates="$(
        grep -E '^[[:space:]]*#[[:space:]]*@alias[[:space:]]+' "$script" |
        sed -E 's/.*@alias[[:space:]]+//' | sort | uniq -d
    )"

    [[ -z "$duplicates" ]]
}
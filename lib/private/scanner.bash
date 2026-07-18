#!/usr/bin/env bash
#
# scanner.bash - structural scanner for Argivo scripts

set -Eeuo pipefail

# Prevent loading this module more than once
[[ -n "${_ARGIVO_SCANNER_LOADED:-}" ]] && return 0
_ARGIVO_SCANNER_LOADED=true

# Extract a function name from a declaration
function _argivo::get_function_name() {
    local line="$1"

    local result=""

    # Function definitions that use the "function" keyword
    if [[ "$line" =~ $_ARGIVO_REGEX_FUNCTION_1 ]]; then
        result="${BASH_REMATCH[1]}"

    # Function definitions that do not use the "function" keyword
    elif [[ "$line" =~ $_ARGIVO_REGEX_FUNCTION_2 ]]; then
        result="${BASH_REMATCH[1]}"
    fi

    echo "$result"
}

# Consume the opening brace expected after a function declaration
function _argivo::consume_open_brace() {
    local line="$1"
    local -n waiting_ref="$2"
    local -n depth_ref="$3"

    # This line resolves the pending opening-brace
    # state, whether valid or not
    waiting_ref=false

    # A valid standalone opening brace starts the function body
    if [[ "$line" =~ $_ARGIVO_REGEX_OPEN_BRACE ]]; then
        depth_ref=1
        return 0
    fi

    return 1
}

# Enter a function body and initialize its structural state
function _argivo::start_function_section() {
    local line="$1"
    local -n section_ref="$2"
    local -n waiting_ref="$3"
    local -n depth_ref="$4"

    # Enter the function section and initialize
    # its brace-tracking state
    section_ref=true
    waiting_ref=false
    depth_ref=0

    # An inline opening brace starts the body immediately
    if [[ "$line" == *"{"* ]]; then
        depth_ref=1

    # The opening brace must appear on the next non-blank line
    else
        # shellcheck disable=SC2034
        waiting_ref=true
    fi

    return 0
}

# Update a function section while scanning one line
function _argivo::update_function_section() {
    local line="$1"
    local section_name="$2"
    local depth_name="$3"

    local -n section_ref="$section_name"
    local -n depth_ref="$depth_name"

    # Only active function bodies affect brace depth
    [[ "$section_ref" != true ]] && return 0

    # Update the brace depth based on current line
    _argivo::update_brace_depth "$line" "$depth_name"

    # Depth zero ends the section
    ((depth_ref == 0)) && section_ref=false

    return 0
}

# Update brace depth while ignoring braces inside strings or comments
function _argivo::update_brace_depth() {
    local line="$1"
    local -n depth_ref="$2"
    local i c previous
    local in_single=false
    local in_double=false
    local escaped=false

    for ((i=0; i<${#line}; i++)); do
        c="${line:i:1}"

        # Ignore everything inside single-quoted strings
        if $in_single; then
            [[ "$c" == "'" ]] && in_single=false
            continue
        fi

        # Ignore everything inside double-quoted strings,
        # taking escaped characters into account
        if $in_double; then
            if $escaped; then
                escaped=false
                continue
            fi

            # Track escape sequences and detect the closing quote
            case "$c" in
                \\)  escaped=true    ;;
                '"') in_double=false ;;
            esac

            continue
        fi

        # A comment starts only when '#' begins a shell word.
        # Keep parameter expansion operators such as ${#value} intact
        if [[ "$c" == "#" ]]; then
            # A hash at the beginning of the
            # line always starts a comment
            ((i == 0)) && break

            # Inspect the preceding character to
            # detect a new shell word
            previous="${line:i-1:1}"

            # Whitespace and shell metacharacters
            # delimit the previous word
            case "$previous" in
                [[:space:]]|"&"|"("|")"|";"|"<"|">"|"|") break ;;
            esac
        fi

        # Handle quote delimiters and update the brace depth
        case "$c" in
            "'") in_single=true     ;;
            '"') in_double=true     ;;
            "{") ((depth_ref++))    ;;
            "}") ((depth_ref--))    ;;
        esac
    done

    return 0
}

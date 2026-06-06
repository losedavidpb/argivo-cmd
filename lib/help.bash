#!/usr/bin/env bash
#
# help.bash - help script for argivo
#
# This script provides a default "help" command for argivo scripts,
# which lists all available commands and their descriptions.

set -Eeuo pipefail

# Print help information for the user-defined commands
function argivo::help_user() {
    local script_name

    # Script was already defined in argivo, so
    # it is safe to use it here without checking for existence
    # shellcheck disable=SC2154
    script_name="$(basename "$script")"

    # Load descriptions if not already loaded
    if ! $ARGIVO_ANNOTATIONS_LOADED; then
        argivo::load_annotations
        ARGIVO_ANNOTATIONS_LOADED=true
    fi

    # If a specific command is provided, show help for that command
    if [[ -n "${1:-}" ]]; then
        argivo::help_command "$script_name" "$1"
        return
    fi

    echo "Usage: $script_name <COMMAND> [ARGS...]"
    echo "$ARGIVO_SCRIPT_DESCRIPTION"
    echo

    echo "Available commands:"

    while read -r command; do
        printf "  %-20s %s\n" \
            "$(argivo::usage "$command")" \
            "${ARGIVO_DESCRIPTIONS[$command]:-No description}"
    done < <(argivo::commands)
}

# Generate usage string for a given command based on its parameters
function argivo::usage() {
    local command="$1"
    local alias_cmd

    local usage="--$command"

    alias_cmd="$(argivo::get_alias "$command" 2>/dev/null || true)"

    # Functions may not always have aliases
    if [[ -n "$alias_cmd" ]]; then
        usage="-$alias_cmd, --$command"
    fi

    local param

    # Add parameters to the usage string if they exist
    for param in ${ARGIVO_PARAMS[$command]:-}; do
        usage+=" [$param]"
    done

    printf '%s\n' "$usage"
}

# Print detailed help information for a specific command
function argivo::help_command() {
    local script_name="$1"
    local command="$2"

    # Resolve aliases to their real function names
    if [[ -n "${ARGIVO_ALIASES[$command]:-}" ]]; then
        command="${ARGIVO_ALIASES[$command]}"
    fi

    # Check that the command exists
    if [[ -z "${ARGIVO_DESCRIPTIONS[$command]:-}" ]]; then
        echo "error: unknown command: $command"
        return 1
    fi

    # Usage message
    echo "Usage: $script_name $(argivo::usage "$command")"
    echo "${ARGIVO_DESCRIPTIONS[$command]}"

    # Show parameters and their descriptions
    if [[ -n "${ARGIVO_PARAMS[$command]:-}" ]]; then
        echo
        echo "Arguments:"

        local param

        for param in ${ARGIVO_PARAMS[$command]}; do
            printf "  %-15s %s\n" \
                "$param" \
                "${ARGIVO_PARAM_DESCRIPTIONS["$command:$param"]:-}"
        done
    fi

    # Show examples for the command
    if [[ -n "${ARGIVO_EXAMPLES[$command]:-}" ]]; then
        echo
        echo "Examples:"

        while IFS= read -r example; do
            [[ -z "$example" ]] && continue

            printf "  %s %s %s\n" \
                "$script_name" \
                "$(argivo::usage "$command" | sed 's/ \[[^]]*\]//g')" \
                "$example"
        done <<< "${ARGIVO_EXAMPLES[$command]}"
    fi
}
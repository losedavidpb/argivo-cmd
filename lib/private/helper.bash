#!/usr/bin/env bash
#
# help.bash - automatic help script for argivo

set -Eeuo pipefail

# Print help information for the user-defined commands
function _argivo::help_script() {
    local script_name

    # Script was already defined in argivo, so
    # it is safe to use it here without checking for existence
    # shellcheck disable=SC2154
    script_name="$(basename "$_script")"

    # Load descriptions if not already loaded
    if ! $_ARGIVO_ANNOTATIONS_LOADED; then
        _argivo::load_annotations
    fi

    # If a specific command is provided, show help for that command
    if [[ -n "${1:-}" ]]; then
        _argivo::help_cmd "$script_name" "$1"
        return
    fi

    # Usage message
    echo "Usage: $script_name <COMMAND> [ARGS...]"
    echo "$_ARGIVO_SCRIPT_DESCRIPTION"

    # Available commands
    commands="$(_argivo::get_commands)"

    if [[ -n "$commands" ]]; then
        echo
        echo "Available commands:"

        while read -r command; do
            printf "  %-20s %s\n" \
                "$(_argivo::usage "$command")" \
                "${_ARGIVO_DESCRIPTIONS[$command]:-No description}"
        done <<< "$commands"
    fi

    # Mutually exclusive commands
    exclusions="$(_argivo::get_exclusions)"

    if [[ -n "$exclusions" ]]; then
        echo
        echo "Mutually exclusive commands:"

        while read -r group; do
            commands=()

            # Prepares commands for current group
            for function_name in "${!_ARGIVO_FUNCTION_EXCLUSIONS[@]}"; do
                for function_group in ${_ARGIVO_FUNCTION_EXCLUSIONS[$function_name]}; do
                    if [[ "$function_group" == "$group" ]]; then
                        commands+=("--$function_name")
                    fi
                done
            done

            printf "  %-20s %s\n" "@$group" "${commands[*]}"
        done <<< "$exclusions"
    fi
}

# Print detailed help information for a specific command
function _argivo::help_cmd() {
    local script_name="$1"
    local command="$2"

    # Resolve aliases to their real function names
    if [[ -n "${_ARGIVO_ALIASES[$command]:-}" ]]; then
        command="${_ARGIVO_ALIASES[$command]}"
    fi

    # Check that the command exists
    if [[ -z "${_ARGIVO_DESCRIPTIONS[$command]:-}" ]]; then
        echo "error: unknown command: $command"
        return 1
    fi

    # Usage message
    echo "Usage: $script_name $(_argivo::usage "$command")"
    echo "${_ARGIVO_DESCRIPTIONS[$command]}"

    # Show parameters and their descriptions
    if [[ -n "${_ARGIVO_PARAMS[$command]:-}" ]]; then
        echo
        echo "Arguments:"

        local param

        for param in ${_ARGIVO_PARAMS[$command]}; do
            printf "  %-15s %s\n" \
                "$param" \
                "${_ARGIVO_PARAM_DESCRIPTIONS["$command:$param"]:-}"
        done
    fi

    # Show examples for the command
    if [[ -n "${_ARGIVO_EXAMPLES[$command]:-}" ]]; then
        echo
        echo "Examples:"

        while IFS= read -r example; do
            [[ -z "$example" ]] && continue

            printf "  %s %s %s\n" \
                "$script_name" \
                "$(_argivo::usage "$command" | sed 's/ \[[^]]*\]//g')" \
                "$example"
        done <<< "${_ARGIVO_EXAMPLES[$command]}"
    fi

    # Show exclusions for the command
    if [[ -n "${_ARGIVO_FUNCTION_EXCLUSIONS[$command]:-}" ]]; then
        echo
        echo "Mutually exclusive with:"

        local exclusion
        local function_name
        local commands

        for exclusion in ${_ARGIVO_FUNCTION_EXCLUSIONS[$command]}; do
            commands=()

            for function_name in "${!_ARGIVO_FUNCTION_EXCLUSIONS[@]}"; do
                [[ "$function_name" == "$command" ]] && continue

                for function_group in ${_ARGIVO_FUNCTION_EXCLUSIONS[$function_name]}; do
                    if [[ "$function_group" == "$exclusion" ]]; then
                        commands+=("--$function_name")
                    fi
                done
            done

            printf "  %-15s %s\n" "@$exclusion" "${commands[*]}"
        done
    fi
}

# Generate usage string for a given command based on its parameters
function _argivo::usage() {
    local command="$1"
    local alias_cmd

    local usage="--$command"

    alias_cmd="$(_argivo::get_alias "$command" 2>/dev/null || true)"

    # Functions may not always have aliases
    if [[ -n "$alias_cmd" ]]; then
        usage="-$alias_cmd, --$command"
    fi

    local param

    # Add parameters to the usage string if they exist
    for param in ${_ARGIVO_PARAMS[$command]:-}; do
        usage+=" [$param]"
    done

    printf '%s\n' "$usage"
}
#!/usr/bin/env bash
#
# help.bash - automatic help script for argivo

set -Eeuo pipefail

# Prevent loading this module more than once
[[ -n "${_ARGIVO_HELPER_LOADED:-}" ]] && return 0
_ARGIVO_HELPER_LOADED=true

# Print help information for the user-defined commands
function _argivo::help_script() {
    local script_name

    # Iteration variables used to build command groups
    local command
    local group

    local function_name
    local function_group

    # Required command in the current dependency list
    local required

    # Generated lists displayed in each help section
    local command_list
    local exclusion_list
    local requirement_list

    # Commands collected for the current
    # exclusion or requirement entry
    local -a grouped_commands=()
    local -a requirements=()

    # Script was already defined in argivo, so
    # it is safe to use it here without checking for existence
    # shellcheck disable=SC2154
    script_name="$(basename "$_script")"

    # If a specific command is provided, show help for that command
    if [[ -n "${1:-}" ]]; then
        _argivo::help_cmd "$script_name" "$1"
        return 0
    fi

    # Usage message
    echo "Usage: $script_name <COMMAND> [ARGS...]"
    echo "$_ARGIVO_SCRIPT_DESCRIPTION"

    # Show documentation for main if it is documented
    _argivo::print_help "$script_name" "main"

    # Available commands
    command_list="$(_argivo::get_commands)"

    # Show the available commands of the script
    if [[ -n "$command_list" ]]; then
        echo
        echo "Available commands:"

        # Include each command with its usage and description
        while read -r command; do
            local usage
            local description

            # Prepare the usage and description message
            usage="$(_argivo::usage "$command")"
            description="${_ARGIVO_DESCRIPTIONS[$command]:-No description}"

            printf "  %-20s %s\n" "$usage" "$description"
        done <<< "$command_list"
    fi

    # Mutually exclusive commands
    exclusion_list="$(_argivo::get_exclusions)"

    if [[ -n "$exclusion_list" ]]; then
        echo
        echo "Mutually exclusive commands:"

        while read -r group; do
            grouped_commands=()

            # Prepares commands for current group
            for function_name in "${!_ARGIVO_EXCLUSIONS[@]}"; do
                for function_group in ${_ARGIVO_EXCLUSIONS[$function_name]}; do
                    if [[ "$function_group" == "$group" ]]; then
                        grouped_commands+=("--$function_name")
                    fi
                done
            done

            printf "  %-20s %s\n" "@$group" "${grouped_commands[*]}"
        done <<< "$exclusion_list"
    fi

    # Required commands
    requirement_list="$(_argivo::get_requires)"

    if [[ -n "$requirement_list" ]]; then
        echo
        echo "Required commands:"

        while read -r command; do
            requirements=()

            # Prepares required commands for current function
            for required in ${_ARGIVO_REQUIRES[$command]}; do
                requirements+=("--$required")
            done

            printf "  %-20s %s\n" "--$command" "${requirements[*]}"
        done <<< "$requirement_list"
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
    if [[ -z "${_ARGIVO_COMMANDS[$command]:-}" ]]; then
        echo "error: unknown command: $command"
        return 1
    fi

    # Hidden commands cannot be executed directly
    if [[ "${_ARGIVO_HIDDEN[$command]:-false}" == "true" ]]; then
        echo "error: unknown command: $command"
        return 1
    fi

    # Private commands cannot be executed directly
    if [[ "$command" == _* || "$command" == argivo::* ]]; then
        echo "error: unknown command: $command"
        return 1
    fi

    # Usage message
    echo "Usage: $script_name $(_argivo::usage "$command")"

    # Show the description for the script
    if [[ "$command" == "main" ]]; then
        echo "$_ARGIVO_SCRIPT_DESCRIPTION"

    # Description for a specific command
    else
        echo "${_ARGIVO_DESCRIPTIONS[$command]:-No description}"
    fi

    _argivo::print_help "$script_name" "$command"
}

# Print command documentation (without header)
function _argivo::print_help() {
    local script_name="$1"
    local command="$2"

    local example
    local function_group

    # Show parameters and their properties
    if [[ -n "${_ARGIVO_PARAMS[$command]:-}" ]]; then
        echo
        echo "Arguments:"

        # Length of the longest parameter description
        local max_descr
        max_descr="$(_argivo::max_param_description_length "$command")"

        # Add some spacing before metadata
        max_descr=$((max_descr + 4))

        local param

        # Include each parameter and its metadata
        for param in ${_ARGIVO_PARAMS[$command]}; do
            local key="$command:$param"
            local meta=""

            # Add parameter type if it is not the default text type
            local type="${_ARGIVO_PARAM_TYPES[$key]:-}"
            [[ -n "$type" ]] && meta="type=$type"

            # Add default value to the parameter metadata
            if [[ -n "${_ARGIVO_PARAM_DEFAULTS[$key]:-}" ]]; then
                meta="${meta:+$meta, }default=${_ARGIVO_PARAM_DEFAULTS[$key]}"
            fi

            # Add optional flag to the parameter metadata
            if [[ "${_ARGIVO_PARAM_OPTIONAL[$key]:-false}" == "true" ]]; then
                meta="${meta:+$meta, }optional"
            fi

            # Parameter with additional metadata
            if [[ -n "$meta" ]]; then
                printf "  %-12s %-*s [%s]\n" \
                    "$param" "$max_descr" \
                    "${_ARGIVO_PARAM_DESCRIPTIONS[$key]:-}" \
                    "$meta"

            # Paramater without additional metadata
            else
                printf "  %-12s %s\n" \
                    "$param" \
                    "${_ARGIVO_PARAM_DESCRIPTIONS[$key]:-}"
            fi
        done
    fi

    # Show examples for the command
    if [[ -n "${_ARGIVO_EXAMPLES[$command]:-}" ]]; then
        echo
        echo "Examples:"

        while IFS= read -r example; do
            [[ -z "$example" ]] && continue

            # If the command is "main", show the script
            # name and example
            if [[ "$command" == "main" ]]; then
                printf "  %s %s\n" \
                    "$script_name" \
                    "$example"

            # If the command is not "main", show the
            # usage string for the command
            else
                printf "  %s %s %s\n" \
                    "$script_name" \
                    "$(_argivo::usage "$command" | sed 's/ \[[^]]*\]//g')" \
                    "$example"
            fi
        done <<< "${_ARGIVO_EXAMPLES[$command]}"
    fi

    # Show exclusions for the command
    if [[ -n "${_ARGIVO_EXCLUSIONS[$command]:-}" ]]; then
        echo
        echo "Mutually exclusive with:"

        local exclusion

        # Include all the commands of the @excl annotation
        for exclusion in ${_ARGIVO_EXCLUSIONS[$command]}; do
            local commands=()
            local function_name

            for function_name in "${!_ARGIVO_EXCLUSIONS[@]}"; do
                [[ "$function_name" == "$command" ]] && continue

                for function_group in ${_ARGIVO_EXCLUSIONS[$function_name]}; do
                    if [[ "$function_group" == "$exclusion" ]]; then
                        commands+=("--$function_name")
                    fi
                done
            done

            printf "  %-15s %s\n" "@$exclusion" "${commands[*]}"
        done
    fi

    # Show required commands
    if [[ -n "${_ARGIVO_REQUIRES[$command]:-}" ]]; then
        echo
        echo "Must be executed after:"

        local commands=()
        local required

        # Include all the commands of the @req annotation
        for required in ${_ARGIVO_REQUIRES[$command]}; do
            commands+=("--$required")
        done

        printf "  %-15s %s\n" "--$command" "${commands[*]}"
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

# Get the length of the longest parameter description
function _argivo::max_param_description_length() {
    local command="$1"

    local max_descr=0
    local param

    # Update the length based on the longest descripcion
    for param in ${_ARGIVO_PARAMS[$command]:-}; do
        local descr="${_ARGIVO_PARAM_DESCRIPTIONS["$command:$param"]:-}"
        ((${#descr} > max_descr)) && max_descr=${#descr}
    done

    printf '%s\n' "$max_descr"
}

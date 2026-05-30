#!/usr/bin/env bash
#
# help.bash - help script for argivo
#
# This scripts provides a default "help" command for argivo scripts,
# which lists all available commands and their descriptions.

# Check if annotations have already been loaded
ARGIVO_ANNOTATIONS_LOADED=false

# Annotations for user-defined functions in the script
declare -A ARGIVO_DESCRIPTIONS
declare -A ARGIVO_PARAMS
declare -A ARGIVO_PARAM_DESCRIPTIONS

# Description of the script, if provided by the user
declare ARGIVO_SCRIPT_DESCRIPTION=""

# Discover all user-defined commands excluding those that are
# internal to argivo or defined as private
function argivo::commands() {
    declare -F | awk '{print $3}' | grep -v '^argivo::' | grep -v '^_' | grep -v '^main$' || true
}

# Load all annotations from the script.
function argivo::load_annotations() {
    local line

    # Temporary parameter descriptions for the current function
    declare -A curr_param_descriptions=()

    # Function description and parameters
    local curr_descr=""
    local curr_params=()

    # Script was already defined in argivo, so
    # it is safe to use it here without checking for existence
    # shellcheck disable=SC2154
    local _script="$script"

    while IFS= read -r line; do
        # Check for description comments in the form of:
        # @desc This is a description for a function
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*@desc[[:space:]]+(.*)$ ]]; then
            curr_descr="${BASH_REMATCH[1]}"
            continue
        fi

        # Check for parameter comments in the form of:
        # @param name This is a description for a parameter
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*@param[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]+(.*)$ ]]; then
            curr_params+=("${BASH_REMATCH[1]}")
            curr_param_descriptions["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
            continue
        fi

        local function_name=""

        # Check for function definitions that use the "function" keyword
        if [[ "$line" =~ ^[[:space:]]*function[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            function_name="${BASH_REMATCH[1]}"
        fi

        # Check for function definitions that do not use the "function" keyword
        if [[ -z "$function_name" ]] &&
           [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\) ]]; then
            function_name="${BASH_REMATCH[1]}"
        fi

        # Associate the collected description and parameters
        # of the current function with its name, if we found a function definition
        if [[ -n "$function_name" ]]; then
            # Function description
            if [[ "$function_name" == "main" ]]; then
                ARGIVO_SCRIPT_DESCRIPTION="$curr_descr"
            elif [[ -n "$curr_descr" ]]; then
                ARGIVO_DESCRIPTIONS["$function_name"]="$curr_descr"
            fi

            # Function parameters
            if ((${#curr_params[@]} > 0)); then
                ARGIVO_PARAMS["$function_name"]="${curr_params[*]}"

                local param

                # Parameter descriptions
                for param in "${curr_params[@]}"; do
                    ARGIVO_PARAM_DESCRIPTIONS["$function_name:$param"]="${curr_param_descriptions[$param]}"
                done
            fi

            # Prepares the variables for the next function definition
            curr_descr=""
            curr_params=()
        fi
    done < "$_script"

    # Remove trailing newline from script description
    ARGIVO_SCRIPT_DESCRIPTION="${ARGIVO_SCRIPT_DESCRIPTION%$'\n'}"
}

# Generate usage string for a given command based on its parameters
function argivo::usage() {
    local command="$1"
    local usage="-$command"

    local param

    # Add parameters to the usage string if they exist
    for param in ${ARGIVO_PARAMS[$command]:-}; do
        usage+=" [$param]"
    done

    printf '%s\n' "$usage"
}

# Print help information for the user-defined commands
function argivo::help() {
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

# Print detailed help information for a specific command
function argivo::help_command() {
    local script_name="$1"
    local command="$2"

    if [[ -z "${ARGIVO_DESCRIPTIONS[$command]:-}" ]]; then
        echo "error: unknown command: $command"
        return 1
    fi

    echo "Usage: $script_name $(argivo::usage "$command")"
    echo "${ARGIVO_DESCRIPTIONS[$command]}"
    echo

    if [[ -n "${ARGIVO_PARAMS[$command]:-}" ]]; then
        echo "Arguments:"

        local param

        for param in ${ARGIVO_PARAMS[$command]}; do
            printf "  %-15s %s\n" \
                "$param" \
                "${ARGIVO_PARAM_DESCRIPTIONS["$command:$param"]:-}"
        done
    fi
}
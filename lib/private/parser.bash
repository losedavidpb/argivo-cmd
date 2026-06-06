#!/usr/bin/env bash
#
# parser.bash - parser script for argivo

set -Eeuo pipefail

# Check if annotations have already been loaded
# shellcheck disable=SC2034
_ARGIVO_ANNOTATIONS_LOADED=false

# Annotations for user-defined functions in the script
declare -A _ARGIVO_DESCRIPTIONS
declare -A _ARGIVO_PARAMS
declare -A _ARGIVO_PARAM_DESCRIPTIONS
declare -A _ARGIVO_ALIASES
declare -A _ARGIVO_EXAMPLES

# Description of the script, if provided by the user
declare _ARGIVO_SCRIPT_DESCRIPTION=""

# Load all annotations from the script
function _argivo::load_annotations() {
    # Annotations only need to be parsed once, as they are only used by
    # internal commands that are cached after the first execution
    if $_ARGIVO_ANNOTATIONS_LOADED; then
        return
    fi

    local line

    # Temporary parameter descriptions for the current function
    declare -A curr_param_descriptions=()

    # Function description and parameters
    local curr_descr=""
    local curr_params=()

    # Alias for the current function
    local curr_alias=""

    # Examples for the current function
    local curr_examples=()

    # shellcheck disable=SC2154
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

        # Check for examples in the form of:
        # @example This is an example for a function
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*@example[[:space:]]+(.*)$ ]]; then
            curr_examples+=("${BASH_REMATCH[1]}")
            continue
        fi

        # Check for alias comments in the form of:
        # @alias alias_name
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*@alias[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*$ ]]; then
            curr_alias="${BASH_REMATCH[1]}"
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
                _ARGIVO_SCRIPT_DESCRIPTION="$curr_descr"
            elif [[ -n "$curr_descr" ]]; then
                # shellcheck disable=SC2034
                _ARGIVO_DESCRIPTIONS["$function_name"]="$curr_descr"
            fi

            # Function parameters
            if ((${#curr_params[@]} > 0)); then
                # shellcheck disable=SC2034
                _ARGIVO_PARAMS["$function_name"]="${curr_params[*]}"

                local param

                # Parameter descriptions
                for param in "${curr_params[@]}"; do
                    # shellcheck disable=SC2034
                    _ARGIVO_PARAM_DESCRIPTIONS["$function_name:$param"]="${curr_param_descriptions[$param]}"
                done
            fi

            # Function alias
            if [[ -n "${curr_alias:-}" ]]; then
                # shellcheck disable=SC2034
                _ARGIVO_ALIASES["$curr_alias"]="$function_name"
                curr_alias=""
            fi

            # Function examples
            if ((${#curr_examples[@]} > 0)); then
                # shellcheck disable=SC2034
                _ARGIVO_EXAMPLES["$function_name"]="$(printf '%s\n' "${curr_examples[@]}")"
            fi

            # Prepares the variables for the next function definition
            curr_descr=""
            curr_params=()
            curr_examples=()
        fi
    done < "$_script"

    # Remove trailing newline from script description
    _ARGIVO_SCRIPT_DESCRIPTION="${_ARGIVO_SCRIPT_DESCRIPTION%$'\n'}"

    # Mark annotations as loaded to avoid re-parsing the script
    _ARGIVO_ANNOTATIONS_LOADED=true
}

# Discover all user-defined commands excluding those that are
# internal to argivo or defined as private
function _argivo::get_commands() {
    declare -F | awk '{print $3}' | grep -v '^argivo::' | grep -v '^_' | grep -v '^main$' || true
}

# Get the alias of a given function, if it exists
function _argivo::get_alias() {
    local function_name="$1"
    local alias

    for alias in "${!_ARGIVO_ALIASES[@]}"; do
        if [[ "${_ARGIVO_ALIASES[$alias]}" == "$function_name" ]]; then
            printf '%s\n' "$alias"
            return 0
        fi
    done

    return 1
}

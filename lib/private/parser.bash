#!/usr/bin/env bash
#
# parser.bash - parser script for argivo

set -Eeuo pipefail

# Check if annotations have already been loaded
# shellcheck disable=SC2034
_ARGIVO_ANNOTATIONS_LOADED=false

# Description of the script, if provided by the user
_ARGIVO_SCRIPT_DESCRIPTION=""

# Annotations for user-defined functions
declare -A _ARGIVO_DESCRIPTIONS
declare -A _ARGIVO_PARAMS
declare -A _ARGIVO_ALIASES
declare -A _ARGIVO_EXAMPLES
declare -A _ARGIVO_EXCLUSIONS
declare -A _ARGIVO_REQUIRES
declare -A _ARGIVO_HIDDEN

# Available properties for user-defined parameters
declare -A _ARGIVO_PARAM_TYPES
declare -A _ARGIVO_PARAM_DEFAULTS
declare -A _ARGIVO_PARAM_OPTIONAL
declare -A _ARGIVO_PARAM_DESCRIPTIONS

# Load all annotations from the script
function _argivo::load_annotations() {
    # Annotations only need to be parsed once, as they are only used by
    # internal commands that are cached after the first execution
    $_ARGIVO_ANNOTATIONS_LOADED && return

    local line

    # Function annotations with a single value
    local curr_descr=""
    local curr_alias=""
    local curr_hidden=false

    # Current parameter being parsed
    local param_descr=""
    local param_name=""
    local param_type=""
    local param_default=""
    local param_optional=false

    # Function annotations
    local curr_params=()
    local curr_examples=()
    local curr_exclusions=()
    local curr_requires=()

    # Parameter annotations
    local -A curr_param_descr=()
    local -A curr_param_types=()
    local -A curr_param_defaults=()
    local -A curr_param_optional=()

    # shellcheck disable=SC2154
    while IFS= read -r line; do
        # Check for hidden comments in the form of:
        # @hidden
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*@hidden[[:space:]]*$ ]]; then
            curr_hidden=true
            continue
        fi

        # Check for description comments in the form of:
        # @desc This is a description for a function
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*@desc[[:space:]]+(.*)$ ]]; then
            curr_descr="${BASH_REMATCH[1]}"
            continue
        fi

        # Check for parameter comments in the form of:
        # @param name [type=value] [default=value] [optional] This is a description for a parameter
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*@param[[:space:]]+(.*)$ ]]; then
            read -r -a parts <<< "${BASH_REMATCH[1]}"

            param_descr=""
            param_name="${parts[0]}"
            param_type=""
            param_default=""
            param_optional=false

            local i

            # Properties of the parameter
            for ((i = 1; i < ${#parts[@]}; i++)); do
                local token="${parts[$i]}"

                # Type comment
                if [[ "$token" =~ ^type=(.+)$ ]]; then
                    param_type="${BASH_REMATCH[1]}"
                    continue
                fi

                # Default comment
                if [[ "$token" =~ ^default=(.+)$ ]]; then
                    param_default="${BASH_REMATCH[1]}"
                    continue
                fi

                # Optional comment
                if [[ "$token" == "optional" ]]; then
                    param_optional=true
                    continue
                fi

                # First token that is not metadata starts the description
                param_descr="${parts[*]:$i}"
                break
            done

            curr_params+=("$param_name")

            curr_param_descr["$param_name"]="$param_descr"
            curr_param_types["$param_name"]="$param_type"
            curr_param_defaults["$param_name"]="$param_default"
            curr_param_optional["$param_name"]="$param_optional"

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

        # Check for exclusion comments in the form of:
        # @excl exclusion_name
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*@excl[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*([[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*)*)[[:space:]]*$ ]]; then
            read -r -a exclusions <<< "${BASH_REMATCH[1]}"
            curr_exclusions+=("${exclusions[@]}")
            continue
        fi

        # Check for requires comments in the form of:
        # @req function_name
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*@req[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*([[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*)*)[[:space:]]*$ ]]; then
            read -r -a requires <<< "${BASH_REMATCH[1]}"
            curr_requires+=("${requires[@]}")
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
            # Hidden functions
            _ARGIVO_HIDDEN["$function_name"]="$curr_hidden"
            curr_hidden=false

            # Script description
            if [[ "$function_name" == "main" ]]; then
                _ARGIVO_SCRIPT_DESCRIPTION="$curr_descr"
                curr_descr=""

            # Function description
            elif [[ -n "$curr_descr" ]]; then
                # shellcheck disable=SC2034
                _ARGIVO_DESCRIPTIONS["$function_name"]="$curr_descr"
                curr_descr=""
            fi

            # Function parameters
            if ((${#curr_params[@]} > 0)); then
                # shellcheck disable=SC2034
                _ARGIVO_PARAMS["$function_name"]="${curr_params[*]}"

                local param

                # Parameter properties
                for param in "${curr_params[@]}"; do
                    _ARGIVO_PARAM_DESCRIPTIONS["$function_name:$param"]="${curr_param_descr[$param]}"
                    _ARGIVO_PARAM_TYPES["$function_name:$param"]="${curr_param_types[$param]}"
                    _ARGIVO_PARAM_DEFAULTS["$function_name:$param"]="${curr_param_defaults[$param]}"
                    _ARGIVO_PARAM_OPTIONAL["$function_name:$param"]="${curr_param_optional[$param]}"
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

            # Function exclusions
            if ((${#curr_exclusions[@]} > 0)); then
                # shellcheck disable=SC2034
                _ARGIVO_EXCLUSIONS["$function_name"]="${curr_exclusions[*]}"
            fi

            # Function requires
            if ((${#curr_requires[@]} > 0)); then
                # shellcheck disable=SC2034
                _ARGIVO_REQUIRES["$function_name"]="${curr_requires[*]}"
            fi

            # Clean function annotations
            curr_params=()
            curr_examples=()
            curr_exclusions=()
            curr_requires=()

            # Clean parameter annotations
            curr_param_descr=()
            curr_param_types=()
            curr_param_defaults=()
            curr_param_optional=()
        fi
    done < "$_script"

    # Remove trailing newline from script description
    _ARGIVO_SCRIPT_DESCRIPTION="${_ARGIVO_SCRIPT_DESCRIPTION%$'\n'}"

    # Mark annotations as loaded to avoid re-parsing the script
    _ARGIVO_ANNOTATIONS_LOADED=true
}

# Discover all user-defined commands excluding those that are
# internal to argivo, private, or marked as hidden
function _argivo::get_commands() {
    local cmd
    local commands

    # Get all declared user-defined functions
    commands="$(declare -F | awk '{print $3}' | grep -Ev '^(argivo::|_|main$)')"
    [[ -z "$commands" ]] && return

    # Skip commands marked with the @hidden annotation
    while read -r cmd; do
        [[ "${_ARGIVO_HIDDEN[$cmd]:-}" == "true" ]] && continue
        printf '%s\n' "$cmd"
    done <<< "$commands"
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

# Get the exclusions of current script
function _argivo::get_exclusions() {
    local -A exclusions=()

    local function_name
    local exclusion

    for function_name in "${!_ARGIVO_EXCLUSIONS[@]}"; do
        for exclusion in ${_ARGIVO_EXCLUSIONS[$function_name]}; do
            exclusions["$exclusion"]=1
        done
    done

    printf '%s\n' "${!exclusions[@]}" | sort
}

# Get the commands that define requirements
function _argivo::get_requires() {
    local -A requires=()

    local function_name

    for function_name in "${!_ARGIVO_REQUIRES[@]}"; do
        requires["$function_name"]=1
    done

    printf '%s\n' "${!requires[@]}" | sort
}
#!/usr/bin/env bash
#
# parser.bash - parser script for argivo

set -Eeuo pipefail

# Prevent loading this module more than once
[[ -n "${_ARGIVO_PARSER_LOADED:-}" ]] && return 0
_ARGIVO_PARSER_LOADED=true

# Check if the script have already been loaded
# shellcheck disable=SC2034
_ARGIVO_SCRIPT_PARSED=false

# Description of the script, if provided by the user
_ARGIVO_SCRIPT_DESCRIPTION=""

# Directives for configuring the interpreter
declare -A _ARGIVO_DIRECTIVES

# User-defined functions
declare -A _ARGIVO_COMMANDS

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

# Parse the script and populate the internal metadata
# shellcheck disable=SC2034
function _argivo::parse_script() {
    # The script should only need to be parsed once
    $_ARGIVO_SCRIPT_PARSED && return 0

    # Flags to control the code sections
    local is_directive_section=true
    local is_function_section=false
    local waiting_for_open_brace=false
    local brace_depth=0

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

    local line

    # shellcheck disable=SC2154
    while IFS= read -r line; do
        # Empty or blank lines should not be considered
        [[ "$line" =~ $_ARGIVO_REGEX_EMPTY ]] && continue

        # Waiting for the opening brace of a function declaration
        if [[ "$waiting_for_open_brace" == true ]]; then
            _argivo::consume_open_brace "$line" waiting_for_open_brace brace_depth && continue
            is_function_section=false
        fi

        # Update brace depth and detect when the current function body ends
        _argivo::update_function_section "$line" is_function_section brace_depth

        # Check for directives in the form of:
        # @argivo key=value
        if [[ "$line" =~ $_ARGIVO_REGEX_DIRECTIVE ]]; then
            if [[ "$is_directive_section" == true ]]; then
                local directive_key="${BASH_REMATCH[1]}"
                local directive_value="${BASH_REMATCH[2]}"

                _ARGIVO_DIRECTIVES["$directive_key"]="$directive_value"
            fi

            continue
        fi

        # Check for hidden comments in the form of:
        # @hidden
        if [[ "$line" =~ $_ARGIVO_REGEX_HIDDEN ]]; then
            is_directive_section=false

            # Annotations must only be used before the function declaration
            if [[ "$is_function_section" == false ]]; then
                curr_hidden=true
            fi

            continue
        fi

        # Check for description comments in the form of:
        # @desc This is a description for a function
        if [[ "$line" =~ $_ARGIVO_REGEX_DESC ]]; then
            is_directive_section=false

            # Annotations must only be used before the function declaration
            if [[ "$is_function_section" == false ]]; then
                curr_descr="${BASH_REMATCH[1]}"
            fi

            continue
        fi

        # Check for parameter comments in the form of:
        # @param name [type=value] [default=value] [optional] Description
        if [[ "$line" =~ $_ARGIVO_REGEX_PARAM ]]; then
            is_directive_section=false

            # Annotations must only be used before the function declaration
            if [[ "$is_function_section" == false ]]; then
                read -r -a parts <<< "${BASH_REMATCH[2]}"

                param_descr=""
                param_name="${BASH_REMATCH[1]}"
                param_type=""
                param_default=""
                param_optional=false

                local i

                # Properties of the parameter
                for ((i = 0; i < ${#parts[@]}; i++)); do
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
            fi

            continue
        fi

        # Check for examples in the form of:
        # @example This is an example for a function
        if [[ "$line" =~ $_ARGIVO_REGEX_EXAMPLE ]]; then
            is_directive_section=false

            # Annotations must only be used before the function declaration
            if [[ "$is_function_section" == false ]]; then
                curr_examples+=("${BASH_REMATCH[1]}")
            fi

            continue
        fi

        # Check for alias comments in the form of:
        # @alias alias_name
        if [[ "$line" =~ $_ARGIVO_REGEX_ALIAS ]]; then
            is_directive_section=false

            # Annotations must only be used before the function declaration
            if [[ "$is_function_section" == false ]]; then
                curr_alias="${BASH_REMATCH[1]}"
            fi

            continue
        fi

        # Check for exclusion comments in the form of:
        # @excl exclusion_name
        if [[ "$line" =~ $_ARGIVO_REGEX_EXCL ]]; then
            is_directive_section=false

            # Annotations must only be used before the function declaration
            if [[ "$is_function_section" == false ]]; then
                read -r -a exclusions <<< "${BASH_REMATCH[1]}"
                curr_exclusions+=("${exclusions[@]}")
            fi

            continue
        fi

        # Check for requires comments in the form of:
        # @req function_name
        if [[ "$line" =~ $_ARGIVO_REGEX_REQ ]]; then
            is_directive_section=false

            # Annotations must only be used before the function declaration
            if [[ "$is_function_section" == false ]]; then
                read -r -a requires <<< "${BASH_REMATCH[1]}"
                curr_requires+=("${requires[@]}")
            fi

            continue
        fi

        # shellcheck disable=SC2155
        local function_name="$(_argivo::get_function_name "$line")"

        # Associate the collected description and parameters
        # of the current function with its name, if we found a function definition
        if [[ -n "$function_name" ]]; then
            is_directive_section=false

            # Initialize function body tracking
            _argivo::start_function_section "$line" is_function_section waiting_for_open_brace brace_depth

            # Store the function name for future checks
            _ARGIVO_COMMANDS["$function_name"]=1

            # Hidden functions
            _ARGIVO_HIDDEN["$function_name"]="$curr_hidden"
            curr_hidden=false

            # Script description
            if [[ "$function_name" == "main" ]]; then
                _ARGIVO_SCRIPT_DESCRIPTION="$curr_descr"
                curr_descr=""

            # Function description
            elif [[ -n "$curr_descr" ]]; then
                _ARGIVO_DESCRIPTIONS["$function_name"]="$curr_descr"
                curr_descr=""
            fi

            # Function parameters
            if ((${#curr_params[@]} > 0)); then
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
                _ARGIVO_ALIASES["$curr_alias"]="$function_name"
                curr_alias=""
            fi

            # Function examples
            if ((${#curr_examples[@]} > 0)); then
                _ARGIVO_EXAMPLES["$function_name"]="$(printf '%s\n' "${curr_examples[@]}")"
            fi

            # Function exclusions
            if ((${#curr_exclusions[@]} > 0)); then
                _ARGIVO_EXCLUSIONS["$function_name"]="${curr_exclusions[*]}"
            fi

            # Function requires
            if ((${#curr_requires[@]} > 0)); then
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

    # Mark script as parsed to avoid re-parsing the script
    _ARGIVO_SCRIPT_PARSED=true
}

# Discover all user-defined commands excluding those that are
# internal to argivo, private, or marked as hidden
function _argivo::get_commands() {
    local cmd

    # Return only public commands that can be invoked directly by users
    for cmd in "${!_ARGIVO_COMMANDS[@]}"; do
        [[ "$cmd" == "main" ]] && continue
        [[ "$cmd" == _* ]] && continue
        [[ "${_ARGIVO_HIDDEN[$cmd]:-}" == "true" ]] && continue

        printf '%s\n' "$cmd"
    done | sort
}

# Get the alias of a given function, if it exists
function _argivo::get_alias() {
    local function_name="$1"
    local alias

    # Aliases are keyed by name, so search their values for the function
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

    # Collect exclusion groups in a set to remove duplicates across functions
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

    # Collect commands that declare at least one requirement
    for function_name in "${!_ARGIVO_REQUIRES[@]}"; do
        requires["$function_name"]=1
    done

    printf '%s\n' "${!requires[@]}" | sort
}

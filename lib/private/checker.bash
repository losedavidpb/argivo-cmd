#!/usr/bin/env bash
#
# checker.bash - checker script for argivo

set -Eeuo pipefail

# Check the syntax of an argivo script
function _argivo::check() {
    if (($# == 0)); then
        echo "error: no script provided for checking"
        echo "usage: argivo --check <script>"
        exit 1
    fi

    local script="$1"
    shift

    # Verbose mode is disabled by default to avoid excessive output
    # during script execution and regular checks
    local verbose=false

    # Check the verbose mode
    if [[ "${1:-}" == "--verbose" ]]; then
        echo "Checking $(basename "$script")..."
        verbose=true
        shift
    fi

    # Check that the script is a valid argivo script
    if ! _argivo::is_argivo_script "$script"; then
        exit 1
    fi

    # Check that all directives are valid
    if ! _argivo::check_directives; then
        exit 1
    fi

    # Check that all functions in the script have unique names
    if ! _argivo::check_commands "$script"; then
        echo "error: duplicate functions found"
        exit 1
    fi

    # Check that all command aliases in the script have unique names
    if ! _argivo::check_aliases "$script"; then
        echo "error: duplicate command aliases found"
        exit 1
    fi

    # Check that all exclusions are defined once at each function
    if ! _argivo::check_exclusions "$script"; then
        echo "error: duplicate exclusions found at a function"
        exit 1
    fi

    # Check that all requires are defined once with a valid function
    if ! _argivo::check_requires "$script"; then
        echo "error: duplicate or undefined required commands found"
        exit 1
    fi

    # Check that the main function does only have valid annotations
    if ! _argivo::check_main "$script"; then
        echo "error: main function does have invalid annotations"
        exit 1
    fi

    # Check that defined types are valid
    if ! _argivo::check_param_types; then
        exit 1
    fi

    # Check that default values are defined based on its type
    if ! _argivo::check_param_defaults; then
        exit 1
    fi

    # Show syntax validation results
    if [[ "$verbose" == "true" ]]; then
        echo
        echo "✓ Script is a valid argivo script"
        echo "✓ All directives are valid"
        echo "✓ Command names are unique and valid"
        echo "✓ Command aliases are unique and defined once per function"
        echo "✓ Exclusions are consistent within each function"
        echo "✓ Requires are valid and resolved at each function"
        echo "✓ All parameter types are supported"
        echo "✓ All parameter default values match their declared types"

        echo
        echo "No issues found"
    fi

    return 0
}

# Check that the script is valid for Argivo
function _argivo::is_argivo_script() {
    local script="$1"

    # Check that the script exists and is readable
    if [[ ! -f "$script" || ! -r "$script" ]]; then
        echo "error: script not found or is not readable"
        return 1
    fi

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

    return 0
}

# Check that all directives in the script are valid
function _argivo::check_directives() {
    # Load all directives from the script
    _argivo::load_directives

    # Check if the script targets a specific major version of Argivo
    if [[ -v _ARGIVO_DIRECTIVES[version] ]]; then
        local required_version="${_ARGIVO_DIRECTIVES[version]}"

        # Check that the "version" directive is a valid semantic version
        if [[ ! "$required_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "error: invalid @argivo version: $required_version."
            return 1
        fi

        local required_major="${required_version%%.*}"
        local current_major="${_ARGIVO_VERSION%%.*}"

        # Check that the major version of the script matches
        # the current version of Argivo
        if [[ "$required_major" != "$current_major" ]]; then
            echo "error: this script requires Argivo $required_major.x.x (current: $_ARGIVO_VERSION)."
            return 1
        fi
    fi

    return 0
}

# Check that all functions in the script have unique names
function _argivo::check_commands() {
    local script="$1"

    local duplicates

    duplicates="$(
        grep -E '^[[:space:]]*function[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)' "$script" |
        sed -E 's/^[[:space:]]*function[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*).*/\1/' |
        sort | uniq -d
    )"

    [[ -z "$duplicates" ]]
}

# Check that all command aliases in the script have unique names
function _argivo::check_aliases() {
    local script="$1"

    local duplicates

    duplicates="$(
        grep -E '^[[:space:]]*#[[:space:]]*@alias[[:space:]]+' "$script" |
        sed -E 's/.*@alias[[:space:]]+//' | sort | uniq -d
    )"

    [[ -z "$duplicates" ]]
}

# Check that main exists and does only have valid annotations
function _argivo::check_main() {
    local script="$1"

    local line

    # The main function should exist and it must not
    # have any invalid annotation
    local invalid=false

    while IFS= read -r line; do
        # It is not neccesary to check more annotations if an invalid
        # one for the main function has been detected
        if [[ $invalid == false ]]; then
            # An annotation has been detected
            if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*@([a-zA-Z_]+)[[:space:]]*.*$ ]]; then
                local annotation="${BASH_REMATCH[1]}"

                # The function does contain the annotation
                [[ "$annotation" =~ ^(alias|req|excl|hidden)$ ]] && invalid=true

                continue
            fi
        fi

        # Check that the main doesn't have any invalid annotation
        if [[ "$line" =~ ^[[:space:]]*(function[[:space:]]+)?main[[:space:]]*(\(\))? ]]; then
            [[ $invalid == true ]] && return 1
        fi

        # Any non-comment line breaks the annotation block
        [[ ! "$line" =~ ^[[:space:]]*# ]] && invalid=false
    done < "$script"

    return 0
}

# Check that all exclusions are defined once at each function
function _argivo::check_exclusions() {
    local script="$1"

    local line
    local -A exclusions=()

    while IFS= read -r line; do
        # Reset exclusions for the new function
        if [[ "$line" =~ ^[[:space:]]*(function[[:space:]]+)?[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(\(\))? ]]; then
            exclusions=()
            continue
        fi

        # Check exclusions for current function
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*@excl[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*([[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*)*)[[:space:]]*$ ]]; then
            local group

            for group in ${BASH_REMATCH[1]}; do
                if [[ -n "${exclusions[$group]:-}" ]]; then
                    return 1
                fi

                exclusions["$group"]=1
            done
        fi
    done < "$script"

    return 0
}

# Check that all requires are valid and defined once at each function
function _argivo::check_requires() {
    local script="$1"

    local line
    local -A functions=()
    local -A requires=()

    # Collect all function values before checking its dependencies
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*function[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            functions["${BASH_REMATCH[1]}"]=1
            continue
        fi

        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\) ]]; then
            functions["${BASH_REMATCH[1]}"]=1
        fi
    done < "$script"

    while IFS= read -r line; do
        # Reset requires for the new function
        if [[ "$line" =~ ^[[:space:]]*(function[[:space:]]+)?[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(\(\))? ]]; then
            requires=()
            continue
        fi

        # Check requires for current function
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*@req[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*([[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*)*)[[:space:]]*$ ]]; then
            local required

            for required in ${BASH_REMATCH[1]}; do
                # Duplicate require
                if [[ -n "${requires[$required]:-}" ]]; then
                    echo "error: duplicate require: $required"
                    return 1
                fi

                # Required function does not exist
                if [[ -z "${functions[$required]:-}" ]]; then
                    echo "error: unknown required command: $required"
                    return 1
                fi

                requires["$required"]=1
            done
        fi
    done < "$script"

    return 0
}

# Check that all declared parameter types are supported
function _argivo::check_param_types() {
    _argivo::load_annotations

    local key

    for key in "${!_ARGIVO_PARAM_TYPES[@]}"; do
        [[ -z "${_ARGIVO_PARAM_TYPES[$key]}" ]] && continue

        local validator="argivo::is_${_ARGIVO_PARAM_TYPES[$key]}"

        if ! declare -F "$validator" >/dev/null; then
            echo "error: unknown parameter type: ${_ARGIVO_PARAM_TYPES[$key]} for '$key'"
            return 1
        fi
    done

    return 0
}

# Check that parameter default values match their declared types
function _argivo::check_param_defaults() {
    _argivo::load_annotations

    local key

    for key in "${!_ARGIVO_PARAM_DEFAULTS[@]}"; do
        [[ -z "${_ARGIVO_PARAM_DEFAULTS[$key]}" ]] && continue
        [[ -z "${_ARGIVO_PARAM_TYPES[$key]}" ]] && continue

        local validator="argivo::is_${_ARGIVO_PARAM_TYPES[$key]}"

        # Check default value based on its type
        if ! "$validator" "${_ARGIVO_PARAM_DEFAULTS[$key]}"; then
            echo "error: invalid default value '${_ARGIVO_PARAM_DEFAULTS[$key]}' for '$key'"
            return 1
        fi
    done

    return 0
}
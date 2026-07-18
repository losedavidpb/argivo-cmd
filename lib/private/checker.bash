#!/usr/bin/env bash
#
# checker.bash - checker script for argivo

set -Eeuo pipefail

# Prevent loading this module more than once
[[ -n "${_ARGIVO_CHECKER_LOADED:-}" ]] && return 0
_ARGIVO_CHECKER_LOADED=true

# Check the syntax of an argivo script
function _argivo::check() {
    # An argivo script must be provided
    if (($# == 0)); then
        echo "error: no script provided for checking"
        echo "usage: argivo --check <script>"
        return 1
    fi

    local script="$1"
    shift

    # Verbose is disabled by default to avoid excessive output
    # during script execution and regular checks
    local verbose=false

    # Check the verbose mode
    if [[ "${1:-}" == "--verbose" ]]; then
        echo "Checking $(basename "$script")..."
        verbose=true
        shift
    fi

    # There should not be more arguments
    if (($# != 0)); then
        echo "error: unexpected argument: $1"
        return 1
    fi

    # Check that the script is a valid argivo script
    _argivo::validate_script_structure "$script" || return 1
    _argivo::validate_script_semantics "$script" || return 1
    _argivo::validate_command_dependencies || return 1

    # Show validation results if verbose is active
    if [[ "$verbose" == "true" ]]; then
        echo
        echo "✓ Script structure and entry point are valid"
        echo "✓ Directives and annotations are valid"
        echo "✓ Command names and aliases are unique"
        echo "✓ Command dependencies are valid"
        echo "✓ Parameter definitions are valid"

        echo
        echo "No issues found"
    fi

    return 0
}

# Perform basic checks of an Argivo script
function _argivo::validate_script_structure() {
    local script="$1"

    # The script must exist and be readable
    if [[ ! -f "$script" || ! -r "$script" ]]; then
        echo "error: script not found or is not readable"
        return 1
    fi

    # The argivo shebang should be included
    if ! head -n1 "$script" | grep -qx "$_ARGIVO_REGEX_SHEBANG"; then
        echo "error: missing argivo shebang"
        return 1
    fi

    local syntax_error

    # Check the Bash syntax without executing the script
    if ! syntax_error="$("$BASH" -n "$script" 2>&1)"; then
        echo "error: invalid Bash syntax"
        printf '%s\n' "$syntax_error"
        return 1
    fi

    # Check for the presence of the main function
    if ! grep -Eq "$_ARGIVO_REGEX_MAIN" "$script"; then
        echo "error: missing main function"
        return 1
    fi

    return 0
}

# Perform semantic validation of an Argivo script
# shellcheck disable=SC2034
function _argivo::validate_script_semantics() {
    local script="$1"

    # Annotations and directives already declared
    # for the current function and script
    local -A annotations=()
    local -A directives=()

    # Flags to control the code sections
    local is_directive_section=true
    local waiting_for_open_brace=false
    local is_function_section=false
    local brace_depth=0

    # Flags to track possible duplications
    local -A functions=()
    local -A aliases=()
    local -A exclusions=()
    local -A requires=()
    local -A parameters=()

    # Flags to track the state of the annotations
    local pending_annotations=false
    local hidden=false
    local alias=""

    local line

    while IFS= read -r line; do
        # Empty or blank lines should not be considered
        [[ "$line" =~ $_ARGIVO_REGEX_EMPTY ]] && continue

        # Waiting for the opening brace of a function declaration
        if [[ "$waiting_for_open_brace" == true ]]; then
            _argivo::consume_open_brace "$line" waiting_for_open_brace brace_depth && continue

            echo "error: expected opening brace after function declaration"
            return 1
        fi

        # Update brace depth and detect when the current function body ends
        _argivo::update_function_section "$line" is_function_section brace_depth

        # shellcheck disable=SC2155
        local function_name="$(_argivo::get_function_name "$line")"

        # A new function definition has been declared
        if [[ -n "$function_name" ]]; then
            is_directive_section=false
            pending_annotations=false

            # Initialize function body tracking
            _argivo::start_function_section "$line" is_function_section waiting_for_open_brace brace_depth

            # Validate function
            _argivo::validate_main_function_annotations "$function_name" requires exclusions "$hidden" "$alias" || return 1
            _argivo::validate_name_not_reserved "$function_name" help || return 1
            _argivo::register_unique_value functions "$function_name" || return 1

            # Reset single-value annotations
            # for the next function
            hidden=false
            alias=""

            # Reset annotation value registries
            # for the next function
            exclusions=()
            requires=()
            parameters=()

            # Reset the annotation declaration
            # registry for the next function
            annotations=()

            continue
        fi

        # Check for annotations and directives in the script
        if [[ "$line" =~ $_ARGIVO_REGEX_ANNOTATION ]]; then
            local annotation="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Annotations end the directive section and wait for a function
            if [[ "$annotation" != "argivo" ]]; then
                is_directive_section=false
                pending_annotations=true
            fi

            case $annotation in
                argivo)
                    local directive="${value%%=*}"
                    local directive_value="${value#*=}"

                    # Check @argivo requirements
                    _argivo::validate_declaration_section "$annotation" "$is_directive_section" true || return 1
                    _argivo::validate_required_value "$annotation" "$value" || return 1
                    _argivo::validate_value_syntax "$annotation" "$value" "$_ARGIVO_REGEX_DIRECTIVE_VALUE" || return 1
                    _argivo::register_unique_value directives "$directive" || return 1
                    _argivo::validate_directive_value "$annotation" "$directive" "$directive_value" || return 1
                ;;

                desc)
                    # Check @desc requirements
                    _argivo::validate_declaration_section "$annotation" "$is_function_section" false || return 1
                    _argivo::validate_required_value "$annotation" "$value" || return 1
                    _argivo::register_unique_value annotations "$annotation" || return 1
                ;;

                param)
                    local parameter="${value%%[[:space:]]*}"

                    # Check @param requirements
                    _argivo::validate_declaration_section "$annotation" "$is_function_section" false || return 1
                    _argivo::validate_required_value "$annotation" "$value" || return 1
                    _argivo::validate_value_syntax "$annotation" "$value" "$_ARGIVO_REGEX_PARAM_SYNTAX" || return 1
                    _argivo::register_unique_value parameters "$parameter" || return 1
                    _argivo::validate_parameter_type "$value" || return 1
                    _argivo::validate_parameter_default "$value" "$parameter" || return 1
                ;;

                alias)
                    alias="$value"

                    # Check @alias requirements
                    _argivo::validate_declaration_section "$annotation" "$is_function_section" false || return 1
                    _argivo::validate_required_value "$annotation" "$value" || return 1
                    _argivo::validate_value_syntax "$annotation" "$value" "$_ARGIVO_REGEX_IDENTIFIER" || return 1
                    _argivo::validate_name_not_reserved "$value" h || return 1
                    _argivo::validate_value_not_registered _ARGIVO_COMMANDS "$value" || return 1
                    _argivo::register_unique_value annotations "$annotation" || return 1
                    _argivo::register_unique_value aliases "$value" || return 1
                ;;

                hidden)
                    hidden=true

                    # Check @hidden requirements
                    _argivo::validate_declaration_section "$annotation" "$is_function_section" false || return 1
                    _argivo::validate_forbidden_value "$annotation" "$value" || return 1
                    _argivo::register_unique_value annotations "$annotation" || return 1
                ;;

                example)
                    # Check @example requirements
                    _argivo::validate_declaration_section "$annotation" "$is_function_section" false || return 1
                    _argivo::validate_required_value "$annotation" "$value" || return 1
                ;;

                excl)
                    # Check @excl requirements
                    _argivo::validate_declaration_section "$annotation" "$is_function_section" false || return 1
                    _argivo::validate_required_value "$annotation" "$value" || return 1
                    _argivo::validate_value_syntax "$annotation" "$value" "$_ARGIVO_REGEX_IDENTIFIER_LIST" || return 1
                    _argivo::register_unique_value annotations "$annotation" || return 1
                    _argivo::register_exclusion_groups "$value" exclusions || return 1
                ;;

                req)
                    # Check @req requirements
                    _argivo::validate_declaration_section "$annotation" "$is_function_section" false || return 1
                    _argivo::validate_required_value "$annotation" "$value" || return 1
                    _argivo::validate_value_syntax "$annotation" "$value" "$_ARGIVO_REGEX_IDENTIFIER_LIST" || return 1
                    _argivo::register_unique_value annotations "$annotation" || return 1
                    _argivo::register_command_requirements "$value" requires || return 1
                ;;

                # The annotation or directive is not supported
                *)
                    echo "error: unsupported annotation or directive: $annotation"
                    return 1
                ;;
            esac
        fi
    done < "$script"

    # There must not be any annotations without an associated function
    if $pending_annotations; then
        echo "error: annotations are not associated with a function"
        return 1
    fi

    # A function declaration cannot be left without an opening brace
    if $waiting_for_open_brace; then
        echo "error: expected opening brace after function declaration"
        return 1
    fi

    return 0
}

# Check that an annotation is allowed in the current section
function _argivo::validate_declaration_section() {
    local name="$1"
    local current_state="$2"
    local expected_state="$3"

    # The passed annotation can only be defined in
    # certain parts of the Argivo script
    if [[ "$current_state" != "$expected_state" ]]; then
        echo "error: @$name is not allowed in this section"
        return 1
    fi

    return 0
}

# Check that the passed annotation has a value
function _argivo::validate_required_value() {
    local name="$1"
    local value="$2"

    # The passed annotation requires a value
    if [[ -z "$value" ]]; then
        echo "error: @$name annotation requires a value"
        return 1
    fi

    return 0
}

# Check that the passed annotation does not have a value
function _argivo::validate_forbidden_value() {
    local name="$1"
    local value="$2"

    # The passed annotation does not require a value
    if [[ -n "$value" ]]; then
        echo "error: @$name annotation should not have a value"
        return 1
    fi

    return 0
}

# Check that the passed annotation has a valid syntax
function _argivo::validate_value_syntax() {
    local name="$1"
    local value="$2"
    local regex="$3"

    # Annotations and directives must conform
    # to their expected syntax
    if ! [[ "$value" =~ $regex ]]; then
        echo "error: invalid @$name syntax"
        return 1
    fi

    return 0
}

# Validate an Argivo directive value
function _argivo::validate_directive_value() {
    local annotation="$1"
    local directive="$2"
    local value="$3"

    case "$directive" in
        check)
            # Check @argivo check requirements
            _argivo::validate_value_syntax "$annotation $directive" "$value" "$_ARGIVO_REGEX_BOOLEAN" || return 1
        ;;

        version)
            # Check @argivo version requirements
            _argivo::validate_value_syntax "$annotation $directive" "$value" "$_ARGIVO_REGEX_VERSION" || return 1
            _argivo::validate_version_compatibility "$value" || return 1
        ;;

        *)
            echo "error: unsupported @$annotation directive: $directive"
            return 1
        ;;
    esac

    return 0
}

# Check that the required Argivo version is compatible
function _argivo::validate_version_compatibility() {
    local required_version="$1"

    # Get the required and current major version
    local required_major="${required_version%%.*}"
    local current_major="${_ARGIVO_VERSION%%.*}"

    # Compatibility requires the script and interpreter
    # to share the same major version
    if [[ "$required_major" != "$current_major" ]]; then
        echo "error: this script requires Argivo $required_major.x.x (current: $_ARGIVO_VERSION)"
        return 1
    fi

    return 0
}

# Check annotations that are not allowed on the main function
function _argivo::validate_main_function_annotations() {
    local function_name="$1"
    local -n required="$2"
    local -n excluded="$3"
    local hidden="$4"
    local alias="$5"

    # These requirements are only applied on the main function
    if [[ "$function_name" == "main" ]]; then
        if [[ -n "${required[*]}" || -n "${excluded[*]}" || "$hidden" == true || -n "$alias" ]]; then
            echo "error: main function cannot use @alias, @req, @excl or @hidden"
            return 1
        fi
    fi

    return 0
}

# Check that a name is not reserved
function _argivo::validate_name_not_reserved() {
    local name="$1"
    shift

    local reserved

    # The list of passed values must not have any reserved
    # name used by the Argivo interpreter
    for reserved in "$@"; do
        if [[ "$name" == "$reserved" ]]; then
            echo "error: reserved name: $name"
            return 1
        fi
    done

    return 0
}

# Check that the passed parameter type is supported
function _argivo::validate_parameter_type() {
    local value="$1"

    if [[ "$value" =~ $_ARGIVO_REGEX_PARAM_TYPE ]]; then
        local type="${BASH_REMATCH[1]}"
        local validator="argivo::is_$type"

        # There must be a public function associated
        # with the passed parameter type
        if ! declare -F "$validator" >/dev/null; then
            echo "error: unknown parameter type: $type"
            return 1
        fi
    fi

    return 0
}

# Check that the default value is valid for its type
function _argivo::validate_parameter_default() {
    local value="$1"
    local parameter="$2"

    if [[ "$value" =~ $_ARGIVO_REGEX_PARAM_DEFAULT ]]; then
        local default="${BASH_REMATCH[1]}"

        if [[ "$value" =~ $_ARGIVO_REGEX_PARAM_TYPE ]]; then
            local type="${BASH_REMATCH[1]}"
            local validator="argivo::is_$type"

            # The default value must be valid for the
            # parameter's declared type
            if ! "$validator" "$default"; then
                echo "error: invalid default value '$default' for parameter '$parameter'"
                return 1
            fi
        fi
    fi

    return 0
}

# Check that a value is not registered in an associative array
function _argivo::validate_value_not_registered() {
    local registry_name="$1"
    local -n registry="$registry_name"
    local value="$2"

    # Values must be unique within their registry
    if [[ -n "${registry[$value]:-}" ]]; then
        echo "error: value '$value' is already registered"
        return 1
    fi

    return 0
}

# Check that a value is registered in an associative array
function _argivo::validate_value_registered() {
    local registry_name="$1"
    local -n registry="$registry_name"
    local value="$2"

    # The value must already exist in the registry
    if [[ -z "${registry[$value]:-}" ]]; then
        echo "error: value '$value' is not registered"
        return 1
    fi

    return 0
}

# Register a unique value in an associative array
function _argivo::register_unique_value() {
    local registry_name="$1"
    local -n registry="$registry_name"
    local key="$2"

    # Ensure the key has not already been registered
    _argivo::validate_value_not_registered "$registry_name" "$key" || return 1

    # Store the key in the registry
    registry["$key"]=1
    return 0
}

# Register exclusion groups and reject duplicate declarations
function _argivo::register_exclusion_groups() {
    local value="$1"
    local registry_name="$2"

    local group

    # Register each exclusion group while enforcing uniqueness
    for group in $value; do
        _argivo::register_unique_value "$registry_name" "$group" || return 1
    done

    return 0
}

# Register command requirements and validate their existence
function _argivo::register_command_requirements() {
    local value="$1"
    local registry_name="$2"

    local required

    # Register each requirement after confirming the command exists
    for required in $value; do
        _argivo::validate_value_registered _ARGIVO_COMMANDS "$required" || return 1
        _argivo::register_unique_value "$registry_name" "$required" || return 1
    done

    return 0
}

# Check that command dependencies do not contain cycles
function _argivo::validate_command_dependencies() {
    local -A dependency_count=()
    local -A dependent_commands=()
    local -a ready_commands=()

    local command
    local required
    local dependent

    # Initialize the number of requirements for every command
    for command in "${!_ARGIVO_COMMANDS[@]}"; do
        dependency_count["$command"]=0
    done

    # Count requirements and build the reverse dependency graph
    for command in "${!_ARGIVO_REQUIRES[@]}"; do
        for required in ${_ARGIVO_REQUIRES[$command]}; do
            dependency_count["$command"]=$((
                ${dependency_count[$command]} + 1
            ))

            if [[ -n "${dependent_commands[$required]:-}" ]]; then
                dependent_commands["$required"]+=" $command"
            else
                dependent_commands["$required"]="$command"
            fi
        done
    done

    # Commands without requirements are ready to be processed
    for command in "${!_ARGIVO_COMMANDS[@]}"; do
        if [[ "${dependency_count[$command]}" == "0" ]]; then
            ready_commands+=("$command")
        fi
    done

    local queue_index=0
    local processed_commands=0

    # Process commands in dependency order and release their dependents
    while ((queue_index < ${#ready_commands[@]})); do
        command="${ready_commands[$queue_index]}"
        queue_index=$((queue_index + 1))
        processed_commands=$((processed_commands + 1))

        for dependent in ${dependent_commands[$command]:-}; do
            dependency_count["$dependent"]=$((
                ${dependency_count[$dependent]} - 1
            ))

            if [[ "${dependency_count[$dependent]}" == "0" ]]; then
                ready_commands+=("$dependent")
            fi
        done
    done

    # Unprocessed commands indicate at least one dependency cycle
    if ((processed_commands != ${#_ARGIVO_COMMANDS[@]})); then
        echo "error: circular command dependency detected"
        return 1
    fi

    return 0
}

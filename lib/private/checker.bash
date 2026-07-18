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
    _argivo::validate_script "$script" || return 1
    _argivo::validate_semantics "$script" || return 1
    _argivo::validate_dependencies || return 1

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
function _argivo::validate_script() {
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

    # Check the Bash syntax without executing the script
    local syntax_error

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
function _argivo::validate_semantics() {
    local script="$1"

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
    local hidden=false
    local alias=""

    # Annotations and directives already declared
    # for the current function and script
    local -A annotations=()
    local -A directives=()

    # Indicates whether annotations are waiting for a function
    local pending_annotations=false

    local line

    while IFS= read -r line; do
        # Empty or blank lines should not be considered
        [[ "$line" =~ $_ARGIVO_REGEX_EMPTY ]] && continue

        # Waiting for the opening brace of a function declaration
        if [[ "$waiting_for_open_brace" == true ]]; then
            # The first non-blank line must be the opening brace
            if [[ "$line" =~ $_ARGIVO_REGEX_OPEN_BRACE ]]; then
                waiting_for_open_brace=false
                brace_depth=1
                continue
            fi

            echo "error: expected opening brace after function declaration"
            return 1
        fi

        # Update function brace depth to only load annotations
        # that appear before a function declaration and ignore
        # annotations inside function bodies
        if [[ "$is_function_section" == true ]]; then
            _argivo::update_brace_depth "$line"

            # The function body has ended once the
            # brace depth reaches zero
            if (( brace_depth == 0 )); then
                is_function_section=false
            fi
        fi

        local function_name=""

        # Check for function definitions that use the "function" keyword
        if [[ "$line" =~ $_ARGIVO_REGEX_FUNCTION_1 ]]; then
            is_directive_section=false
            function_name="${BASH_REMATCH[1]}"

        # Check for function definitions that do not use the "function" keyword
        elif [[ -z "$function_name" ]] && [[ "$line" =~ $_ARGIVO_REGEX_FUNCTION_2 ]]; then
            is_directive_section=false
            function_name="${BASH_REMATCH[1]}"
        fi

        # A new function definition has been declared
        if [[ -n "$function_name" ]]; then
            is_directive_section=false
            pending_annotations=false

            # Annotations must not be used inside the function
            is_function_section=true
            brace_depth=0

            # The opening brace may appear on the next non-blank line
            if [[ "$line" == *"{"* ]]; then
                brace_depth=1
            else
                waiting_for_open_brace=true
            fi

            # The main function cannot have certain annotations
            if [[ "$function_name" == "main" ]]; then
                if [[ -n "${requires[*]}" || -n "${exclusions[*]}" || "$hidden" == true || -n "$alias" ]]; then
                    echo "error: main function cannot use @alias, @req, @excl or @hidden"
                    return 1
                fi
            fi

            # Built-in command names cannot be redefined
            if [[ "$function_name" == "help" ]]; then
                echo "error: reserved command name: $function_name"
                return 1
            fi

            # Function names must be unique
            if [[ -n "${functions[$function_name]:-}" ]]; then
                echo "error: duplicate function: $function_name"
                return 1
            fi

            functions["$function_name"]=1

            # Reset flags for the new function
            hidden=false
            alias=""
            exclusions=()
            requires=()
            parameters=()
            annotations=()

            continue
        fi

        # Check for annotations and directives in the script
        if [[ "$line" =~ $_ARGIVO_REGEX_ANNOTATION ]]; then
            local annotation="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            case $annotation in
                argivo)
                    # Directives can only be defined before any function
                    if [[ "$is_directive_section" == false ]]; then
                        echo "error: @argivo directives must be declared before the first function"
                        return 1
                    fi

                    # @argivo requires a value
                    if [[ -z "$value" ]]; then
                        echo "error: @argivo annotation requires a value"
                        return 1
                    fi

                    # Validate syntax
                    if ! [[ "$value" =~ $_ARGIVO_REGEX_DIRECTIVE_VALUE ]]; then
                        echo "error: invalid @argivo syntax"
                        return 1
                    fi

                    local directive="${BASH_REMATCH[1]}"
                    local directive_value="${BASH_REMATCH[2]}"

                    # @argivo directive can only be declared once
                    if [[ -n "${directives[$directive]:-}" ]]; then
                        echo "error: duplicate @argivo directive: $directive"
                        return 1
                    fi

                    directives["$directive"]=1

                    case "$directive" in
                        check)
                            # Check that the value is boolean
                            if [[ ! "$directive_value" =~ $_ARGIVO_REGEX_BOOLEAN ]]; then
                                echo "error: invalid @argivo check: $directive_value"
                                return 1
                            fi
                        ;;

                        version)
                            # Check that the version is a valid semantic version
                            if [[ ! "$directive_value" =~ $_ARGIVO_REGEX_VERSION ]]; then
                                echo "error: invalid @argivo version: $directive_value"
                                return 1
                            fi

                            local required_major="${directive_value%%.*}"
                            local current_major="${_ARGIVO_VERSION%%.*}"

                            # Check that the major version matches
                            if [[ "$required_major" != "$current_major" ]]; then
                                echo "error: this script requires Argivo $required_major.x.x (current: $_ARGIVO_VERSION)"
                                return 1
                            fi
                        ;;

                        *)
                            echo "error: unsupported @argivo directive: $directive"
                            return 1
                        ;;
                    esac
                ;;

                desc)
                    is_directive_section=false
                    pending_annotations=true

                    # Annotations must be declared outside functions
                    if [[ "$is_function_section" == true ]]; then
                        echo "error: @desc cannot appear inside a function"
                        return 1
                    fi

                    # @desc requires a value
                    if [[ -z "$value" ]]; then
                        echo "error: @desc annotation requires a value"
                        return 1
                    fi

                    # @desc cannot be used twice at the same function
                    if [[ -n "${annotations[$annotation]:-}" ]]; then
                        echo "error: duplicate @$annotation annotation"
                        return 1
                    fi

                    annotations["$annotation"]=1
                ;;

                param)
                    is_directive_section=false
                    pending_annotations=true

                    # Annotations must be declared outside functions
                    if [[ "$is_function_section" == true ]]; then
                        echo "error: @param cannot appear inside a function"
                        return 1
                    fi

                    # @param requires a value
                    if [[ -z "$value" ]]; then
                        echo "error: @param annotation requires a value"
                        return 1
                    fi

                    # Validate syntax
                    if ! [[ "$value" =~ $_ARGIVO_REGEX_PARAM_SYNTAX ]]; then
                        echo "error: invalid @param syntax"
                        return 1
                    fi

                    # Get the parameter name from the annotation
                    local parameter
                    read -r parameter _ <<< "$value"

                    # Parameter names must be unique within the same function
                    if [[ -n "${parameters[$parameter]:-}" ]]; then
                        echo "error: duplicate parameter: $parameter"
                        return 1
                    fi

                    parameters["$parameter"]=1

                    # Check if type is supported
                    if [[ "$value" =~ $_ARGIVO_REGEX_PARAM_TYPE ]]; then
                        local type="${BASH_REMATCH[1]}"
                        local validator="argivo::is_$type"

                        if ! declare -F "$validator" >/dev/null; then
                            echo "error: unknown parameter type: $type"
                            return 1
                        fi
                    fi

                    # Check if default is a valid value based on its type
                    if [[ "$value" =~ $_ARGIVO_REGEX_PARAM_DEFAULT ]]; then
                        local default="${BASH_REMATCH[1]}"

                        if [[ -n "${type:-}" ]]; then
                            local validator="argivo::is_$type"

                            if ! "$validator" "$default"; then
                                echo "error: invalid default value '$default' for parameter '$parameter'"
                                return 1
                            fi
                        fi
                    fi
                ;;

                alias)
                    is_directive_section=false
                    pending_annotations=true

                    # Annotations must be declared outside functions
                    if [[ "$is_function_section" == true ]]; then
                        echo "error: @alias cannot appear inside a function"
                        return 1
                    fi

                    # @alias requires a value
                    if [[ -z "$value" ]]; then
                        echo "error: @alias annotation requires a value"
                        return 1
                    fi

                    # Alias must be a valid identifier
                    if ! [[ "$value" =~ $_ARGIVO_REGEX_IDENTIFIER ]]; then
                        echo "error: invalid @alias syntax"
                        return 1
                    fi

                    # Reversed command aliases like "-h" cannot be used
                    if [[ "$value" == "h" ]]; then
                        echo "error: reserved command alias: $value"
                        return 1
                    fi

                    # Alias must not collide with a command name
                    if [[ -n "${_ARGIVO_COMMANDS[$value]:-}" ]]; then
                        echo "error: alias conflicts with command name: $value"
                        return 1
                    fi

                    # @alias cannot be used twice at the same function
                    if [[ -n "${annotations[$annotation]:-}" ]]; then
                        echo "error: duplicate @$annotation annotation"
                        return 1
                    fi

                    annotations["$annotation"]=1

                    # Alias must be unique
                    if [[ -n "${aliases[$value]:-}" ]]; then
                        echo "error: duplicate alias: $value"
                        return 1
                    fi

                    aliases["$value"]=1
                    alias="$value"
                ;;

                hidden)
                    is_directive_section=false
                    pending_annotations=true

                    # Annotations must be declared outside functions
                    if [[ "$is_function_section" == true ]]; then
                        echo "error: @hidden cannot appear inside a function"
                        return 1
                    fi

                    # @hidden does not require a value
                    if [[ -n "$value" ]]; then
                        echo "error: @hidden annotation should not have a value"
                        return 1
                    fi

                    # @hidden cannot be used twice at the same function
                    if [[ -n "${annotations[$annotation]:-}" ]]; then
                        echo "error: duplicate @$annotation annotation"
                        return 1
                    fi

                    annotations["$annotation"]=1

                    # Used to check that the main function
                    # does not use @hidden
                    hidden=true
                ;;

                example)
                    is_directive_section=false
                    pending_annotations=true

                    # Annotations must be declared outside functions
                    if [[ "$is_function_section" == true ]]; then
                        echo "error: @example cannot appear inside a function"
                        return 1
                    fi

                    # @example requires a value
                    if [[ -z "$value" ]]; then
                        echo "error: @example annotation requires a value"
                        return 1
                    fi
                ;;

                excl)
                    is_directive_section=false
                    pending_annotations=true

                    # Annotations must be declared outside functions
                    if [[ "$is_function_section" == true ]]; then
                        echo "error: @excl cannot appear inside a function"
                        return 1
                    fi

                    # @excl requires a value
                    if [[ -z "$value" ]]; then
                        echo "error: @excl annotation requires a value"
                        return 1
                    fi

                    # Validate syntax
                    if ! [[ "$value" =~ $_ARGIVO_REGEX_IDENTIFIER_LIST ]]; then
                        echo "error: invalid @excl syntax"
                        return 1
                    fi

                    # @excl cannot be used twice at the same function
                    if [[ -n "${annotations[$annotation]:-}" ]]; then
                        echo "error: duplicate @$annotation annotation"
                        return 1
                    fi

                    annotations["$annotation"]=1

                    local group

                    # Check for duplicate exclusion groups within the same function
                    for group in $value; do
                        if [[ -n "${exclusions[$group]:-}" ]]; then
                            echo "error: duplicate exclusion group '$group'"
                            return 1
                        fi

                        exclusions["$group"]=1
                    done
                ;;

                req)
                    is_directive_section=false
                    pending_annotations=true

                    # Annotations must be declared outside functions
                    if [[ "$is_function_section" == true ]]; then
                        echo "error: @req cannot appear inside a function"
                        return 1
                    fi

                    # @req requires a value
                    if [[ -z "$value" ]]; then
                        echo "error: @req annotation requires a value"
                        return 1
                    fi

                    # Validate syntax
                    if ! [[ "$value" =~ $_ARGIVO_REGEX_IDENTIFIER_LIST ]]; then
                        echo "error: invalid @req syntax"
                        return 1
                    fi

                    # @req cannot be used twice at the same function
                    if [[ -n "${annotations[$annotation]:-}" ]]; then
                        echo "error: duplicate @$annotation annotation"
                        return 1
                    fi

                    annotations["$annotation"]=1

                    local required

                    # Check for duplicate required commands within the same function
                    for required in $value; do
                        # Duplicate require
                        if [[ -n "${requires[$required]:-}" ]]; then
                            echo "error: duplicate require: $required"
                            return 1
                        fi

                        # Required function does not exist
                        if [[ -z "${_ARGIVO_COMMANDS[$required]:-}" ]]; then
                            echo "error: unknown required command: $required"
                            return 1
                        fi

                        requires["$required"]=1
                    done
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

# Check that command dependencies do not contain cycles
function _argivo::validate_dependencies() {
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

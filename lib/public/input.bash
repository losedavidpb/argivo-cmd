#!/usr/bin/env bash
#
# input.bash - user input utilities for argivo

set -Eeuo pipefail

# Prompt the user for input
# Usage: argivo::prompt <message> [<type> [<default>]]
function argivo::prompt() {
    (($# > 0 && $# <= 3)) || return 1

    local value
    local message="$1"

    # Check that the provided type is supported
    if (($# >= 2)); then
        if ! argivo::_is_valid_type "$2"; then
            printf 'error: unknown input type: %s\n' "$2" >&2
            return 1
        fi
    fi

    # The prompt message can optionally include a default value, which
    # will be used if the user submits an empty response.
    if (($# == 3)); then
        # Display the default value in the prompt message
        message+=" [$3]"

        # Check that the default value matches the expected type
        if ! argivo::is_type "$3" "$2"; then
            printf 'error: default value must be of type %s\n' "$2" >&2
            return 1
        fi
    fi

    # Keep prompting until the user
    # provides a valid input
    while true; do
        read -rp "$message: " value || return 1

        # If only a message is provided, prompt the
        # user for input without considering its type
        if (($# == 1)); then
            printf '%s\n' "$value"
            return 0
        fi

        # If a default value is provided, use it when
        # the user submits an empty response
        if (($# == 3 )) && [[ -z $value ]]; then
            value="$3"
        fi

        # If a type is provided, check that the input
        # matches the expected type before returning it
        if ! argivo::is_type "$value" "$2"; then
            printf 'error: value must be of type %s\n' "$2" >&2
            continue
        fi

        printf '%s\n' "${value}"
        return 0
    done
}

# Prompt the user for a secret value
# Usage: argivo::secret <message> <needs_confirmation>
function argivo::secret() {
    (($# == 1 || $# == 2)) || return 1

    local value
    local confirmation

    # Keep prompting until the user provides
    # a valid secret value
    while true; do
        # Prompt the user for a secret value
        if ! read -rsp "$1: " value; then
            printf '\n' >&2
            return 1
        fi

        printf '\n' >&2

        # If confirmation is required, prompt the user
        # to confirm the secret value
        if (( $# == 2 )) && [[ "$2" == "true" ]]; then
            # Prompt the user to confirm the secret value
            if ! read -rsp "Confirm $1: " confirmation; then
                printf '\n' >&2
                return 1
            fi

            printf '\n' >&2

            # Check that the secret value and its confirmation match
            if [[ $value != "$confirmation" ]]; then
                printf 'error: %s does not match confirmation\n' "$1" >&2
                continue
            fi
        fi

        printf '%s\n' "$value"
        return 0
    done
}

# Prompt the user for confirmation
# Usage: argivo::confirm <message>
function argivo::confirm() {
    (($# == 1)) || return 1

    local value

    # Keep prompting until the user confirms
    # the action with a yes or no
    while true; do
        read -rp "$1 [y/n]: " value || return 1

        # Check that the input is a valid confirmation
        if [[ $value =~ ^[YyNn]$ ]]; then
            printf '%s\n' "${value,,}"
            return 0
        fi

        printf 'error: enter y or n\n' >&2
    done
}

# Prompt the user to select an option from a list
# Usage: argivo::select <options...>
function argivo::select() {
    (($# > 0)) || return 1

    local options=("$@")
    local value

    printf "Select one of the following options:\n" >&2

    # Display the options to the user
    for i in "${!options[@]}"; do
        printf '\t%s) %s\n' "$((i + 1))" "${options[i]}" >&2
    done

    # Keep prompting until the user
    # selects a valid option
    while true; do
        read -rp "Select an option [1-${#options[@]}]: " value || return 1

        # Check that the input is a valid number and
        # within the range of available options
        if [[ $value =~ ^[1-9][0-9]*$ ]]; then
            if ((value >= 1 && value <= ${#options[@]})); then
                printf '%s\n' "${options[value - 1]}"
                return 0
            fi
        fi

        printf 'error: select an option between 1 and %s\n' "${#options[@]}" >&2
    done
}
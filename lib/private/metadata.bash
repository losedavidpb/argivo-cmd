#!/usr/bin/env bash
#
# metadata.bash - general properties for argivo

set -Eeuo pipefail

# Prevent loading this module more than once
[[ -n "${_ARGIVO_METADATA_LOADED:-}" ]] && return 0
_ARGIVO_METADATA_LOADED=true

# Path to the argivo configuration file
_ARGIVO_CONF="/usr/local/lib/argivo/argivo.conf"

# The configuration file must exist and be readable
if [[ ! -f "$_ARGIVO_CONF" || ! -r "$_ARGIVO_CONF" ]]; then
    echo "error: argivo config file not found or not readable"
    return 1
fi

# Indicates whether load_metadata has already been executed
# shellcheck disable=SC2034
_ARGIVO_METADATA_PARSED=false

# ===== METADATA =====

# Loaded project metadata
_ARGIVO_NAME=""
_ARGIVO_VERSION=""
_ARGIVO_DESCRIPTION=""
_ARGIVO_ABOUT=""

# Load project metadata from argivo.conf
function _argivo::load_metadata() {
    # Metadata only needs to be parsed once
    $_ARGIVO_METADATA_PARSED && return

    local line

    # Current metadata entry being parsed
    local key=""
    local value=""
    local variable=""

    # Indicates if the current value is multiline
    local multiline=false

    while IFS= read -r line; do
        # Read the contents of a multiline value until
        # the closing triple quote is found
        if $multiline; then
            if [[ "$line" == '"""' ]]; then
                # Store the value into a global variable
                variable="_ARGIVO_${key^^}"
                printf -v "$variable" '%s' "${value%$'\n'}"

                # Reset the parser state to prepare
                # for the next metadata entry
                key=""
                value=""
                multiline=false

                continue
            fi

            # Append the current line to the multiline value
            value+="$line"$'\n'
            continue
        fi

        # Match supported configuration value formats
        case "$line" in
            # Multiline value
            *=\ \"\"\")
                # Extract the metadata key
                key="${line%%=*}"
                key="${key//[[:space:]]/}"

                # Start reading a multiline value
                value=""
                multiline=true
                ;;

            # Single-line value
            *=\ \"*\")
                # Extract the metadata key
                key="${line%%=*}"
                key="${key//[[:space:]]/}"

                # Extract the metadata value
                value="${line#*= }"
                value="${value#\"}"
                value="${value%\"}"

                # Store the value into a global variable
                variable="_ARGIVO_${key^^}"
                printf -v "$variable" '%s' "$value"

                # Reset the parser state to prepare
                # for the next metadata entry
                key=""
                value=""
                ;;
        esac
    done < "$_ARGIVO_CONF"

    # Ensure no multiline value was left unterminated
    if $multiline; then
        echo "error: unterminated multiline value in argivo.conf"
        return 1
    fi
}

# Initialize project metadata
_argivo::load_metadata

# Print the current version of argivo
function _argivo::version() {
    echo "$_ARGIVO_NAME $_ARGIVO_VERSION"
}

# Print general information about argivo
function _argivo::about() {
    echo "$_ARGIVO_NAME ($_ARGIVO_VERSION) - $_ARGIVO_DESCRIPTION"
    echo
    echo "$_ARGIVO_ABOUT"
}

# Print help information for a specific command
function _argivo::help() {
    _argivo::about
    echo

    # Show available commands for argivo
    echo "Available commands:"
    printf "  %-12s %s\n" "-v, --version" "Show version information"
    printf "  %-12s %s\n" "-a, --about"   "Show about information"
    printf "  %-12s %s\n" "-h, --help"    "Show help information"
    printf "  %-12s %s\n" "-c, --check"   "Validate command syntax"
}
#!/usr/bin/env bash
#
# metadata.bash - general properties for argivo

set -Eeuo pipefail

# Path for argivo configuration
_ARGIVO_CONF="/usr/local/lib/argivo/argivo.conf"

# Check that the configuration file exists
[[ ! -f "$_ARGIVO_CONF" ]] && {
    echo "error: argivo config file not found: $_ARGIVO_CONF"
    exit 1
}

# Check that the configuration file is readable
[[ ! -r "$_ARGIVO_CONF" ]] && {
    echo "error: argivo config file is not readable: $_ARGIVO_CONF"
    exit 1
}

## PROPERTIES ##

# shellcheck disable=SC2034
_ARGIVO_NAME="$(
    grep '^name[[:space:]]*=' "$_ARGIVO_CONF" \
        | sed -E 's/^[^"]*"([^"]+)".*/\1/'
)"

# shellcheck disable=SC2034
_ARGIVO_VERSION="$(
    grep '^version[[:space:]]*=' "$_ARGIVO_CONF" \
        | sed -E 's/^[^"]*"([^"]+)".*/\1/'
)"

# shellcheck disable=SC2034
_ARGIVO_DESCRIPTION="$(
    grep '^description[[:space:]]*=' "$_ARGIVO_CONF" \
        | sed -E 's/^[^"]*"([^"]+)".*/\1/'
)"

# shellcheck disable=SC2034
_ARGIVO_ABOUT="$(
    sed -n '/^about *= *"""/,/^"""/p' "$_ARGIVO_CONF" \
        | sed '1d;$d'
)"

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
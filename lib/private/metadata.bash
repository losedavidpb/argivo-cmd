#!/usr/bin/env bash
#
# metadata.bash - general properties for argivo

set -Eeuo pipefail

# Path for argivo configuration
ARGIVO_CONF="/usr/local/lib/argivo/argivo.conf"

# Check that the configuration file exists
[[ ! -f "$ARGIVO_CONF" ]] && {
    echo "error: argivo config file not found: $ARGIVO_CONF"
    exit 1
}

# Check that the configuration file is readable
[[ ! -r "$ARGIVO_CONF" ]] && {
    echo "error: argivo config file is not readable: $ARGIVO_CONF"
    exit 1
}

## PROPERTIES ##

# shellcheck disable=SC2034
ARGIVO_NAME="$(
    grep '^name[[:space:]]*=' "$ARGIVO_CONF" \
        | sed -E 's/^[^"]*"([^"]+)".*/\1/'
)"

# shellcheck disable=SC2034
ARGIVO_VERSION="$(
    grep '^version[[:space:]]*=' "$ARGIVO_CONF" \
        | sed -E 's/^[^"]*"([^"]+)".*/\1/'
)"

# shellcheck disable=SC2034
ARGIVO_DESCRIPTION="$(
    grep '^description[[:space:]]*=' "$ARGIVO_CONF" \
        | sed -E 's/^[^"]*"([^"]+)".*/\1/'
)"

# shellcheck disable=SC2034
ARGIVO_ABOUT="$(
    sed -n '/^about *= *"""/,/^"""/p' "$ARGIVO_CONF" \
        | sed '1d;$d'
)"

# Print the current version of argivo
function _argivo::version() {
    echo "$ARGIVO_NAME $ARGIVO_VERSION"
}

# Print general information about argivo
function _argivo::about() {
    echo "$ARGIVO_NAME ($ARGIVO_VERSION) - $ARGIVO_DESCRIPTION"
    echo
    echo "$ARGIVO_ABOUT"
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
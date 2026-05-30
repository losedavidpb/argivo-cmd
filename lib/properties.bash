#!/usr/bin/env bash
#
# properties.bash - general properties for argivo

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
function argivo::version() {
    echo "$ARGIVO_NAME $ARGIVO_VERSION"
}

# Print general information about argivo
function argivo::about() {
    echo "$ARGIVO_NAME ($ARGIVO_VERSION) - $ARGIVO_DESCRIPTION"
    echo
    echo "$ARGIVO_ABOUT"
}

# Print usage information for a specific command
function argivo::usage() {
    argivo::about
    echo

    # Show available commands for argivo
    echo "Available commands:"
    printf "  %-12s %s\n" "--version" "Show version information"
    printf "  %-12s %s\n" "--about"   "Show about information"
    printf "  %-12s %s\n" "--help"    "Show help information"
}
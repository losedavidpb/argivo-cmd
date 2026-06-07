#!/usr/bin/env bash
#
# assert.bash - assertion utilities for argivo

set -Eeuo pipefail

# Assert that a command succeeds
# Usage: argivo::assert <message> <command> [args...]
function argivo::assert() {
    (($# >= 2)) || { return 1; }

    local message="$1"
    shift

    # If the condition does not succeed,
    # show the provided error message
    "$@" || argivo::error "$message"
}

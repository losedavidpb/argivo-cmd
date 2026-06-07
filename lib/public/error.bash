#!/usr/bin/env bash
#
# error.bash - error handling utilities for argivo

set -Eeuo pipefail

# Show an error message and exit
# Usage: argivo::error <message>
function argivo::error() {
    (($# >= 1)) || { return 1; }
    printf 'error: %s\n' "$*" >&2
    exit 1
}
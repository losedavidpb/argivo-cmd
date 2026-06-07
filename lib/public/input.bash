#!/usr/bin/env bash
#
# input.bash - user input utilities for argivo

set -Eeuo pipefail

# Prompt the user for input
# Usage: argivo::prompt <message> [<default>]
function argivo::prompt() {
    (($# >= 1)) || { return 1; }

    local value

    # If a default value is provided, use it when
    # the user submits an empty response
    if (($# == 2)); then
        read -rp "$1 [$2]: " value
        printf '%s\n' "${value:-$2}"
    else
        read -rp "$1: " value
        printf '%s\n' "$value"
    fi
}
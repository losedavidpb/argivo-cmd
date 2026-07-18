#!/usr/bin/env bash
#
# uninstall.bash - uninstall script for argivo

set -Eeuo pipefail

# Installation paths to remove
_argivo_bin="/usr/local/bin/argivo"
_argivo_lib="/usr/local/lib/argivo"

# Run an uninstallation command with sudo when required
function _argivo::uninstall_command() {
    if ((EUID)); then sudo "$@"; else "$@"; fi
}

# Remove the executable and library directory
_argivo::uninstall_command rm -f -- "$_argivo_bin"
_argivo::uninstall_command rm -rf -- "$_argivo_lib"

echo "argivo uninstalled successfully"
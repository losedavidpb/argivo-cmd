#!/usr/bin/env bash
#
# uninstall.bash - uninstall script for argivo

set -Eeuo pipefail

# Directories for desinstallation
_argivo_bin="/usr/local/bin/argivo"
_argivo_lib="/usr/local/lib/argivo"

# Use sudo if not running as root
if [[ $EUID -ne 0 ]]; then
    sudo rm -f "$_argivo_bin"
    sudo rm -rf "$_argivo_lib"
else
    rm -f "$_argivo_bin"
    rm -rf "$_argivo_lib"
fi

echo "argivo uninstalled successfully"
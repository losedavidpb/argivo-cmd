#!/usr/bin/env bash
#
# uninstall.bash - uninstall script for argivo

set -Eeuo pipefail

# Directories for desinstallation
argivo_bin="/usr/local/bin/argivo"
argivo_lib="/usr/local/lib/argivo"

# Use sudo if not running as root
if [[ $EUID -ne 0 ]]; then
    sudo rm -f "$argivo_bin"
    sudo rm -rf "$argivo_lib"
else
    rm -f "$argivo_bin"
    rm -rf "$argivo_lib"
fi

echo "argivo uninstalled successfully"
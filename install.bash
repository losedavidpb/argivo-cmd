#!/usr/bin/env bash
#
# install.bash - installation script for argivo

set -Eeuo pipefail

# Get the directory of this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the argivo script to get the library path
argivo_source="$script_dir/argivo"

# Directories for installation
argivo_bin_dir="/usr/local/bin"
argivo_lib_dir="/usr/local/lib/argivo"

# Target path for the argivo executable
argivo_target="$argivo_bin_dir/argivo"

# Check that the Argivo executable exists
[[ -f "$argivo_source" ]] || {
    echo "error: argivo executable not found: $argivo_source"
    exit 1
}

# Use sudo if not running as root
if [[ $EUID -ne 0 ]]; then
    sudo mkdir -p "$argivo_lib_dir"

    sudo install -m 755 "$argivo_source" "$argivo_target"
    sudo install -m 644 "$script_dir"/lib/*.bash "$argivo_lib_dir/"
    sudo install -m 644 "$script_dir/argivo.conf" "$argivo_lib_dir/argivo.conf"
else
    mkdir -p "$argivo_lib_dir"

    install -m 755 "$argivo_source" "$argivo_target"
    install -m 644 "$script_dir"/lib/*.bash "$argivo_lib_dir/"
    install -m 644 "$script_dir/argivo.conf" "$argivo_lib_dir/argivo.conf"
fi

echo "argivo installed successfully"
echo "  binary: $argivo_target"
echo "  library: $argivo_lib_dir"
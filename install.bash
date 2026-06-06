#!/usr/bin/env bash
#
# install.bash - installation script for argivo

set -Eeuo pipefail

# Get the directory of this script
_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the argivo script to get the library path
_argivo_source="$_script_dir/argivo"

# Directories for installation
_argivo_bin_dir="/usr/local/bin"
_argivo_lib_dir="/usr/local/lib/argivo"

# Target path for the argivo executable
_argivo_target="$_argivo_bin_dir/argivo"

# Check that the Argivo executable exists
[[ -f "$_argivo_source" ]] || {
    echo "error: argivo executable not found: $_argivo_source"
    exit 1
}

# Use sudo if not running as root
if [[ $EUID -ne 0 ]]; then
    sudo mkdir -p "$_argivo_lib_dir"
    sudo mkdir -p "$_argivo_lib_dir/private"
    sudo mkdir -p "$_argivo_lib_dir/public"

    sudo install -m 755 "$_argivo_source" "$_argivo_target"
    sudo install -m 644 "$_script_dir"/lib/private/*.bash "$_argivo_lib_dir/private/"
    sudo install -m 644 "$_script_dir"/lib/public/*.bash "$_argivo_lib_dir/public/"
    sudo install -m 644 "$_script_dir/argivo.conf" "$_argivo_lib_dir/argivo.conf"
else
    mkdir -p "$_argivo_lib_dir"
    mkdir -p "$_argivo_lib_dir/private"
    mkdir -p "$_argivo_lib_dir/public"

    install -m 755 "$_argivo_source" "$_argivo_target"
    install -m 644 "$_script_dir"/lib/private/*.bash "$_argivo_lib_dir/private/"
    install -m 644 "$_script_dir"/lib/public/*.bash "$_argivo_lib_dir/public/"
    install -m 644 "$_script_dir/argivo.conf" "$_argivo_lib_dir/argivo.conf"
fi

echo "argivo installed successfully"
echo "  binary: $_argivo_target"
echo "  library: $_argivo_lib_dir"
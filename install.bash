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

# Run an installation command with sudo when required
function _argivo::install_command() {
    if ((EUID)); then sudo "$@"; else "$@"; fi
}

# Prepare the installation directories
_argivo::install_command mkdir -p "$_argivo_lib_dir"
_argivo::install_command mkdir -p "$_argivo_lib_dir/private"
_argivo::install_command mkdir -p "$_argivo_lib_dir/public"

# Install the executable, libraries, and configuration file
_argivo::install_command install -m 755 "$_argivo_source" "$_argivo_target"
_argivo::install_command install -m 644 "$_script_dir"/lib/private/*.bash "$_argivo_lib_dir/private/"
_argivo::install_command install -m 644 "$_script_dir"/lib/public/*.bash "$_argivo_lib_dir/public/"
_argivo::install_command install -m 644 "$_script_dir/argivo.conf" "$_argivo_lib_dir/argivo.conf"

# Remove installed modules that no longer exist in the current source tree
for _library_type in private public; do
    for _installed_lib in "$_argivo_lib_dir/$_library_type"/*.bash; do
        [[ -e "$_installed_lib" ]] || continue

        _lib_name="${_installed_lib##*/}"

        if [[ ! -f "$_script_dir/lib/$_library_type/$_lib_name" ]]; then
            _argivo::install_command rm -f -- "$_installed_lib"
        fi
    done
done

echo "argivo installed successfully"
echo "  binary: $_argivo_target"
echo "  library: $_argivo_lib_dir"
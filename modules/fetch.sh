#!/bin/bash
#
# Hectogon module for selecting fetch system information utility
# Part of BaseUtils for OpenBase GNU/Linux
# Developer: AnmiTaliDev
#
# Copyright (C) 2025 AnmiTaliDev
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Module metadata
MODULE_NAME="fetch"
MODULE_DESCRIPTION="Manage system fetch utility (fastfetch/neofetch/hsfetch)"
MODULE_AUTHOR="AnmiTaliDev"
MODULE_VERSION="1.0.0"

# Default paths
FETCH_BINDIR="/usr/bin"
WRAPPER_PATH="/usr/local/bin/fetch"
CONFIG_DIR="/etc/hectogon/fetch"
CONFIG_FILE="$CONFIG_DIR/current"
BACKUP_DIR="$CONFIG_DIR/backup"

# All supported fetch utilities
ALL_FETCHES=("fastfetch" "neofetch" "hsfetch")

# Initialize module
module_init() {
    # Create config and backup directories if they don't exist
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
    fi
    
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
    fi
}

# Find available and installed fetch utilities (not symlinks)
find_installed_fetches() {
    local installed_fetches=()
    
    for fetch in "${ALL_FETCHES[@]}"; do
        if command -v "$fetch" >/dev/null 2>&1; then
            # Check if it's a real binary and not a symlink to another fetch
            local fetch_path=$(command -v "$fetch")
            if [ ! -L "$fetch_path" ] || [[ "$(readlink -f "$fetch_path")" != *"fetch"* ]]; then
                installed_fetches+=("$fetch")
            fi
        fi
    done
    
    echo "${installed_fetches[@]}"
}

# Find all available fetch utilities (including symlinks)
find_available_fetches() {
    local available_fetches=()
    
    for fetch in "${ALL_FETCHES[@]}"; do
        if command -v "$fetch" >/dev/null 2>&1; then
            available_fetches+=("$fetch")
        fi
    done
    
    echo "${available_fetches[@]}"
}

# Get current fetch utility
get_current_fetch() {
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
        return 0
    elif [ -L "$WRAPPER_PATH" ]; then
        # If config file doesn't exist but wrapper does, use that
        local target
        target=$(readlink -f "$WRAPPER_PATH")
        basename "$target"
        return 0
    fi
    
    # No current fetch set
    return 1
}

# Backup original fetch utility if needed
backup_original() {
    local util=$1
    local util_path=$(command -v "$util")
    
    # Skip if already a symlink
    if [ -L "$util_path" ]; then
        return 0
    fi
    
    # Backup original binary if it exists and not already backed up
    if [ -f "$util_path" ] && [ ! -f "$BACKUP_DIR/$util.original" ]; then
        cp "$util_path" "$BACKUP_DIR/$util.original"
        echo "Backed up original $util to $BACKUP_DIR/$util.original"
    fi
    
    return 0
}

# Restore original binaries if they exist
restore_originals() {
    local current_fetch=$(get_current_fetch)
    
    # Restore all fetch utilities except the current one
    for fetch in "${ALL_FETCHES[@]}"; do
        if [ "$fetch" != "$current_fetch" ] && [ -f "$BACKUP_DIR/$fetch.original" ]; then
            local fetch_path=$(command -v "$fetch" 2>/dev/null)
            
            if [ -n "$fetch_path" ] && [ -L "$fetch_path" ]; then
                # Remove symlink
                rm -f "$fetch_path"
                
                # Restore original
                cp "$BACKUP_DIR/$fetch.original" "$fetch_path"
                chmod 755 "$fetch_path"
                echo "Restored original $fetch"
            fi
        fi
    done
}

# Create symlinks to make all fetch utils point to the selected one
create_fetch_symlinks() {
    local selected_fetch=$1
    local selected_path=$(command -v "$selected_fetch")
    
    # Find all installed fetch utilities
    local installed_fetches=( $(find_installed_fetches) )
    
    # Create main wrapper
    if [ -e "$WRAPPER_PATH" ]; then
        rm -f "$WRAPPER_PATH"
    fi
    
    # Create fetch wrapper symlink
    ln -sf "$selected_path" "$WRAPPER_PATH"
    echo "Created wrapper symlink: $WRAPPER_PATH -> $selected_path"
    
    # Now replace all other fetch utilities with symlinks to selected one
    for fetch in "${ALL_FETCHES[@]}"; do
        if [ "$fetch" != "$selected_fetch" ]; then
            local fetch_path=$(command -v "$fetch" 2>/dev/null)
            
            if [ -n "$fetch_path" ]; then
                # Backup original if not already a symlink
                if [ ! -L "$fetch_path" ]; then
                    backup_original "$fetch"
                fi
                
                # Replace with symlink to selected fetch
                rm -f "$fetch_path"
                ln -sf "$selected_path" "$fetch_path"
                echo "Created symlink: $fetch_path -> $selected_path"
            fi
        fi
    done
    
    # Save current selection to config file
    echo "$selected_fetch" > "$CONFIG_FILE"
    
    return 0
}

# List available fetch utilities
module_list() {
    local available_fetches
    local current_fetch=""
    
    # Get available fetches
    available_fetches=( $(find_available_fetches) )
    
    # Get current fetch if set
    if get_current_fetch >/dev/null 2>&1; then
        current_fetch=$(get_current_fetch)
    fi
    
    # Display available fetches
    if [ ${#available_fetches[@]} -eq 0 ]; then
        echo "No fetch utilities found"
        echo "Install at least one of: fastfetch, neofetch, hsfetch"
        return 1
    fi
    
    echo "Available fetch utilities:"
    for fetch in "${available_fetches[@]}"; do
        # Check if it's a symlink
        local fetch_path=$(command -v "$fetch")
        local symlink_info=""
        
        if [ -L "$fetch_path" ]; then
            local target=$(readlink -f "$fetch_path")
            local target_base=$(basename "$target")
            
            if [ "$target_base" != "$fetch" ]; then
                symlink_info=" -> $target_base"
            fi
        fi
        
        if [ "$fetch" = "$current_fetch" ]; then
            echo "* $fetch$symlink_info"
        else
            echo "  $fetch$symlink_info"
        fi
    done
    
    echo ""
    echo "Installed base utilities:"
    installed_fetches=( $(find_installed_fetches) )
    for fetch in "${installed_fetches[@]}"; do
        echo "  $fetch"
    done
    
    return 0
}

# Show current fetch utility
module_show() {
    local current_fetch
    
    if ! get_current_fetch >/dev/null 2>&1; then
        echo "No fetch utility selected"
        echo "Use 'hectogon fetch set <utility>' to select one"
        return 1
    fi
    
    current_fetch=$(get_current_fetch)
    echo "Current fetch utility: $current_fetch"
    
    # Check wrapper
    if [ -L "$WRAPPER_PATH" ]; then
        local target=$(readlink -f "$WRAPPER_PATH")
        echo "Wrapper script: $WRAPPER_PATH -> $target"
    else
        echo "Warning: Wrapper script not found or not a symlink"
    fi
    
    # Show fetch utility symlinks
    echo "Fetch utility symlinks:"
    for fetch in "${ALL_FETCHES[@]}"; do
        local fetch_path=$(command -v "$fetch" 2>/dev/null)
        if [ -n "$fetch_path" ] && [ -L "$fetch_path" ]; then
            local target=$(readlink -f "$fetch_path")
            local target_base=$(basename "$target")
            
            if [ "$target_base" != "$fetch" ]; then
                echo "  $fetch ($fetch_path) -> $target_base ($target)"
            fi
        elif [ -n "$fetch_path" ]; then
            echo "  $fetch ($fetch_path) - original binary"
        fi
    done
    
    return 0
}

# Set fetch utility
module_set() {
    local fetch_util=$1
    local installed_fetches
    
    # Check if utility name was provided
    if [ -z "$fetch_util" ]; then
        echo "Error: No fetch utility specified"
        echo "Available utilities:"
        module_list
        return 1
    fi
    
    # Check if utility exists as a real binary
    installed_fetches=( $(find_installed_fetches) )
    if ! echo "${installed_fetches[@]}" | grep -q "\b$fetch_util\b"; then
        echo "Error: Fetch utility '$fetch_util' not found or not installed"
        echo "Available base utilities:"
        for fetch in "${installed_fetches[@]}"; do
            echo "  $fetch"
        done
        return 1
    fi
    
    # Create symlinks
    echo "Setting fetch utility to: $fetch_util"
    if create_fetch_symlinks "$fetch_util"; then
        echo "Created symlinks for all fetch utilities to point to $fetch_util"
        echo "You can use any of these commands: fetch, ${ALL_FETCHES[*]}"
        return 0
    else
        echo "Failed to set fetch utility"
        return 1
    fi
}

# Restore original binaries
module_restore() {
    echo "Restoring original fetch utilities..."
    
    # Restore all utilities
    restore_originals
    
    # Remove main wrapper
    if [ -L "$WRAPPER_PATH" ]; then
        rm -f "$WRAPPER_PATH"
        echo "Removed wrapper: $WRAPPER_PATH"
    fi
    
    # Remove config
    if [ -f "$CONFIG_FILE" ]; then
        rm -f "$CONFIG_FILE"
    fi
    
    echo "All fetch utilities restored to their original binaries"
    return 0
}

# Add new fetch utility (not supported in this module)
module_add() {
    echo "Adding custom fetch utilities is not supported"
    echo "Install one of the supported utilities: ${ALL_FETCHES[*]}"
    return 1
}

# Remove fetch utility (not supported in this module)
module_remove() {
    echo "Removing fetch utilities is not supported"
    echo "Use your package manager to remove the utility"
    return 1
}

# Show help for fetch module
module_help() {
    echo "Hectogon fetch module"
    echo "Manages system fetch utility selection"
    echo ""
    echo "Usage:"
    echo "  hectogon fetch list         - List available fetch utilities"
    echo "  hectogon fetch show         - Show current fetch utility"
    echo "  hectogon fetch set <util>   - Set fetch utility to <util>"
    echo "  hectogon fetch restore      - Restore original fetch utilities"
    echo ""
    echo "Supported utilities:"
    echo "  - fastfetch: A fast system information tool"
    echo "  - neofetch:  A command-line system information tool"
    echo "  - hsfetch:   A lightweight system information fetch script"
    echo ""
    echo "When you set a utility (e.g., fastfetch), all other utilities"
    echo "will be replaced with symlinks to the selected one. This means"
    echo "you can use any of the commands (fetch, fastfetch, neofetch, hsfetch)"
    echo "and they will all use the selected utility."
    echo ""
    echo "Use 'restore' to revert to the original binaries."
    echo ""
    
    # Show version information
    if [ -n "$MODULE_VERSION" ]; then
        echo "Module version: $MODULE_VERSION"
    fi
    
    return 0
}

# Initialize module
module_init
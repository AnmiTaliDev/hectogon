#!/bin/bash
#
# Hectogon module for managing C compilers
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
MODULE_NAME="cc"
MODULE_DESCRIPTION="Manage system C compiler alternatives"
MODULE_AUTHOR="AnmiTaliDev"
MODULE_VERSION="1.0.0"

# Default paths
COMPILER_DIR="/usr/bin"
CONFIG_DIR="/etc/hectogon/cc"
CONFIG_FILE="$CONFIG_DIR/current"
PROFILE_DIR="/etc/profile.d"
ENV_FILE="$PROFILE_DIR/10-c-compiler.sh"
BACKUP_DIR="$CONFIG_DIR/backup"

# Compiler base names and versions to look for
# Format: Array of "<base-name>:<search-pattern>:<symlink>" entries
COMPILERS=(
    "gcc:gcc-[0-9]*:cc,gcc,c89,c99,c11,c23" 
    "clang:clang-[0-9]*:cc,clang"
)

# Verbose debug function
debug() {
    echo "DEBUG: $1" >&2
}

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

# Find compiler binaries (will work with both real and symlinked binaries)
find_compilers() {
    local available=()
    
    # Debug information
    debug "Searching for compilers in: $COMPILER_DIR and PATH"
    
    # Search for GCC and Clang in standard locations
    for base in "gcc" "clang"; do
        # Try to find in standard locations
        if [ -x "$COMPILER_DIR/$base" ]; then
            debug "Found $base in $COMPILER_DIR"
            if [ -L "$COMPILER_DIR/$base" ]; then
                debug "$COMPILER_DIR/$base is a symlink to $(readlink -f "$COMPILER_DIR/$base")"
            else
                debug "$COMPILER_DIR/$base is a real binary"
                available+=("$base")
            fi
        fi
        
        # Also search in other places in PATH
        which "$base" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            local path=$(which "$base")
            if [ "$path" != "$COMPILER_DIR/$base" ]; then
                debug "Found $base in $path"
                if [ -L "$path" ]; then
                    debug "$path is a symlink to $(readlink -f "$path")"
                else
                    debug "$path is a real binary"
                    available+=("$base")
                fi
            fi
        fi
    done
    
    # Find versioned compilers
    for compiler_entry in "${COMPILERS[@]}"; do
        local pattern=$(echo "$compiler_entry" | cut -d: -f2)
        
        debug "Searching for pattern $pattern in $COMPILER_DIR"
        
        # Find all matching compilers in compiler directory
        for binary in "$COMPILER_DIR"/$pattern; do
            if [ -f "$binary" ]; then
                debug "Found $binary"
                if [ -L "$binary" ]; then
                    debug "$binary is a symlink to $(readlink -f "$binary")"
                else
                    debug "$binary is a real binary"
                    available+=("$(basename "$binary")")
                fi
            fi
        done
    done
    
    # If no real binaries found, try to resolve symlinks to find real binaries
    if [ ${#available[@]} -eq 0 ]; then
        debug "No real binaries found, trying to resolve symlinks"
        
        for base in "gcc" "clang"; do
            local binary_path=$(which "$base" 2>/dev/null)
            if [ -n "$binary_path" ]; then
                # Follow symlinks to find the real binary
                local real_path=$(readlink -f "$binary_path")
                debug "Resolved $base to real path: $real_path"
                
                # Add the basename without version suffix to available list
                local base_name=$(echo "$(basename "$real_path")" | sed -E 's/(-[0-9]+.*)?$//')
                available+=("$base_name")
                debug "Added $base_name to available compilers list"
            fi
        done
    fi
    
    # Sort and remove duplicates
    if [ ${#available[@]} -gt 0 ]; then
        debug "Found available compilers: ${available[@]}"
        echo "${available[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '
    else
        debug "No available compilers found"
    fi
}

# Get real compiler path
get_real_compiler_path() {
    local compiler=$1
    local real_path=""
    
    debug "Searching for real binary of $compiler"
    
    # Check if it's a direct path to a real binary
    if [ -f "$compiler" ] && [ -x "$compiler" ] && [ ! -L "$compiler" ]; then
        debug "Found direct real binary: $compiler"
        echo "$compiler"
        return 0
    fi
    
    # Check in standard location
    if [ -f "$COMPILER_DIR/$compiler" ]; then
        if [ ! -L "$COMPILER_DIR/$compiler" ]; then
            debug "Found real binary in $COMPILER_DIR: $compiler"
            echo "$COMPILER_DIR/$compiler"
            return 0
        else
            # Follow symlink to real binary
            real_path=$(readlink -f "$COMPILER_DIR/$compiler")
            debug "Resolved $compiler to real path: $real_path"
            echo "$real_path"
            return 0
        fi
    fi
    
    # Try to find in PATH
    which "$compiler" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        local path=$(which "$compiler")
        debug "Found $compiler in PATH at: $path"
        
        if [ ! -L "$path" ]; then
            debug "$path is a real binary"
            echo "$path"
            return 0
        else
            # Follow symlink to real binary
            real_path=$(readlink -f "$path")
            debug "Resolved $path to real path: $real_path"
            echo "$real_path"
            return 0
        fi
    fi
    
    # As a last resort, try to find any binary with this name in common locations
    debug "Searching for $compiler in common locations"
    for dir in "/usr/bin" "/usr/local/bin" "/bin"; do
        if [ -f "$dir/$compiler" ] && [ -x "$dir/$compiler" ]; then
            debug "Found $compiler in $dir"
            if [ ! -L "$dir/$compiler" ]; then
                debug "$dir/$compiler is a real binary"
                echo "$dir/$compiler"
                return 0
            else
                # Follow symlink to real binary
                real_path=$(readlink -f "$dir/$compiler")
                debug "Resolved $dir/$compiler to real path: $real_path"
                echo "$real_path"
                return 0
            fi
        fi
    done
    
    # Try fuzzy match for versioned compilers
    debug "Trying fuzzy match for versioned compilers"
    for binary in "$COMPILER_DIR"/${compiler}* "$COMPILER_DIR"/*${compiler}*; do
        if [ -f "$binary" ] && [ -x "$binary" ]; then
            debug "Found potential match: $binary"
            if [ ! -L "$binary" ]; then
                debug "$binary is a real binary"
                echo "$binary"
                return 0
            else
                # Follow symlink to real binary
                real_path=$(readlink -f "$binary")
                debug "Resolved $binary to real path: $real_path"
                echo "$real_path"
                return 0
            fi
        fi
    done
    
    # Nothing found
    debug "No real binary found for $compiler"
    return 1
}

# Get current compiler
get_current_compiler() {
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
        return 0
    fi
    
    return 1
}

# Backup original compiler binaries
backup_original() {
    local symlink=$1
    local symlink_path="$COMPILER_DIR/$symlink"
    
    # Skip if it doesn't exist or is already a symlink
    if [ ! -e "$symlink_path" ] || [ -L "$symlink_path" ]; then
        return 0
    fi
    
    # Backup original binary if not already backed up
    if [ ! -f "$BACKUP_DIR/$symlink.original" ]; then
        cp "$symlink_path" "$BACKUP_DIR/$symlink.original"
        echo "Backed up original $symlink to $BACKUP_DIR/$symlink.original"
    fi
    
    return 0
}

# Create symlinks for a compiler
create_compiler_symlinks() {
    local compiler=$1
    local compiler_path=$(get_real_compiler_path "$compiler")
    
    if [ -z "$compiler_path" ]; then
        echo "Error: Real binary for $compiler not found"
        debug "get_real_compiler_path failed for $compiler"
        # Show some system information to help diagnose
        debug "Existing compiler binaries in $COMPILER_DIR:"
        ls -la "$COMPILER_DIR"/*cc* "$COMPILER_DIR"/*gcc* "$COMPILER_DIR"/*clang* 2>/dev/null || true
        return 1
    fi
    
    echo "Using real compiler binary: $compiler_path"
    
    # Check real binary
    if [ ! -x "$compiler_path" ]; then
        echo "Error: $compiler_path is not executable"
        return 1
    fi
    
    # Find which symlinks to create for this compiler
    local symlinks_to_create=()
    for compiler_entry in "${COMPILERS[@]}"; do
        local base_name=$(echo "$compiler_entry" | cut -d: -f1)
        local pattern=$(echo "$compiler_entry" | cut -d: -f2)
        local symlinks=$(echo "$compiler_entry" | cut -d: -f3)
        
        # If compiler matches base name or pattern
        if [ "$compiler" = "$base_name" ] || [[ "$compiler" =~ ${pattern//\[/\\[} ]]; then
            # Add all symlinks for this compiler type
            IFS=',' read -ra LINK_ARRAY <<< "$symlinks"
            for link in "${LINK_ARRAY[@]}"; do
                symlinks_to_create+=("$link")
            done
        fi
    done
    
    # If no symlinks matched by pattern, try to guess based on compiler name
    if [ ${#symlinks_to_create[@]} -eq 0 ]; then
        if [[ "$compiler" == *"gcc"* ]]; then
            symlinks_to_create=("cc" "gcc" "c89" "c99" "c11" "c23")
        elif [[ "$compiler" == *"clang"* ]]; then
            symlinks_to_create=("cc" "clang")
        else
            symlinks_to_create=("cc")
        fi
    fi
    
    # Remove duplicates
    symlinks_to_create=($(echo "${symlinks_to_create[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    
    echo "Will create the following symlinks: ${symlinks_to_create[@]}"
    
    # Create the symlinks
    for symlink in "${symlinks_to_create[@]}"; do
        local symlink_path="$COMPILER_DIR/$symlink"
        
        # Don't create a symlink to itself
        if [ "$(basename "$compiler_path")" = "$symlink" ]; then
            echo "Skipping self-symlink for $symlink"
            continue
        fi
        
        # Backup original if needed
        backup_original "$symlink"
        
        # Remove existing symlink or file
        if [ -e "$symlink_path" ]; then
            rm -f "$symlink_path"
        fi
        
        # Create new symlink directly to the real binary
        ln -sf "$compiler_path" "$symlink_path"
        echo "Created symlink: $symlink -> $compiler_path"
    done
    
    # Create environment file
    cat > "$ENV_FILE" <<EOF
# Generated by Hectogon CC module
# Selected C compiler: $compiler

export CC="$compiler_path"
export CPP="$compiler_path -E"
EOF
    
    chmod 644 "$ENV_FILE"
    
    # Save current compiler to config file
    echo "$compiler" > "$CONFIG_FILE"
    
    return 0
}

# Restore original compiler binaries
restore_originals() {
    # Find all backups
    for backup in "$BACKUP_DIR"/*.original; do
        if [ -f "$backup" ]; then
            local original=$(basename "$backup" .original)
            local original_path="$COMPILER_DIR/$original"
            
            # Remove symlink if exists
            if [ -L "$original_path" ]; then
                rm -f "$original_path"
                
                # Restore from backup
                cp "$backup" "$original_path"
                chmod 755 "$original_path"
                echo "Restored original $original"
            fi
        fi
    done
    
    # Remove environment file
    if [ -f "$ENV_FILE" ]; then
        rm -f "$ENV_FILE"
        echo "Removed environment file: $ENV_FILE"
    fi
    
    # Remove config file
    if [ -f "$CONFIG_FILE" ]; then
        rm -f "$CONFIG_FILE"
    fi
    
    return 0
}

# List available compilers
module_list() {
    local available_compilers
    local current_compiler=""
    
    # Get available compilers
    available_compilers=( $(find_compilers) )
    
    # Get current compiler if set
    if get_current_compiler >/dev/null 2>&1; then
        current_compiler=$(get_current_compiler)
    fi
    
    # Display available compilers
    if [ ${#available_compilers[@]} -eq 0 ]; then
        echo "No C compilers found"
        echo "Install at least one compiler (gcc, clang, etc.)"
        return 1
    fi
    
    for compiler in "${available_compilers[@]}"; do
        if [ "$compiler" = "$current_compiler" ]; then
            echo "* $compiler"
        else
            echo "  $compiler"
        fi
    done
    
    return 0
}

# Show current compiler
module_show() {
    local current_compiler
    
    if ! get_current_compiler >/dev/null 2>&1; then
        echo "No C compiler selected"
        echo "Use 'hectogon cc set <compiler>' to select one"
        return 1
    fi
    
    current_compiler=$(get_current_compiler)
    echo "Current C compiler: $current_compiler"
    
    # Show environment variables
    if [ -f "$ENV_FILE" ]; then
        echo ""
        echo "Environment variables:"
        grep "^export" "$ENV_FILE" | sed 's/export /  /'
    fi
    
    # Show active symlinks
    echo ""
    echo "Active C compiler symlinks:"
    for symlink in cc gcc c89 c99 c11 c23 clang; do
        if [ -L "$COMPILER_DIR/$symlink" ]; then
            local target=$(readlink -f "$COMPILER_DIR/$symlink")
            echo "  $symlink -> $(basename "$target")"
        elif [ -f "$COMPILER_DIR/$symlink" ] && [ ! -L "$COMPILER_DIR/$symlink" ]; then
            echo "  $symlink (original binary)"
        fi
    done
    
    return 0
}

# Set compiler
module_set() {
    local compiler=$1
    local available_compilers
    
    # Check if compiler name was provided
    if [ -z "$compiler" ]; then
        echo "Error: No compiler specified"
        echo "Available compilers:"
        module_list
        return 1
    fi
    
    # Get available compilers
    available_compilers=( $(find_compilers) )
    
    # If the specific compiler is not in the list but a variant might exist
    if ! echo "${available_compilers[@]}" | grep -qw "$compiler"; then
        debug "$compiler not found in available compilers list"
        debug "Looking for real binary directly"
        
        # Try to find the real binary directly
        if get_real_compiler_path "$compiler" > /dev/null 2>&1; then
            debug "Found real binary path for $compiler"
        else
            echo "Error: Compiler '$compiler' not found"
            echo "Available compilers:"
            module_list
            return 1
        fi
    fi
    
    # Set compiler
    echo "Setting system C compiler to: $compiler"
    if create_compiler_symlinks "$compiler"; then
        echo "Created compiler symlinks and environment settings"
        echo "You may need to log out and back in for environment changes to take effect"
        echo "or run: source $ENV_FILE"
        return 0
    else
        echo "Failed to set compiler"
        return 1
    fi
}

# Restore original compilers
module_restore() {
    echo "Restoring original C compiler binaries..."
    
    # Restore all compilers
    restore_originals
    
    echo "All C compiler binaries restored to original state"
    return 0
}

# Add new compiler (not supported in this module)
module_add() {
    echo "Adding custom compilers is not supported"
    echo "Install compilers using your package manager"
    return 1
}

# Remove compiler (not supported in this module)
module_remove() {
    echo "Removing compilers is not supported"
    echo "Use your package manager to remove compilers"
    return 1
}

# Show help for compiler module
module_help() {
    echo "Hectogon CC module"
    echo "Manages system C compiler alternatives"
    echo ""
    echo "Usage:"
    echo "  hectogon cc list         - List available C compilers"
    echo "  hectogon cc show         - Show current C compiler"
    echo "  hectogon cc set <compiler>   - Set system C compiler to <compiler>"
    echo "  hectogon cc restore      - Restore original C compiler binaries"
    echo ""
    echo "This module allows you to select the default C compiler"
    echo "for your system. It will create the appropriate symlinks for"
    echo "cc, gcc, c89, c99, c11, c23, etc. and set up environment variables."
    echo ""
    echo "Supported compilers:"
    echo "  - gcc (and versioned variants like gcc-12)"
    echo "  - clang (and versioned variants like clang-16)"
    echo ""
    echo "For C++ compilers management, use the 'cxx' module."
    echo ""
    echo "Note: You may need to log out and back in for environment"
    echo "changes to take effect, or source the environment file:"
    echo "  source $ENV_FILE"
    echo ""
    
    # Show version information
    if [ -n "$MODULE_VERSION" ]; then
        echo "Module version: $MODULE_VERSION"
    fi
    
    return 0
}

# Initialize module
module_init
#!/bin/bash
#
# Hectogon module for managing shell selection
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
MODULE_NAME="shell"
MODULE_DESCRIPTION="Manage default system shell"
MODULE_AUTHOR="AnmiTaliDev"
MODULE_VERSION="1.0.0"

# Default paths
SHELLS_FILE="/etc/shells"
PASSWD_FILE="/etc/passwd"
CONFIG_DIR="/etc/hectogon/shell"
CONFIG_FILE="$CONFIG_DIR/current"
BACKUP_FILE="$CONFIG_DIR/backup"
DEFAULT_SHELL="/bin/bash"

# Common shells to look for
COMMON_SHELLS=(
    "/bin/bash"
    "/bin/zsh"
    "/bin/fish"
    "/bin/dash"
    "/bin/sh"
    "/usr/bin/bash"
    "/usr/bin/zsh"
    "/usr/bin/fish"
    "/usr/bin/dash"
    "/usr/bin/sh"
)

# Initialize module
module_init() {
    # Create config directory if it doesn't exist
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
    fi
}

# Find available shells
find_shells() {
    local available_shells=()
    
    # Check if /etc/shells exists
    if [ -f "$SHELLS_FILE" ]; then
        # Read from /etc/shells
        while IFS= read -r shell; do
            # Skip comments and empty lines
            if [[ "$shell" =~ ^[[:space:]]*# ]] || [[ "$shell" =~ ^[[:space:]]*$ ]]; then
                continue
            fi
            
            # Check if shell exists and is executable
            if [ -x "$shell" ]; then
                available_shells+=("$shell")
            fi
        done < "$SHELLS_FILE"
    else
        # Fallback to common shells
        for shell in "${COMMON_SHELLS[@]}"; do
            if [ -x "$shell" ]; then
                available_shells+=("$shell")
            fi
        done
    fi
    
    # Output the shells
    for shell in "${available_shells[@]}"; do
        echo "$shell"
    done
}

# Get shell name from path
get_shell_name() {
    local shell_path="$1"
    basename "$shell_path"
}

# Get current default shell
get_default_shell() {
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
        return 0
    fi
    
    # Try to detect from /etc/passwd
    if [ -f "$PASSWD_FILE" ]; then
        local root_shell
        root_shell=$(grep "^root:" "$PASSWD_FILE" | cut -d: -f7)
        
        if [ -n "$root_shell" ]; then
            echo "$root_shell"
            return 0
        fi
    fi
    
    # Default fallback
    echo "$DEFAULT_SHELL"
    return 0
}

# Get user's current shell
get_user_shell() {
    local username="$1"
    
    # If no username provided, use current user
    if [ -z "$username" ]; then
        username="$(whoami)"
    fi
    
    # Get from /etc/passwd
    if [ -f "$PASSWD_FILE" ]; then
        local user_shell
        user_shell=$(grep "^$username:" "$PASSWD_FILE" | cut -d: -f7)
        
        if [ -n "$user_shell" ]; then
            echo "$user_shell"
            return 0
        fi
    fi
    
    # Use getent if available
    if command -v getent > /dev/null 2>&1; then
        local user_shell
        user_shell=$(getent passwd "$username" | cut -d: -f7)
        
        if [ -n "$user_shell" ]; then
            echo "$user_shell"
            return 0
        fi
    fi
    
    # Fallback
    echo "$DEFAULT_SHELL"
    return 0
}

# Check if a shell is valid
is_valid_shell() {
    local shell_to_check="$1"
    local available_shells=()
    
    # Get available shells
    mapfile -t available_shells < <(find_shells)
    
    # Check if the shell is in the list
    for shell in "${available_shells[@]}"; do
        if [ "$shell" = "$shell_to_check" ]; then
            return 0
        fi
    done
    
    return 1
}

# Backup current shells configuration
backup_shells_config() {
    if [ ! -f "$BACKUP_FILE" ]; then
        # Create a backup of current shells settings
        echo "Creating backup of current shells configuration..."
        
        if [ -f "$SHELLS_FILE" ]; then
            cp "$SHELLS_FILE" "$BACKUP_FILE.shells"
            echo "Backed up $SHELLS_FILE to $BACKUP_FILE.shells"
        fi
        
        # Save the current default shell
        local default_shell
        default_shell=$(get_default_shell)
        echo "$default_shell" > "$BACKUP_FILE.default"
        echo "Backed up default shell to $BACKUP_FILE.default"
    fi
}

# Set system default shell
set_system_default_shell() {
    local shell="$1"
    
    # Check if shell exists and is executable
    if [ ! -x "$shell" ]; then
        echo "Error: Shell '$shell' not found or not executable"
        return 1
    fi
    
    # Check if it's a valid shell
    if ! is_valid_shell "$shell"; then
        echo "Warning: '$shell' is not listed in $SHELLS_FILE"
        echo "Adding it to the list of valid shells..."
        
        # Add to /etc/shells if not already there
        if ! grep -q "^$shell$" "$SHELLS_FILE" 2>/dev/null; then
            echo "$shell" >> "$SHELLS_FILE"
            echo "Added $shell to $SHELLS_FILE"
        fi
    fi
    
    # Backup current configuration
    backup_shells_config
    
    # Save the new default shell
    echo "$shell" > "$CONFIG_FILE"
    
    # Set as the default for root
    if command -v chsh > /dev/null 2>&1; then
        echo "Setting system default shell to $shell..."
        chsh -s "$shell" root
        echo "Changed root's shell to $shell"
    else
        echo "Cannot change root's shell: chsh not found"
        return 1
    fi
    
    echo "System default shell set to: $shell"
    return 0
}

# Set user shell
set_user_shell() {
    local shell="$1"
    local username="$2"
    
    # If no username provided, use current user
    if [ -z "$username" ]; then
        username="$(whoami)"
    fi
    
    # Check if shell exists and is executable
    if [ ! -x "$shell" ]; then
        echo "Error: Shell '$shell' not found or not executable"
        return 1
    fi
    
    # Check if it's a valid shell
    if ! is_valid_shell "$shell"; then
        echo "Warning: '$shell' is not listed in $SHELLS_FILE"
        echo "This may prevent you from changing to this shell."
        echo "Run 'hectogon shell set $shell' as root to add it to valid shells."
        return 1
    fi
    
    # Set user's shell
    if command -v chsh > /dev/null 2>&1; then
        echo "Setting $username's shell to $shell..."
        
        if [ "$username" = "$(whoami)" ]; then
            chsh -s "$shell"
        else
            chsh -s "$shell" "$username"
        fi
        
        echo "Changed $username's shell to $shell"
        echo "The change will take effect after logging out and back in."
        return 0
    else
        echo "Cannot change shell: chsh not found"
        return 1
    fi
}

# Restore original shells configuration
restore_shells_config() {
    # Check if backup files exist
    if [ -f "$BACKUP_FILE.shells" ] && [ -f "$BACKUP_FILE.default" ]; then
        echo "Restoring shells configuration from backup..."
        
        # Restore /etc/shells
        cp "$BACKUP_FILE.shells" "$SHELLS_FILE"
        echo "Restored $SHELLS_FILE from backup"
        
        # Restore default shell
        local default_shell
        default_shell=$(cat "$BACKUP_FILE.default")
        
        # Set root's shell back to the original
        if command -v chsh > /dev/null 2>&1; then
            chsh -s "$default_shell" root
            echo "Changed root's shell back to $default_shell"
        else
            echo "Cannot change root's shell: chsh not found"
        fi
        
        # Remove config file
        if [ -f "$CONFIG_FILE" ]; then
            rm -f "$CONFIG_FILE"
        fi
        
        echo "Shell configuration restored from backup"
        return 0
    else
        echo "No backup files found"
        return 1
    fi
}

# List available shells
module_list() {
    local available_shells=()
    local current_default=""
    local current_user=""
    
    # Get available shells
    mapfile -t available_shells < <(find_shells)
    
    # Get current default shell
    current_default=$(get_default_shell)
    
    # Get current user shell
    current_user=$(get_user_shell)
    
    # Display available shells
    echo "Available shells:"
    for shell in "${available_shells[@]}"; do
        local shell_name=$(get_shell_name "$shell")
        local markers=""
        
        if [ "$shell" = "$current_default" ]; then
            markers+="D"  # Default shell
        fi
        
        if [ "$shell" = "$current_user" ]; then
            markers+="U"  # User shell
        fi
        
        if [ -n "$markers" ]; then
            echo "  $shell ($shell_name) [$markers]"
        else
            echo "  $shell ($shell_name)"
        fi
    done
    
    echo ""
    echo "Markers: D = System default shell, U = Current user's shell"
    
    return 0
}

# Show current shell
module_show() {
    local current_default=$(get_default_shell)
    local current_user=$(get_user_shell)
    local default_name=$(get_shell_name "$current_default")
    local user_name=$(get_shell_name "$current_user")
    
    echo "System default shell: $current_default ($default_name)"
    echo "Current user shell:   $current_user ($user_name)"
    
    # Show if they're not the same
    if [ "$current_default" != "$current_user" ]; then
        echo "Note: Your shell differs from the system default"
    fi
    
    return 0
}

# Set shell
module_set() {
    local shell="$1"
    local scope="$2"  # "system" or "user" or empty
    
    # Check if shell was provided
    if [ -z "$shell" ]; then
        echo "Error: No shell specified"
        echo "Usage: hectogon shell set <shell_path> [system|user]"
        echo "Available shells:"
        module_list
        return 1
    fi
    
    # If the shell is a name, convert to path
    if [[ ! "$shell" =~ ^/ ]]; then
        # Try to find the full path
        for path in "/bin" "/usr/bin"; do
            if [ -x "$path/$shell" ]; then
                shell="$path/$shell"
                break
            fi
        done
    fi
    
    # Check if shell exists
    if [ ! -x "$shell" ]; then
        echo "Error: Shell '$shell' not found or not executable"
        return 1
    fi
    
    # Default scope
    if [ -z "$scope" ]; then
        # If running as root, default to system
        if [ "$EUID" -eq 0 ]; then
            scope="system"
        else
            scope="user"
        fi
    fi
    
    case "$scope" in
        system)
            # Need root for system changes
            if [ "$EUID" -ne 0 ]; then
                echo "Error: You need root privileges to change the system default shell"
                echo "Try: sudo hectogon shell set $shell system"
                return 1
            fi
            
            set_system_default_shell "$shell"
            ;;
            
        user)
            set_user_shell "$shell"
            ;;
            
        *)
            echo "Error: Invalid scope '$scope'"
            echo "Usage: hectogon shell set <shell_path> [system|user]"
            return 1
            ;;
    esac
    
    return $?
}

# Restore original configuration
module_restore() {
    # Need root for system changes
    if [ "$EUID" -ne 0 ]; then
        echo "Error: You need root privileges to restore the shell configuration"
        echo "Try: sudo hectogon shell restore"
        return 1
    fi
    
    restore_shells_config
    return $?
}

# Add shell (not implemented separately, happens in set)
module_add() {
    echo "To add a new shell, use: hectogon shell set <shell_path>"
    echo "If the shell is not in $SHELLS_FILE, it will be added automatically"
    return 1
}

# Remove shell (not supported in this module)
module_remove() {
    echo "Removing shells from the system is not supported"
    echo "Use your package manager to remove shell packages"
    return 1
}

# Show help for shell module
module_help() {
    echo "Hectogon shell module"
    echo "Manages default system and user shells"
    echo ""
    echo "Usage:"
    echo "  hectogon shell list              - List available shells"
    echo "  hectogon shell show              - Show current shells"
    echo "  hectogon shell set <shell> [scope] - Set default shell"
    echo "  hectogon shell restore           - Restore original configuration"
    echo ""
    echo "Options:"
    echo "  <shell>   - Path to shell (/bin/bash, /bin/zsh, etc.) or name (bash, zsh)"
    echo "  [scope]   - 'system' for system-wide, 'user' for current user (default: user)"
    echo ""
    echo "Examples:"
    echo "  hectogon shell set /bin/zsh user    - Set current user's shell to zsh"
    echo "  sudo hectogon shell set /bin/bash system - Set system default shell to bash"
    echo ""
    echo "Note: Changing shells requires logging out and back in to take effect"
    echo ""
    
    # Show version information
    if [ -n "$MODULE_VERSION" ]; then
        echo "Module version: $MODULE_VERSION"
    fi
    
    return 0
}

# Initialize module
module_init
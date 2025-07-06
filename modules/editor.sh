#!/bin/bash
#
# Hectogon module for managing text editors
# Part of BaseUtils for OpenBase GNU/Linux
# Developer: AnmiTaliDev
#
# Copyright (C) 2025 AnmiTaliDev
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Module metadata
MODULE_NAME="editor"
MODULE_DESCRIPTION="Manage default text editor alternatives"
MODULE_AUTHOR="AnmiTaliDev"
MODULE_VERSION="1.0.0"

# Configuration
CONFIG_DIR="/etc/hectogon/editor"
CONFIG_FILE="$CONFIG_DIR/current"
BACKUP_DIR="$CONFIG_DIR/backup"
PROFILE_DIR="/etc/profile.d"
ENV_FILE="$PROFILE_DIR/10-editor.sh"

# Supported editors with their common variants and features
declare -A EDITORS=(
    ["vim"]="/usr/bin/vim,/bin/vim,/usr/local/bin/vim"
    ["nvim"]="/usr/bin/nvim,/usr/local/bin/nvim"
    ["nano"]="/usr/bin/nano,/bin/nano"
    ["emacs"]="/usr/bin/emacs,/usr/local/bin/emacs"
    ["code"]="/usr/bin/code,/usr/local/bin/code,/snap/bin/code"
    ["subl"]="/usr/bin/subl,/usr/local/bin/subl"
    ["atom"]="/usr/bin/atom,/usr/local/bin/atom"
    ["gedit"]="/usr/bin/gedit"
    ["kate"]="/usr/bin/kate"
    ["micro"]="/usr/bin/micro,/usr/local/bin/micro"
    ["helix"]="/usr/bin/hx,/usr/local/bin/hx"
    ["joe"]="/usr/bin/joe"
    ["mcedit"]="/usr/bin/mcedit"
    ["ne"]="/usr/bin/ne"
    ["ed"]="/bin/ed,/usr/bin/ed"
)

# Editor features/categories
declare -A EDITOR_FEATURES=(
    ["vim"]="terminal,modal,advanced"
    ["nvim"]="terminal,modal,advanced,modern"
    ["nano"]="terminal,simple,beginner"
    ["emacs"]="terminal,gui,advanced,extensible"
    ["code"]="gui,modern,ide,extensible"
    ["subl"]="gui,modern,fast"
    ["atom"]="gui,modern,extensible"
    ["gedit"]="gui,simple,gnome"
    ["kate"]="gui,advanced,kde"
    ["micro"]="terminal,modern,simple"
    ["helix"]="terminal,modal,modern"
    ["joe"]="terminal,simple"
    ["mcedit"]="terminal,simple"
    ["ne"]="terminal,simple"
    ["ed"]="terminal,minimal,historic"
)

# Initialize module
module_init() {
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
    fi
    
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
    fi
}

# Find available editors
find_available_editors() {
    local available_editors=()
    
    for editor in "${!EDITORS[@]}"; do
        IFS=',' read -ra PATHS <<< "${EDITORS[$editor]}"
        for path in "${PATHS[@]}"; do
            if [ -x "$path" ]; then
                available_editors+=("$editor:$path")
                break
            fi
        done
    done
    
    # Look for other editors in PATH
    local common_editors=("vi" "pico" "notepad++")
    for editor in "${common_editors[@]}"; do
        if command -v "$editor" >/dev/null 2>&1; then
            local editor_path=$(command -v "$editor")
            # Avoid duplicates
            local found=false
            for available in "${available_editors[@]}"; do
                if [[ "$available" == *":$editor_path" ]]; then
                    found=true
                    break
                fi
            done
            if [ "$found" = false ]; then
                available_editors+=("$editor:$editor_path")
            fi
        fi
    done
    
    printf '%s\n' "${available_editors[@]}"
}

# Get editor information
get_editor_info() {
    local editor_name="$1"
    local editor_path="$2"
    
    local version="Unknown"
    local description="Text editor"
    
    case "$editor_name" in
        vim)
            if [ -x "$editor_path" ]; then
                version=$("$editor_path" --version 2>/dev/null | head -1 | grep -o 'VIM [0-9]\+\.[0-9]\+' || echo "Unknown")
            fi
            description="Vi IMproved - highly configurable text editor"
            ;;
        nvim)
            if [ -x "$editor_path" ]; then
                version=$("$editor_path" --version 2>/dev/null | head -1 | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "Unknown")
            fi
            description="Neovim - hyperextensible Vim-based text editor"
            ;;
        nano)
            if [ -x "$editor_path" ]; then
                version=$("$editor_path" --version 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+' || echo "Unknown")
            fi
            description="GNU nano - simple terminal text editor"
            ;;
        emacs)
            if [ -x "$editor_path" ]; then
                version=$("$editor_path" --version 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+' || echo "Unknown")
            fi
            description="GNU Emacs - extensible, customizable text editor"
            ;;
        code)
            if [ -x "$editor_path" ]; then
                version=$("$editor_path" --version 2>/dev/null | head -1 || echo "Unknown")
            fi
            description="Visual Studio Code - modern code editor"
            ;;
        subl)
            description="Sublime Text - sophisticated text editor"
            ;;
        micro)
            if [ -x "$editor_path" ]; then
                version=$("$editor_path" --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "Unknown")
            fi
            description="Micro - modern and intuitive terminal-based text editor"
            ;;
        helix)
            if [ -x "$editor_path" ]; then
                version=$("$editor_path" --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+' || echo "Unknown")
            fi
            description="Helix - post-modern modal text editor"
            ;;
        *)
            description="Text editor"
            ;;
    esac
    
    echo "$version|$description"
}

# Get current editor
get_current_editor() {
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
        return 0
    fi
    
    # Try to detect from environment
    if [ -n "$EDITOR" ] && command -v "$EDITOR" >/dev/null 2>&1; then
        echo "$EDITOR"
        return 0
    fi
    
    # Try common alternatives
    for var in VISUAL FCEDIT; do
        if [ -n "${!var}" ] && command -v "${!var}" >/dev/null 2>&1; then
            echo "${!var}"
            return 0
        fi
    done
    
    return 1
}

# Create editor symlinks and environment
set_editor() {
    local editor_path="$1"
    local editor_name=$(basename "$editor_path")
    
    # Validate editor
    if [ ! -x "$editor_path" ]; then
        echo "Error: Editor '$editor_path' not found or not executable"
        return 1
    fi
    
    # Create backup
    if [ ! -f "$BACKUP_DIR/environment.backup" ] && [ -f "$ENV_FILE" ]; then
        cp "$ENV_FILE" "$BACKUP_DIR/environment.backup"
        echo "Created backup of current environment"
    fi
    
    # Create symlinks
    create_editor_symlinks "$editor_path"
    
    # Create environment file
    cat > "$ENV_FILE" <<EOF
# Generated by Hectogon editor module
# Default text editor configuration

export EDITOR="$editor_path"
export VISUAL="\$EDITOR"

# For programs that use specific editor variables
export FCEDIT="\$EDITOR"
export GIT_EDITOR="\$EDITOR"
export SVN_EDITOR="\$EDITOR"

# Sudo editor
export SUDO_EDITOR="\$EDITOR"

# For programs that might need terminal editors
case "\$(basename "\$EDITOR")" in
    code|subl|atom|gedit|kate)
        # GUI editors - set fallback terminal editor
        export TERMINAL_EDITOR="/usr/bin/nano"
        if command -v vim >/dev/null 2>&1; then
            export TERMINAL_EDITOR="/usr/bin/vim"
        fi
        ;;
    *)
        export TERMINAL_EDITOR="\$EDITOR"
        ;;
esac
EOF
    
    chmod 644 "$ENV_FILE"
    
    # Save current configuration
    echo "$editor_path" > "$CONFIG_FILE"
    
    echo "Editor set to: $editor_name ($editor_path)"
    echo "Restart your shell or run: source $ENV_FILE"
    
    return 0
}

# List available editors
module_list() {
    local available_editors
    mapfile -t available_editors < <(find_available_editors)
    
    if [ ${#available_editors[@]} -eq 0 ]; then
        echo "No text editors found"
        echo ""
        echo "Download and install a text editor:"
        echo "  VS Code:      https://code.visualstudio.com/"
        echo "  Sublime:      https://sublimetext.com/"
        echo "  Atom:         https://atom.io/"
        echo "  Vim:          https://vim.org/"
        echo "  Emacs:        https://gnu.org/software/emacs/"
        return 1
    fi
    
    local current_editor=""
    if get_current_editor >/dev/null 2>&1; then
        current_editor=$(get_current_editor)
    fi
    
    echo "Available text editors:"
    echo ""
    
    # Group by category
    local terminal_editors=()
    local gui_editors=()
    local other_editors=()
    
    for editor_info in "${available_editors[@]}"; do
        local editor_name="${editor_info%:*}"
        local editor_path="${editor_info#*:}"
        local features="${EDITOR_FEATURES[$editor_name]:-unknown}"
        
        if [[ "$features" == *"gui"* ]]; then
            gui_editors+=("$editor_info")
        elif [[ "$features" == *"terminal"* ]]; then
            terminal_editors+=("$editor_info")
        else
            other_editors+=("$editor_info")
        fi
    done
    
    # Display terminal editors
    if [ ${#terminal_editors[@]} -gt 0 ]; then
        echo "Terminal Editors:"
        for editor_info in "${terminal_editors[@]}"; do
            display_editor_info "$editor_info" "$current_editor"
        done
        echo ""
    fi
    
    # Display GUI editors
    if [ ${#gui_editors[@]} -gt 0 ]; then
        echo "GUI Editors:"
        for editor_info in "${gui_editors[@]}"; do
            display_editor_info "$editor_info" "$current_editor"
        done
        echo ""
    fi
    
    # Display other editors
    if [ ${#other_editors[@]} -gt 0 ]; then
        echo "Other Editors:"
        for editor_info in "${other_editors[@]}"; do
            display_editor_info "$editor_info" "$current_editor"
        done
        echo ""
    fi
    
    echo "* = Current default editor"
    
    return 0
}

# Display editor information helper
display_editor_info() {
    local editor_info="$1"
    local current_editor="$2"
    local editor_name="${editor_info%:*}"
    local editor_path="${editor_info#*:}"
    
    local marker="  "
    if [ "$editor_path" = "$current_editor" ] || [ "$editor_name" = "$(basename "$current_editor")" ]; then
        marker="* "
    fi
    
    local info
    info=$(get_editor_info "$editor_name" "$editor_path")
    local version="${info%|*}"
    local description="${info#*|}"
    local features="${EDITOR_FEATURES[$editor_name]:-unknown}"
    
    printf "%s %-12s %-15s %s\n" "$marker" "$editor_name" "$version" "$description"
    printf "    Path: %s\n" "$editor_path"
    if [ "$features" != "unknown" ]; then
        printf "    Features: %s\n" "$features"
    fi
    echo ""
}

# Show current editor
module_show() {
    local current_editor
    
    if ! get_current_editor >/dev/null 2>&1; then
        echo "No default editor configured"
        echo "Use 'hectogon editor set <editor>' to configure"
        return 1
    fi
    
    current_editor=$(get_current_editor)
    local editor_name=$(basename "$current_editor")
    
    local info
    info=$(get_editor_info "$editor_name" "$current_editor")
    local version="${info%|*}"
    local description="${info#*|}"
    
    echo "Current default editor: $editor_name"
    echo "Path: $current_editor"
    echo "Version: $version"
    echo "Description: $description"
    
    # Show environment variables
    if [ -f "$ENV_FILE" ]; then
        echo ""
        echo "Environment variables:"
        grep "^export" "$ENV_FILE" | sed 's/export /  /'
    fi
    
    # Show alternatives
    echo ""
    echo "Editor symlinks:"
    local editor_links=("/usr/bin/editor" "/usr/bin/vi")
    for link in "${editor_links[@]}"; do
        if [ -L "$link" ]; then
            local target=$(readlink -f "$link")
            echo "  $(basename "$link") -> $target"
        elif [ -f "$link" ]; then
            echo "  $(basename "$link") (original binary)"
        else
            echo "  $(basename "$link") (not found)"
        fi
    done
    
    return 0
}

# Set editor
module_set() {
    local editor_selection="$1"
    
    if [ -z "$editor_selection" ]; then
        echo "Error: No editor specified"
        echo "Available editors:"
        module_list
        return 1
    fi
    
    local available_editors
    mapfile -t available_editors < <(find_available_editors)
    
    local selected_editor=""
    
    # Search by name or path
    for editor_info in "${available_editors[@]}"; do
        local editor_name="${editor_info%:*}"
        local editor_path="${editor_info#*:}"
        
        if [ "$editor_name" = "$editor_selection" ] || [ "$editor_path" = "$editor_selection" ]; then
            selected_editor="$editor_path"
            break
        fi
    done
    
    # Search by partial match
    if [ -z "$selected_editor" ]; then
        local matches=()
        for editor_info in "${available_editors[@]}"; do
            local editor_name="${editor_info%:*}"
            if [[ "$editor_name" == *"$editor_selection"* ]]; then
                matches+=("${editor_info#*:}")
            fi
        done
        
        if [ ${#matches[@]} -eq 1 ]; then
            selected_editor="${matches[0]}"
        elif [ ${#matches[@]} -gt 1 ]; then
            echo "Error: Multiple matches found for '$editor_selection':"
            for match in "${matches[@]}"; do
                echo "  $(basename "$match")"
            done
            return 1
        fi
    fi
    
    # Direct path check
    if [ -z "$selected_editor" ] && [ -x "$editor_selection" ]; then
        selected_editor="$editor_selection"
    fi
    
    if [ -z "$selected_editor" ]; then
        echo "Error: Editor '$editor_selection' not found"
        echo "Available editors:"
        module_list
        return 1
    fi
    
    set_editor "$selected_editor"
    return $?
}

# Add custom editor
module_add() {
    local editor_path="$1"
    
    if [ -z "$editor_path" ]; then
        echo "Error: No editor path specified"
        echo "Usage: hectogon editor add <path_to_editor>"
        return 1
    fi
    
    if [ ! -f "$editor_path" ]; then
        echo "Error: File not found: $editor_path"
        return 1
    fi
    
    if [ ! -x "$editor_path" ]; then
        echo "Error: File is not executable: $editor_path"
        return 1
    fi
    
    local editor_name=$(basename "$editor_path")
    echo "Added custom editor: $editor_name"
    echo "Path: $editor_path"
    echo ""
    echo "This editor is now available for selection with:"
    echo "  hectogon editor set $editor_path"
    
    return 0
}

# Remove editor configuration
module_remove() {
    echo "This will reset editor configuration to system defaults"
    read -p "Are you sure? [y/N]: " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        return 1
    fi
    
    # Remove environment file
    if [ -f "$ENV_FILE" ]; then
        rm -f "$ENV_FILE"
        echo "Removed environment file: $ENV_FILE"
    fi
    
    # Remove configuration
    if [ -f "$CONFIG_FILE" ]; then
        rm -f "$CONFIG_FILE"
        echo "Removed configuration file"
    fi
    
    # Restore original binaries
    local editor_links=("/usr/bin/editor" "/usr/bin/vi")
    for link in "${editor_links[@]}"; do
        local backup_name=$(basename "$link")
        local backup_file="$BACKUP_DIR/$backup_name.original"
        
        if [ -f "$backup_file" ]; then
            if [ -L "$link" ]; then
                rm -f "$link"
                cp "$backup_file" "$link"
                chmod 755 "$link"
                echo "Restored original $link"
            fi
        else
            if [ -L "$link" ]; then
                rm -f "$link"
                echo "Removed symlink: $link"
            fi
        fi
    done
    
    echo "Editor configuration reset to system defaults"
    echo "Restart your shell for changes to take effect"
    
    return 0
}

# Show help
module_help() {
    echo "Hectogon editor module"
    echo "Manages default text editor configuration"
    echo ""
    echo "Usage:"
    echo "  hectogon editor list           - List available text editors"
    echo "  hectogon editor show           - Show current editor configuration"
    echo "  hectogon editor set <editor>   - Set default text editor"
    echo "  hectogon editor add <path>     - Add custom editor"
    echo "  hectogon editor remove         - Reset to system defaults"
    echo ""
    echo "Supported editors:"
    echo "  Terminal: vim, nvim, nano, emacs, micro, helix, joe, mcedit"
    echo "  GUI:      code, subl, atom, gedit, kate"
    echo ""
    echo "The module sets the following environment variables:"
    echo "  EDITOR, VISUAL, FCEDIT, GIT_EDITOR, SVN_EDITOR, SUDO_EDITOR"
    echo ""
    echo "For GUI editors, a fallback terminal editor is automatically configured."
    echo ""
    echo "Examples:"
    echo "  hectogon editor set vim        # Set vim as default editor"
    echo "  hectogon editor set code       # Set VS Code as default editor"
    echo "  hectogon editor add ~/my-editor # Add custom editor"
    echo ""
    
    if [ -n "$MODULE_VERSION" ]; then
        echo "Module version: $MODULE_VERSION"
    fi
    
    return 0
}

# Initialize module
module_init
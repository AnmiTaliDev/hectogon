#!/bin/bash
#
# Hectogon module for managing web browsers
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
MODULE_NAME="browser"
MODULE_DESCRIPTION="Manage default web browser alternatives"
MODULE_AUTHOR="AnmiTaliDev"
MODULE_VERSION="1.0.0"

# Configuration
CONFIG_DIR="/etc/hectogon/browser"
CONFIG_FILE="$CONFIG_DIR/current"
BACKUP_DIR="$CONFIG_DIR/backup"
PROFILE_DIR="/etc/profile.d"
ENV_FILE="$PROFILE_DIR/10-browser.sh"

# Browser symlinks to manage
BROWSER_LINKS=("/usr/bin/x-www-browser" "/usr/bin/www-browser" "/usr/bin/browser")

# Supported browsers with their common paths
declare -A BROWSERS=(
    ["firefox"]="/usr/bin/firefox,/usr/lib/firefox/firefox,/opt/firefox/firefox"
    ["firefox-esr"]="/usr/bin/firefox-esr"
    ["chromium"]="/usr/bin/chromium,/usr/bin/chromium-browser"
    ["google-chrome"]="/usr/bin/google-chrome,/opt/google/chrome/chrome"
    ["brave"]="/usr/bin/brave,/usr/bin/brave-browser,/opt/brave.com/brave/brave"
    ["opera"]="/usr/bin/opera,/usr/lib/x86_64-linux-gnu/opera/opera"
    ["vivaldi"]="/usr/bin/vivaldi,/opt/vivaldi/vivaldi"
    ["edge"]="/usr/bin/microsoft-edge,/opt/microsoft/msedge/msedge"
    ["tor-browser"]="/usr/bin/tor-browser,/opt/tor-browser/Browser/start-tor-browser"
    ["epiphany"]="/usr/bin/epiphany"
    ["konqueror"]="/usr/bin/konqueror"
    ["midori"]="/usr/bin/midori"
    ["qutebrowser"]="/usr/bin/qutebrowser"
    ["falkon"]="/usr/bin/falkon"
)

# Browser engines and features
declare -A BROWSER_INFO=(
    ["firefox"]="Mozilla Gecko|Open source web browser by Mozilla"
    ["firefox-esr"]="Mozilla Gecko|Firefox Extended Support Release"
    ["chromium"]="Blink|Open source web browser project"
    ["google-chrome"]="Blink|Web browser by Google"
    ["brave"]="Blink|Privacy-focused browser with ad blocking"
    ["opera"]="Blink|Web browser with built-in VPN and ad blocker"
    ["vivaldi"]="Blink|Highly customizable web browser"
    ["edge"]="Blink|Web browser by Microsoft"
    ["tor-browser"]="Mozilla Gecko|Privacy-focused browser for anonymous browsing"
    ["epiphany"]="WebKit|GNOME web browser"
    ["konqueror"]="KHTML/WebKit|KDE web browser and file manager"
    ["midori"]="WebKit|Lightweight web browser"
    ["qutebrowser"]="QtWebEngine|Keyboard-driven web browser"
    ["falkon"]="QtWebEngine|KDE web browser"
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

# Find available browsers
find_available_browsers() {
    local available_browsers=()
    
    # Check predefined browsers
    for browser in "${!BROWSERS[@]}"; do
        IFS=',' read -ra PATHS <<< "${BROWSERS[$browser]}"
        for path in "${PATHS[@]}"; do
            if [ -x "$path" ]; then
                available_browsers+=("$browser:$path")
                break
            fi
        done
    done
    
    # Look for other browsers in PATH
    local common_browsers=("lynx" "links" "w3m" "elinks")
    for browser in "${common_browsers[@]}"; do
        if command -v "$browser" >/dev/null 2>&1; then
            local browser_path=$(command -v "$browser")
            available_browsers+=("$browser:$browser_path")
        fi
    done
    
    printf '%s\n' "${available_browsers[@]}"
}

# Get browser information
get_browser_info() {
    local browser_name="$1"
    local browser_path="$2"
    
    local engine="Unknown"
    local description="Web browser"
    local version="Unknown"
    
    # Get info from predefined data
    if [[ -n "${BROWSER_INFO[$browser_name]}" ]]; then
        local info="${BROWSER_INFO[$browser_name]}"
        engine="${info%|*}"
        description="${info#*|}"
    fi
    
    # Try to get version
    case "$browser_name" in
        firefox|firefox-esr)
            if [ -x "$browser_path" ]; then
                version=$("$browser_path" --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+' | head -1 || echo "Unknown")
            fi
            ;;
        chromium|google-chrome|brave|opera|vivaldi|edge)
            if [ -x "$browser_path" ]; then
                version=$("$browser_path" --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo "Unknown")
            fi
            ;;
        *)
            if [ -x "$browser_path" ]; then
                version=$("$browser_path" --version 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+' | head -1 || echo "Unknown")
            fi
            ;;
    esac
    
    echo "$engine|$version|$description"
}

# Get current browser
get_current_browser() {
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
        return 0
    fi
    
    # Try to detect from environment
    if [ -n "$BROWSER" ] && command -v "$BROWSER" >/dev/null 2>&1; then
        echo "$BROWSER"
        return 0
    fi
    
    return 1
}

# Backup existing binaries
backup_browser_binaries() {
    for link in "${BROWSER_LINKS[@]}"; do
        if [ -f "$link" ] && [ ! -L "$link" ]; then
            local backup_name=$(basename "$link")
            if [ ! -f "$BACKUP_DIR/$backup_name.original" ]; then
                cp "$link" "$BACKUP_DIR/$backup_name.original"
                echo "Backed up original $link"
            fi
        fi
    done
}

# Create browser symlinks
create_browser_symlinks() {
    local browser_path="$1"
    
    # Create symlinks for common browser paths
    for link in "${BROWSER_LINKS[@]}"; do
        # Remove existing file/symlink
        if [ -e "$link" ]; then
            rm -f "$link"
        fi
        
        # Create new symlink
        ln -sf "$browser_path" "$link"
        echo "Created symlink: $link -> $browser_path"
    done
    
    return 0
}

# Set default browser
set_default_browser() {
    local browser_path="$1"
    local browser_name=$(basename "$browser_path")
    
    # Validate browser
    if [ ! -x "$browser_path" ]; then
        echo "Error: Browser '$browser_path' not found or not executable"
        return 1
    fi
    
    echo "Setting default browser to: $browser_name"
    
    # Backup existing binaries
    backup_browser_binaries
    
    # Create symlinks
    create_browser_symlinks "$browser_path"
    
    # Create environment file
    cat > "$ENV_FILE" <<EOF
# Generated by Hectogon browser module
# Default web browser configuration

export BROWSER="$browser_path"
export WWW_BROWSER="\$BROWSER"

# For applications that might need browser
export DEFAULT_BROWSER="\$BROWSER"
EOF
    
    chmod 644 "$ENV_FILE"
    
    # Set xdg default if available
    if command -v xdg-settings >/dev/null 2>&1; then
        # Find desktop file for browser
        local desktop_file=""
        case "$browser_name" in
            firefox) desktop_file="firefox.desktop" ;;
            chromium) desktop_file="chromium.desktop" ;;
            google-chrome) desktop_file="google-chrome.desktop" ;;
            brave) desktop_file="brave-browser.desktop" ;;
            *) desktop_file="" ;;
        esac
        
        if [ -n "$desktop_file" ]; then
            xdg-settings set default-web-browser "$desktop_file" 2>/dev/null || true
        fi
    fi
    
    # Save current configuration
    echo "$browser_path" > "$CONFIG_FILE"
    
    echo "Browser configuration complete"
    echo "Restart your shell or run: source $ENV_FILE"
    
    return 0
}

# List available browsers
module_list() {
    local available_browsers
    mapfile -t available_browsers < <(find_available_browsers)
    
    if [ ${#available_browsers[@]} -eq 0 ]; then
        echo "No web browsers found"
        echo ""
        echo "Download and install a web browser:"
        echo "  Firefox:      https://firefox.com/"
        echo "  Chrome:       https://chrome.google.com/"
        echo "  Brave:        https://brave.com/"
        echo "  Opera:        https://opera.com/"
        echo "  Vivaldi:      https://vivaldi.com/"
        return 1
    fi
    
    local current_browser=""
    if get_current_browser >/dev/null 2>&1; then
        current_browser=$(get_current_browser)
    fi
    
    echo "Available web browsers:"
    echo ""
    
    for browser_info in "${available_browsers[@]}"; do
        local browser_name="${browser_info%:*}"
        local browser_path="${browser_info#*:}"
        
        local marker="  "
        if [ "$browser_path" = "$current_browser" ]; then
            marker="* "
        fi
        
        local info
        info=$(get_browser_info "$browser_name" "$browser_path")
        local engine="${info%%|*}"
        local version=$(echo "$info" | cut -d'|' -f2)
        local description=$(echo "$info" | cut -d'|' -f3)
        
        printf "%s %-15s %-12s %-15s\n" "$marker" "$browser_name" "$version" "$engine"
        printf "    %s\n" "$description"
        printf "    Path: %s\n" "$browser_path"
        echo ""
    done
    
    echo "* = Current default browser"
    
    return 0
}

# Show current browser
module_show() {
    local current_browser
    
    if ! get_current_browser >/dev/null 2>&1; then
        echo "No default browser configured"
        echo "Use 'hectogon browser set <browser>' to configure"
        return 1
    fi
    
    current_browser=$(get_current_browser)
    local browser_name=$(basename "$current_browser")
    
    local info
    info=$(get_browser_info "$browser_name" "$current_browser")
    local engine="${info%%|*}"
    local version=$(echo "$info" | cut -d'|' -f2)
    local description=$(echo "$info" | cut -d'|' -f3)
    
    echo "Current default browser: $browser_name"
    echo "Path: $current_browser"
    echo "Engine: $engine" 
    echo "Version: $version"
    echo "Description: $description"
    
    # Show environment variables
    if [ -f "$ENV_FILE" ]; then
        echo ""
        echo "Environment variables:"
        grep "^export" "$ENV_FILE" | sed 's/export /  /'
    fi
    
    # Show active symlinks
    echo ""
    echo "Browser symlinks:"
    for link in "${BROWSER_LINKS[@]}"; do
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

# Set browser
module_set() {
    local browser_selection="$1"
    
    if [ -z "$browser_selection" ]; then
        echo "Error: No browser specified"
        echo "Available browsers:"
        module_list
        return 1
    fi
    
    local available_browsers
    mapfile -t available_browsers < <(find_available_browsers)
    
    local selected_browser=""
    
    # Search by name or path
    for browser_info in "${available_browsers[@]}"; do
        local browser_name="${browser_info%:*}"
        local browser_path="${browser_info#*:}"
        
        if [ "$browser_name" = "$browser_selection" ] || [ "$browser_path" = "$browser_selection" ]; then
            selected_browser="$browser_path"
            break
        fi
    done
    
    # Search by partial match
    if [ -z "$selected_browser" ]; then
        local matches=()
        for browser_info in "${available_browsers[@]}"; do
            local browser_name="${browser_info%:*}"
            if [[ "$browser_name" == *"$browser_selection"* ]]; then
                matches+=("${browser_info#*:}")
            fi
        done
        
        if [ ${#matches[@]} -eq 1 ]; then
            selected_browser="${matches[0]}"
        elif [ ${#matches[@]} -gt 1 ]; then
            echo "Error: Multiple matches found for '$browser_selection':"
            for match in "${matches[@]}"; do
                echo "  $(basename "$match")"
            done
            return 1
        fi
    fi
    
    # Direct path check
    if [ -z "$selected_browser" ] && [ -x "$browser_selection" ]; then
        selected_browser="$browser_selection"
    fi
    
    if [ -z "$selected_browser" ]; then
        echo "Error: Browser '$browser_selection' not found"
        echo "Available browsers:"
        module_list
        return 1
    fi
    
    set_default_browser "$selected_browser"
    return $?
}

# Add custom browser
module_add() {
    local browser_path="$1"
    
    if [ -z "$browser_path" ]; then
        echo "Error: No browser path specified"
        echo "Usage: hectogon browser add <path_to_browser>"
        return 1
    fi
    
    if [ ! -f "$browser_path" ]; then
        echo "Error: File not found: $browser_path"
        return 1
    fi
    
    if [ ! -x "$browser_path" ]; then
        echo "Error: File is not executable: $browser_path"
        return 1
    fi
    
    local browser_name=$(basename "$browser_path")
    echo "Added custom browser: $browser_name"
    echo "Path: $browser_path"
    echo ""
    echo "This browser is now available for selection with:"
    echo "  hectogon browser set $browser_path"
    
    return 0
}

# Remove browser configuration
module_remove() {
    echo "This will reset browser configuration to system defaults"
    read -p "Are you sure? [y/N]: " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        return 1
    fi
    
    # Restore original binaries
    for link in "${BROWSER_LINKS[@]}"; do
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
    
    echo "Browser configuration reset to system defaults"
    echo "Restart your shell for changes to take effect"
    
    return 0
}

# Show help
module_help() {
    echo "Hectogon browser module"
    echo "Manages default web browser configuration"
    echo ""
    echo "Usage:"
    echo "  hectogon browser list           - List available web browsers"
    echo "  hectogon browser show           - Show current browser configuration"
    echo "  hectogon browser set <browser>  - Set default web browser"
    echo "  hectogon browser add <path>     - Add custom browser"
    echo "  hectogon browser remove         - Reset to system defaults"
    echo ""
    echo "Supported browsers:"
    echo "  GUI:      firefox, chromium, google-chrome, brave, opera, vivaldi"
    echo "  Terminal: lynx, links, w3m, elinks"
    echo "  Other:    epiphany, konqueror, midori, qutebrowser, falkon"
    echo ""
    echo "The module creates symlinks for:"
    for link in "${BROWSER_LINKS[@]}"; do
        echo "  $(basename "$link")"
    done
    echo ""
    echo "Environment variables set:"
    echo "  BROWSER, WWW_BROWSER, DEFAULT_BROWSER"
    echo ""
    echo "Examples:"
    echo "  hectogon browser set firefox    # Set Firefox as default browser"
    echo "  hectogon browser set chromium   # Set Chromium as default browser"
    echo "  hectogon browser add ~/mybrowser # Add custom browser"
    echo ""
    
    if [ -n "$MODULE_VERSION" ]; then
        echo "Module version: $MODULE_VERSION"
    fi
    
    return 0
}

# Initialize module
module_init
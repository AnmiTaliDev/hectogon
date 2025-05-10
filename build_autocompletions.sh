#!/bin/bash
#
# Hectogon - Autocompletions builder
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

set -e

# Output directory
OUTPUT_DIR="autocompletions"

# Colors for output
if [ -t 1 ]; then
    BOLD="\033[1m"
    RED="\033[31m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    BLUE="\033[34m"
    RESET="\033[0m"
else
    BOLD=""
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    RESET=""
fi

# Print functions
info() {
    echo -e "${BLUE}*${RESET} $1"
}

success() {
    echo -e "${GREEN}✓${RESET} $1"
}

error() {
    echo -e "${RED}✗${RESET} $1" >&2
    exit 1
}

# Show help
show_help() {
    echo -e "${BOLD}Hectogon Autocompletions Builder${RESET}"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --output=DIR       Set output directory (default: autocompletions)"
    echo "  --help             Display this help message"
    echo ""
    echo "Example:"
    echo "  $0 --output=./completions"
    echo ""
}

# Parse command line arguments
parse_args() {
    for arg in "$@"; do
        case $arg in
            --output=*)
                OUTPUT_DIR="${arg#*=}"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $arg"
                ;;
        esac
    done
}

# Create output directory
create_output_dir() {
    if [ ! -d "$OUTPUT_DIR" ]; then
        info "Creating output directory: $OUTPUT_DIR"
        mkdir -p "$OUTPUT_DIR"
    fi
}

# Create Bash completion script
create_bash_completion() {
    info "Creating Bash completion script..."
    
    cat > "$OUTPUT_DIR/bash.sh" <<'EOF'
#!/bin/bash
# Bash completion for Hectogon

_hectogon() {
    local cur prev opts modules module_actions
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Basic commands
    opts="list help version"
    
    # Get list of available modules
    if [ -d "/usr/share/hectogon/modules" ]; then
        modules=$(find /usr/share/hectogon/modules -type f -name "*.sh" 2>/dev/null | sed -e 's|.*/||' -e 's|\.sh$||' | sort)
    fi
    
    # Check for custom modules
    if [ -d "/etc/hectogon/modules" ]; then
        modules="$modules $(find /etc/hectogon/modules -type f -name "*.sh" 2>/dev/null | sed -e 's|.*/||' -e 's|\.sh$||' | sort)"
    fi
    
    # Module actions
    module_actions="list show set add remove help"
    
    # First argument
    if [ $COMP_CWORD -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$opts $modules" -- "$cur") )
        return 0
    fi
    
    # If previous word is a module
    if echo " $modules " | grep -q " $prev "; then
        COMPREPLY=( $(compgen -W "$module_actions" -- "$cur") )
        return 0
    fi
    
    # If we're after a module action
    if [ $COMP_CWORD -ge 3 ]; then
        module="${COMP_WORDS[1]}"
        action="${COMP_WORDS[2]}"
        
        # Complete for 'set' and 'remove' actions
        if [ "$action" = "set" ] || [ "$action" = "remove" ]; then
            # Try to get options from the module
            if command -v hectogon >/dev/null 2>&1; then
                options=$(hectogon "$module" list 2>/dev/null | grep -v "^\*" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]].*$//')
                COMPREPLY=( $(compgen -W "$options" -- "$cur") )
                return 0
            fi
        fi
        
        # Complete files for 'add' action
        if [ "$action" = "add" ]; then
            COMPREPLY=( $(compgen -f -- "$cur") )
            return 0
        fi
    fi
    
    return 0
}

complete -F _hectogon hectogon
EOF

    chmod 644 "$OUTPUT_DIR/bash.sh"
    success "Created: $OUTPUT_DIR/bash.sh"
}

# Create Zsh completion script
create_zsh_completion() {
    info "Creating Zsh completion script..."
    
    cat > "$OUTPUT_DIR/zsh.sh" <<'EOF'
#compdef hectogon
# Zsh completion for Hectogon

_hectogon_modules() {
    local -a modules
    local module_dir="/usr/share/hectogon/modules"
    local custom_dir="/etc/hectogon/modules"
    
    # Get standard modules
    if [[ -d "$module_dir" ]]; then
        modules=( ${module_dir}/*.sh(N:t:r) )
    fi
    
    # Get custom modules
    if [[ -d "$custom_dir" ]]; then
        modules+=( ${custom_dir}/*.sh(N:t:r) )
    fi
    
    echo $modules
}

_hectogon_module_options() {
    local module=$1
    local options
    
    if (( $+commands[hectogon] )); then
        options=(${(f)"$(hectogon $module list 2>/dev/null | grep -v '^\*' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]].*$//')"})
        _values 'options' $options
    fi
}

_hectogon() {
    local -a commands modules actions
    local state
    
    _arguments -C \
        '1: :->command' \
        '2: :->action' \
        '3: :->option' \
        '*: :->args'
    
    case $state in
        command)
            commands=(
                'list:List all available modules'
                'help:Show help message'
                'version:Show version information'
            )
            
            # Add modules
            modules=($(_hectogon_modules))
            for module in $modules; do
                commands+=("$module:Module")
            done
            
            _describe -t commands 'hectogon commands' commands
            ;;
            
        action)
            case $words[2] in
                list|help|version)
                    # No actions for these commands
                    ;;
                *)
                    # Module actions
                    actions=(
                        'list:List available options'
                        'show:Show current option'
                        'set:Set an option'
                        'add:Add a new option'
                        'remove:Remove an option'
                        'help:Show module help'
                    )
                    _describe -t actions 'module actions' actions
                    ;;
            esac
            ;;
            
        option)
            case $words[3] in
                set|remove)
                    _hectogon_module_options $words[2]
                    ;;
                    
                add)
                    _files
                    ;;
            esac
            ;;
            
        args)
            # No additional arguments
            ;;
    esac
}

_hectogon "$@"
EOF

    chmod 644 "$OUTPUT_DIR/zsh.sh"
    success "Created: $OUTPUT_DIR/zsh.sh"
}

# Create Fish completion script
create_fish_completion() {
    info "Creating Fish completion script..."
    
    cat > "$OUTPUT_DIR/fish.sh" <<'EOF'
# Fish shell completions for Hectogon

function __fish_hectogon_modules
    if test -d "/usr/share/hectogon/modules"
        find /usr/share/hectogon/modules -type f -name "*.sh" 2>/dev/null | sed -e 's|.*/||' -e 's|\.sh$||' | sort
    end
    
    if test -d "/etc/hectogon/modules"
        find /etc/hectogon/modules -type f -name "*.sh" 2>/dev/null | sed -e 's|.*/||' -e 's|\.sh$||' | sort
    end
end

function __fish_hectogon_module_options
    set -l cmd (commandline -opc)
    if test (count $cmd) -gt 1
        hectogon $cmd[2] list 2>/dev/null | grep -v "^\*" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]].*$//'
    end
end

function __fish_hectogon_no_subcommand
    set -l cmd (commandline -opc)
    if test (count $cmd) -eq 1
        return 0
    end
    return 1
end

function __fish_hectogon_using_command
    set -l cmd (commandline -opc)
    if test (count $cmd) -gt 1
        if test $argv[1] = $cmd[2]
            return 0
        end
    end
    return 1
end

function __fish_hectogon_using_module
    set -l cmd (commandline -opc)
    if test (count $cmd) -gt 1
        for module in (__fish_hectogon_modules)
            if test $module = $cmd[2]
                return 0
            end
        end
    end
    return 1
end

function __fish_hectogon_using_module_action
    set -l cmd (commandline -opc)
    if test (count $cmd) -gt 2
        if test $argv[1] = $cmd[3]
            return 0
        end
    end
    return 1
end

# Main commands
complete -f -c hectogon -n '__fish_hectogon_no_subcommand' -a "list" -d 'List all available modules'
complete -f -c hectogon -n '__fish_hectogon_no_subcommand' -a "help" -d 'Show help message'
complete -f -c hectogon -n '__fish_hectogon_no_subcommand' -a "version" -d 'Show version information'

# Modules
complete -f -c hectogon -n '__fish_hectogon_no_subcommand' -a "(__fish_hectogon_modules)"

# Module actions
complete -f -c hectogon -n '__fish_hectogon_using_module' -a "list" -d 'List available options'
complete -f -c hectogon -n '__fish_hectogon_using_module' -a "show" -d 'Show current option'
complete -f -c hectogon -n '__fish_hectogon_using_module' -a "set" -d 'Set an option'
complete -f -c hectogon -n '__fish_hectogon_using_module' -a "add" -d 'Add a new option'
complete -f -c hectogon -n '__fish_hectogon_using_module' -a "remove" -d 'Remove an option'
complete -f -c hectogon -n '__fish_hectogon_using_module' -a "help" -d 'Show module help'

# Options for actions
complete -f -c hectogon -n '__fish_hectogon_using_module_action set' -a "(__fish_hectogon_module_options)"
complete -f -c hectogon -n '__fish_hectogon_using_module_action remove' -a "(__fish_hectogon_module_options)"
complete -f -c hectogon -n '__fish_hectogon_using_module_action add' -a "(__fish_complete_path)"
EOF

    chmod 644 "$OUTPUT_DIR/fish.sh"
    success "Created: $OUTPUT_DIR/fish.sh"
}

# Main function
main() {
    echo -e "${BOLD}Hectogon Autocompletions Builder${RESET}"
    
    parse_args "$@"
    create_output_dir
    
    create_bash_completion
    create_zsh_completion
    create_fish_completion
    
    echo ""
    success "All autocompletion scripts created in $OUTPUT_DIR/"
    echo ""
}

# Run main function
main "$@"
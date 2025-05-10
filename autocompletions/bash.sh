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
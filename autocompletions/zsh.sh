#compdef hectogon
# ZSH completion for Hectogon

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
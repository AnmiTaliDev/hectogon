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
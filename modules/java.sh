# Создание симлинков для Java бинарников
create_java_symlinks() {
    local java_home="$1"
    
    # Создание симлинков для всех Java бинарников
    for binary in "${JAVA_BINARIES[@]}"; do
        local binary_path="$java_home/bin/$binary"
        local symlink_path="/usr/bin/$binary"
        
        if safe_check_executable "$binary_path"; then
            # Бэкап оригинального файла если он не симлинк
            if [ -f "$symlink_path" ] && [ ! -L "$symlink_path" ]; then
                local backup_name="$binary"
                if [ ! -f "$BACKUP_DIR/$backup_name.original" ]; then
                    cp "$symlink_path" "$BACKUP_DIR/$backup_name.original"
                    echo "Backed up original $binary"
                fi
            fi
            
            # Удаление существующего файла/симлинка
            if [ -e "$symlink_path" ]; then
                rm -f "$symlink_path"
            fi
            
            # Создание нового симлинка
            ln -sf "$binary_path" "$symlink_path"
            echo "Created symlink: $binary -> $binary_path"
        fi
    done
    
    return 0
}#!/bin/bash
#
# Hectogon module for managing Java Development Kit (JDK) alternatives
# Part of BaseUtils for OpenBase GNU/Linux
# Developer: AnmiTaliDev
#
# Copyright (C) 2025 AnmiTaliDev
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.#

# Module metadata
MODULE_NAME="java"
MODULE_DESCRIPTION="Manage Java Development Kit (JDK) alternatives"
MODULE_AUTHOR="AnmiTaliDev"
MODULE_VERSION="1.2.0"
PLUGIN_API_VERSION="1.0"

# Configuration
JAVA_BASE_DIRS=("/usr/lib/jvm" "/opt/java" "/opt/jdk" "/usr/java" "/Library/Java/JavaVirtualMachines")
CONFIG_DIR="/etc/hectogon/java"
CONFIG_FILE="$CONFIG_DIR/current"
BACKUP_DIR="$CONFIG_DIR/backup"
PROFILE_DIR="/etc/profile.d"
ENV_FILE="$PROFILE_DIR/10-java-environment.sh"
JAVA_BINARIES=("java" "javac" "javadoc" "jar" "javap" "jps" "jstack" "jmap" "jcmd")

# Цвета для вывода
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' PURPLE='' CYAN='' WHITE='' BOLD='' RESET=''
fi

# Логирование
log_action() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local user=$(whoami)
    
    echo "[$timestamp] [$level] [$user] $message" >> "/var/log/hectogon-java.log"
}

# Безопасная проверка существования файла
safe_check_file() {
    local file="$1"
    [[ -f "$file" && -r "$file" ]]
}

# Безопасная проверка исполняемого файла
safe_check_executable() {
    local file="$1"
    [[ -f "$file" && -x "$file" ]]
}

# Инициализация модуля
module_init() {
    if [[ ! -d "$CONFIG_DIR" ]]; then
        mkdir -p "$CONFIG_DIR" 2>/dev/null || {
            echo -e "${RED}✗${RESET} Cannot create config directory: $CONFIG_DIR" >&2
            return 1
        }
    fi
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR" 2>/dev/null || {
            echo -e "${YELLOW}!${RESET} Cannot create backup directory: $BACKUP_DIR" >&2
        }
    fi
    
    log_action "INFO" "Java module initialized"
}

# Обнаружение установленных JDK
find_java_installations() {
    local java_installations=()
    
    # Поиск в стандартных директориях
    for base_dir in "${JAVA_BASE_DIRS[@]}"; do
        if [[ -d "$base_dir" ]]; then
            while IFS= read -r -d '' java_dir; do
                if [[ -d "$java_dir/bin" ]] && safe_check_executable "$java_dir/bin/java"; then
                    java_installations+=("$java_dir")
                fi
    # Поиск установленных JDK
    for base_dir in "${JAVA_BASE_DIRS[@]}"; do
        if [[ -d "$base_dir" ]]; then
            while IFS= read -r -d '' java_dir; do
                if [[ -d "$java_dir/bin" ]] && safe_check_executable "$java_dir/bin/java"; then
                    java_installations+=("$java_dir")
                fi
            done < <(find "$base_dir" -maxdepth 3 -type d -name "java*" -o -name "jdk*" -o -name "openjdk*" 2>/dev/null | sort | tr '\n' '\0')
        fi
    done
    
    # Поиск через PATH
    if command -v java >/dev/null 2>&1; then
        local java_path
        java_path=$(command -v java)
        local java_home
        java_home=$(dirname "$(dirname "$java_path")")
        if [[ ! " ${java_installations[*]} " =~ " ${java_home} " ]] && [[ -d "$java_home" ]]; then
            java_installations+=("$java_home")
        fi
    fi
    
    # Удаление дубликатов и сортировка
    readarray -t java_installations < <(printf '%s\n' "${java_installations[@]}" | sort -u)
    
    printf '%s\n' "${java_installations[@]}"
}

# Получение информации о JDK
get_java_info() {
    local java_home="$1"
    local java_executable="$java_home/bin/java"
    
    if ! safe_check_executable "$java_executable"; then
        return 1
    fi
    
    local version_output
    version_output=$("$java_executable" -version 2>&1 | head -1)
    
    local vendor="Unknown"
    local version="Unknown"
    
    # Парсинг версии и вендора
    if [[ "$version_output" =~ openjdk ]]; then
        vendor="OpenJDK"
    elif [[ "$version_output" =~ \"Oracle ]]; then
        vendor="Oracle"
    elif [[ "$version_output" =~ Eclipse ]]; then
        vendor="Eclipse Temurin"
    elif [[ "$version_output" =~ Azul ]]; then
        vendor="Azul Zulu"
    elif [[ "$version_output" =~ Amazon ]]; then
        vendor="Amazon Corretto"
    fi
    
    if [[ "$version_output" =~ \"([0-9]+\.[0-9]+\.[0-9_]+) ]]; then
        version="${BASH_REMATCH[1]}"
    elif [[ "$version_output" =~ \"([0-9]+) ]]; then
        version="${BASH_REMATCH[1]}"
    fi
    
    echo "$vendor|$version"
}

# Получение текущего Java
get_current_java() {
    if safe_check_file "$CONFIG_FILE"; then
        cat "$CONFIG_FILE"
        return 0
    fi
    
    # Попытка определить из переменных окружения
    if [[ -n "$JAVA_HOME" ]] && safe_check_executable "$JAVA_HOME/bin/java"; then
        echo "$JAVA_HOME"
        return 0
    fi
    
    return 1
}

# Создание резервной копии
create_backup() {
    local backup_id
    backup_id=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/backup_$backup_id.conf"
    
    {
        echo "# Hectogon Java backup created on $(date)"
        echo "BACKUP_ID=$backup_id"
        echo "USER=$(whoami)"
        echo ""
        
        if safe_check_file "$CONFIG_FILE"; then
            echo "JAVA_HOME=$(cat "$CONFIG_FILE")"
        fi
        
        echo "ENVIRONMENT_VARS=("
        env | grep -E '^(JAVA_HOME|JRE_HOME|CLASSPATH|PATH)=' | sed 's/^/  /'
        echo ")"
        
        echo "SYMLINKS=("
        for binary in "${JAVA_BINARIES[@]}"; do
            local binary_path="/usr/bin/$binary"
            if [ -L "$binary_path" ]; then
                local target=$(readlink -f "$binary_path")
                echo "  $binary:$target"
            elif [ -f "$binary_path" ]; then
                echo "  $binary:$binary_path (original)"
            fi
        done
        echo ")"
    } > "$backup_file"
    
    echo -e "${GREEN}✓${RESET} Backup created: $backup_id"
    log_action "INFO" "Backup created: $backup_id"
    
    # Ротация старых бэкапов (оставляем только последние 10)
    local backup_count
    backup_count=$(find "$BACKUP_DIR" -name "backup_*.conf" | wc -l)
    if [[ "$backup_count" -gt 10 ]]; then
        find "$BACKUP_DIR" -name "backup_*.conf" -type f -printf '%T@ %p\n' | \
        sort -n | head -n $((backup_count - 10)) | \
        cut -d' ' -f2- | xargs rm -f
    fi
}

# Установка Java окружения
set_java_environment() {
    local java_home="$1"
    
    if [[ ! -d "$java_home" ]] || ! safe_check_executable "$java_home/bin/java"; then
        echo -e "${RED}✗${RESET} Invalid Java installation: $java_home"
        return 1
    fi
    
    echo -e "${BLUE}*${RESET} Setting Java environment..."
    
    # Создание резервной копии
    create_backup
    
    # Создание симлинков
    create_java_symlinks "$java_home"
    
    # Создание файла окружения
    cat > "$ENV_FILE" <<EOF
# Generated by Hectogon Java module
# Java environment configuration

export JAVA_HOME="$java_home"
export JRE_HOME="\$JAVA_HOME"
export CLASSPATH="\$JAVA_HOME/lib:\$CLASSPATH"

# Add Java binaries to PATH if not already present
if [[ ":\$PATH:" != *":\$JAVA_HOME/bin:"* ]]; then
    export PATH="\$JAVA_HOME/bin:\$PATH"
fi

# Java tool options
export JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF-8"

# Maven/Gradle compatibility
export M2_HOME="\$JAVA_HOME"
export GRADLE_HOME="\$JAVA_HOME"
EOF
    
    chmod 644 "$ENV_FILE"
    
    # Сохранение текущей конфигурации
    echo "$java_home" > "$CONFIG_FILE"
    
    echo -e "${GREEN}✓${RESET} Java environment configured"
    echo -e "${YELLOW}!${RESET} Restart your shell or run: source $ENV_FILE"
    
    log_action "INFO" "Java environment set to: $java_home"
    
    return 0
}

# Список доступных Java установок
module_list() {
    local installations
    mapfile -t installations < <(find_java_installations)
    
    if [[ ${#installations[@]} -eq 0 ]]; then
        echo -e "${YELLOW}!${RESET} No Java installations found"
        echo ""
        echo "Search directories:"
        for dir in "${JAVA_BASE_DIRS[@]}"; do
            if [[ -d "$dir" ]]; then
                echo -e "  ${GREEN}✓${RESET} $dir"
            else
                echo -e "  ${RED}✗${RESET} $dir (not found)"
            fi
        done
        echo ""
        echo "Install Java using your package manager or download from:"
        echo "  - https://openjdk.org/"
        echo "  - https://adoptium.net/"
        echo "  - https://www.oracle.com/java/"
        return 1
    fi
    
    local current_java=""
    if get_current_java >/dev/null 2>&1; then
        current_java=$(get_current_java)
    fi
    
    echo "Available Java installations:"
    echo ""
    
    for installation in "${installations[@]}"; do
        local info
        info=$(get_java_info "$installation")
        local vendor="${info%|*}"
        local version="${info#*|}"
        
        local marker=" "
        if [[ "$installation" == "$current_java" ]]; then
            marker="${GREEN}*${RESET}"
        fi
        
        printf "  %s %-50s ${CYAN}%s${RESET} ${WHITE}%s${RESET}\n" \
               "$marker" \
               "$(basename "$installation")" \
               "$vendor" \
               "$version"
        printf "    ${PURPLE}%s${RESET}\n" "$installation"
        echo ""
    done
    
    if [[ -n "$current_java" ]]; then
        echo -e "${GREEN}*${RESET} = Current selection"
    fi
    
    return 0
}

# Показать текущее Java окружение
module_show() {
    local current_java
    
    if ! get_current_java >/dev/null 2>&1; then
        echo -e "${YELLOW}!${RESET} No Java environment configured"
        echo "Use 'hectogon java set <installation>' to configure"
        return 1
    fi
    
    current_java=$(get_current_java)
    local info
    info=$(get_java_info "$current_java")
    local vendor="${info%|*}"
    local version="${info#*|}"
    
    echo -e "${BOLD}Current Java Configuration:${RESET}"
    echo ""
    echo -e "  Installation: ${CYAN}$(basename "$current_java")${RESET}"
    echo -e "  Vendor:       ${WHITE}$vendor${RESET}"
    echo -e "  Version:      ${WHITE}$version${RESET}"
    echo -e "  Path:         ${PURPLE}$current_java${RESET}"
    echo ""
    
    # Показать переменные окружения
    if safe_check_file "$ENV_FILE"; then
        echo -e "${BOLD}Environment Variables:${RESET}"
        while IFS= read -r line; do
            if [[ "$line" =~ ^export ]]; then
                echo "  $line"
            fi
        done < "$ENV_FILE"
        echo ""
    fi
    
    # Показать активные alternatives
    echo -e "${BOLD}Active Java Binaries:${RESET}"
    for binary in "${JAVA_BINARIES[@]}"; do
        if command -v "$binary" >/dev/null 2>&1; then
            local binary_path
            binary_path=$(command -v "$binary")
            local target
            target=$(readlink -f "$binary_path" 2>/dev/null || echo "$binary_path")
            echo -e "  ${GREEN}$binary${RESET} -> $target"
        else
            echo -e "  ${RED}$binary${RESET} (not found)"
        fi
    done
    
    return 0
}

# Установить Java окружение
module_set() {
    local java_selection="$1"
    
    if [[ -z "$java_selection" ]]; then
        echo -e "${RED}✗${RESET} No Java installation specified"
        echo "Available installations:"
        module_list
        return 1
    fi
    
    local installations
    mapfile -t installations < <(find_java_installations)
    
    local selected_java=""
    
    # Поиск по имени директории или полному пути
    for installation in "${installations[@]}"; do
        if [[ "$installation" == "$java_selection" ]] || \
           [[ "$(basename "$installation")" == "$java_selection" ]]; then
            selected_java="$installation"
            break
        fi
    done
    
    # Поиск по частичному совпадению
    if [[ -z "$selected_java" ]]; then
        local matches=()
        for installation in "${installations[@]}"; do
            if [[ "$(basename "$installation")" == *"$java_selection"* ]]; then
                matches+=("$installation")
            fi
        done
        
        if [[ ${#matches[@]} -eq 1 ]]; then
            selected_java="${matches[0]}"
        elif [[ ${#matches[@]} -gt 1 ]]; then
            echo -e "${RED}✗${RESET} Multiple matches found for '$java_selection':"
            for match in "${matches[@]}"; do
                echo "  $(basename "$match")"
            done
            return 1
        fi
    fi
    
    if [[ -z "$selected_java" ]]; then
        echo -e "${RED}✗${RESET} Java installation '$java_selection' not found"
        echo "Available installations:"
        module_list
        return 1
    fi
    
    echo -e "${BLUE}*${RESET} Setting Java to: $(basename "$selected_java")"
    set_java_environment "$selected_java"
    
    return $?
}

# Восстановление из резервной копии
module_restore() {
    local backup_id="$1"
    
    if [[ -z "$backup_id" ]]; then
        echo "Available backups:"
        local backups
        mapfile -t backups < <(find "$BACKUP_DIR" -name "backup_*.conf" -type f -printf '%f\n' | sort -r)
        
        if [[ ${#backups[@]} -eq 0 ]]; then
            echo -e "${YELLOW}!${RESET} No backups found"
            return 1
        fi
        
        for backup in "${backups[@]}"; do
            local backup_file="$BACKUP_DIR/$backup"
            local backup_date
            backup_date=$(grep "^# Hectogon Java backup created on" "$backup_file" 2>/dev/null | cut -d' ' -f6-)
            echo "  ${backup%%.conf} ($backup_date)"
        done
        
        echo ""
        echo "Usage: hectogon java restore <backup_id>"
        return 1
    fi
    
    local backup_file="$BACKUP_DIR/backup_${backup_id}.conf"
    
    if ! safe_check_file "$backup_file"; then
        echo -e "${RED}✗${RESET} Backup not found: $backup_id"
        return 1
    fi
    
    echo -e "${BLUE}*${RESET} Restoring from backup: $backup_id"
    
    # Здесь можно добавить логику восстановления
    echo -e "${YELLOW}!${RESET} Backup restore functionality is not yet implemented"
    echo "Backup file: $backup_file"
    
    return 0
}

# Добавление пользовательской Java установки
module_add() {
    local java_path="$1"
    
    if [[ -z "$java_path" ]]; then
        echo -e "${RED}✗${RESET} No Java installation path specified"
        echo "Usage: hectogon java add <path_to_java_installation>"
        return 1
    fi
    
    if [[ ! -d "$java_path" ]]; then
        echo -e "${RED}✗${RESET} Directory not found: $java_path"
        return 1
    fi
    
    if ! safe_check_executable "$java_path/bin/java"; then
        echo -e "${RED}✗${RESET} Not a valid Java installation: $java_path"
        echo "Expected: $java_path/bin/java"
        return 1
    fi
    
    local info
    info=$(get_java_info "$java_path")
    local vendor="${info%|*}"
    local version="${info#*|}"
    
    echo -e "${GREEN}✓${RESET} Valid Java installation found:"
    echo "  Path:    $java_path"
    echo "  Vendor:  $vendor"
    echo "  Version: $version"
    echo ""
    echo "This installation is now available for selection."
    
    log_action "INFO" "Custom Java installation added: $java_path"
    
    return 0
}

# Удаление Java окружения (сброс настроек)
module_remove() {
    echo -e "${YELLOW}!${RESET} This will reset Java environment to system defaults"
    read -p "Are you sure? [y/N]: " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        return 1
    fi
    
    echo -e "${BLUE}*${RESET} Removing Java environment configuration..."
    
    # Создание резервной копии перед удалением
    create_backup
    
    # Удаление файла окружения
    if [[ -f "$ENV_FILE" ]]; then
        rm -f "$ENV_FILE"
        echo -e "${GREEN}✓${RESET} Removed environment file: $ENV_FILE"
    fi
    
    # Удаление конфигурации
    if [[ -f "$CONFIG_FILE" ]]; then
        rm -f "$CONFIG_FILE"
        echo -e "${GREEN}✓${RESET} Removed configuration file"
    fi
    
    # Восстановление оригинальных бинарников
    for binary in "${JAVA_BINARIES[@]}"; do
        local binary_path="/usr/bin/$binary"
        local backup_file="$BACKUP_DIR/$binary.original"
        
        if [ -f "$backup_file" ]; then
            if [ -L "$binary_path" ]; then
                rm -f "$binary_path"
                cp "$backup_file" "$binary_path"
                chmod 755 "$binary_path"
                echo "Restored original $binary"
            fi
        else
            if [ -L "$binary_path" ]; then
                rm -f "$binary_path"
                echo "Removed symlink: $binary"
            fi
        fi
    done
    
    echo -e "${GREEN}✓${RESET} Java environment reset to system defaults"
    echo -e "${YELLOW}!${RESET} Restart your shell for changes to take effect"
    
    log_action "INFO" "Java environment reset to defaults"
    
    return 0
}

# Справка по модулю
module_help() {
    cat <<EOF
${BOLD}Hectogon Java Module${RESET}
Manages Java Development Kit (JDK) alternatives

${BOLD}USAGE:${RESET}
  hectogon java list              List available Java installations
  hectogon java show              Show current Java configuration
  hectogon java set <installation> Set active Java installation
  hectogon java add <path>        Add custom Java installation
  hectogon java remove            Reset Java environment to defaults
  hectogon java restore [backup]  Restore from backup
  hectogon java help              Show this help

${BOLD}EXAMPLES:${RESET}
  hectogon java list              # List all available JDK installations
  hectogon java set openjdk-17    # Set OpenJDK 17 as active
  hectogon java set /opt/jdk-21   # Set custom JDK installation
  hectogon java add ~/my-jdk      # Add custom Java installation
  hectogon java restore 20250106_143022  # Restore specific backup

${BOLD}FEATURES:${RESET}
  • Automatic detection of Java installations in standard directories
  • Support for Oracle JDK, OpenJDK, Eclipse Temurin, Azul Zulu, Amazon Corretto
  • Integration with system alternatives mechanism
  • Automatic PATH and environment variables configuration
  • Backup and restore functionality
  • Comprehensive logging and audit trail

${BOLD}SUPPORTED DIRECTORIES:${RESET}
EOF

    for dir in "${JAVA_BASE_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "  ${GREEN}✓${RESET} $dir"
        else
            echo "  ${RED}✗${RESET} $dir"
        fi
    done

    cat <<EOF

${BOLD}CONFIGURATION FILES:${RESET}
  Environment: $ENV_FILE
  Current:     $CONFIG_FILE
  Backups:     $BACKUP_DIR/
  Logs:        /var/log/hectogon-java.log

${BOLD}NOTE:${RESET}
Changes to Java environment require restarting your shell session
or running: source $ENV_FILE

Module version: $MODULE_VERSION
Author: $MODULE_AUTHOR
EOF
}

# Инициализация модуля при загрузке
module_init
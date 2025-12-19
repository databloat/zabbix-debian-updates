#!/bin/bash
#
# Zabbix Remote Update Script for Debian Systems v2 - by databloat
# Github: https://github.com/databloat
#
# Performs system updates and logs all actions

set -euo pipefail

# Conf Path
readonly LOG_DIR="/var/log/zabbix"
readonly LOG_FILE="/var/log/zabbix/zbx_remote_update.log"
readonly STATUS_FILE="/var/log/zabbix/zbx_update_status"

# Check Log dir
if [[ ! -d "$LOG_DIR" ]]; then
    mkdir -p "$LOG_DIR"
    chown zabbix:zabbix "$LOG_DIR"
fi

################## Functions ###########################

log() {
    local level="${2:-INFO}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [${level}] - $(whoami) - $1" >> "$LOG_FILE"
}

error_exit() {
    log "ERROR: $1" "ERROR"
    echo "1" > "$STATUS_FILE"
    exit 1
}

write_success() {
    echo "0" > "$STATUS_FILE"
}

main() {
    log "=== Script started ===" "INFO"
    
    export DEBIAN_FRONTEND=noninteractive
    export DEBIAN_PRIORITY=critical
    
    # Update package lists
    log "Updating package lists..."
    if sudo apt-get update >> "$LOG_FILE" 2>&1; then
        log "Package lists updated successfully"
    else
        error_exit "apt-get update failed"
    fi
    
    # Perform full upgrade
    log "Performing full system upgrade..."
    if sudo apt-get full-upgrade -y --simulate \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        >> "$LOG_FILE" 2>&1; then
        log "System upgrade completed successfully"
    else
        error_exit "apt-get full-upgrade failed"
    fi
    
    # Remove unused packages
    log "Removing unused packages..."
    if sudo apt-get autoremove --purge -y --simulate >> "$LOG_FILE" 2>&1; then
        log "Unused packages removed successfully"
    else
        log "apt-get autoremove failed (non-critical)" "WARN"
    fi
    
    # Clean package cache
    log "Cleaning package cache..."
    if sudo apt-get autoclean -y --simulate >> "$LOG_FILE" 2>&1; then
        log "Package cache cleaned successfully"
    else
        log "apt-get autoclean failed (non-critical)" "WARN"
    fi
    
    log "=== Script completed successfully ===" "INFO"
    write_success
    return 0
}

# main function in background mode
main &

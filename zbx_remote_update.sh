#!/bin/bash

# Log file location
LOG_FILE="/var/log/zabbix/zbx_remote_update.log"

# Ensure the log directory exists
mkdir -p /var/log/zabbix
chown zabbix:zabbix /var/log/zabbix

# Log function to write to the log file
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $(whoami) - $1" >> "$LOG_FILE"
}

# Start the script in the background
{
    # Log the start of the script execution
    log "Script started"

    # Update package lists
    log "Running: sudo apt update"
    sudo apt update >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        log "ERROR: 'apt update' failed"
        exit 1
    fi

    # Perform a full upgrade
    log "Running: sudo apt full-upgrade -y"
    sudo apt full-upgrade -y >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        log "ERROR: 'apt full-upgrade' failed"
        exit 1
    fi

    # Clean up unused packages and configuration files
    log "Running: sudo apt autoremove --purge -y"
    sudo apt autoremove --purge -y >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        log "ERROR: 'apt autoremove --purge' failed"
        exit 1
    fi

    # Clean up cached package files
    log "Running: sudo apt autoclean -y"
    sudo apt autoclean -y >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        log "ERROR: 'apt autoclean' failed"
        exit 1
    fi

    # Log the successful completion of the script
    log "Script completed successfully"
} &

#!/bin/bash
#
# Zabbix Remote Update Script for Debian Systems v3 - by databloat
# Github: https://github.com/databloat
#

set -euo pipefail

readonly LOG_DIR="/var/log/zabbix"
readonly LOG_FILE="$LOG_DIR/zbx_remote_update.log"
readonly STATUS_FILE="$LOG_DIR/zbx_update_status"
readonly LOCK_FILE="/run/lock/zbx_debian_update.lock"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [${2:-INFO}] - $(whoami) - $1" >> "$LOG_FILE"
}

# CHECK

simulate_upgrade() {
    local attempt output
    for attempt in 1 2 3; do
        if output=$(apt-get -s full-upgrade 2>&1); then
            printf '%s\n' "$output"
            return 0
        fi
        grep -qi 'could not get lock\|unable to fetch' <<<"$output" || break
        sleep 2
    done
    return 1
}

cmd_check() {
    local sim_output packages_total packages_security packages_normal
    local auto_update_enabled=0 reboot_required=0

    if ! sim_output=$(simulate_upgrade); then
        echo "apt-get -s full-upgrade failed (see log)" >&2
        exit 1
    fi

    packages_total=$(grep -c '^Inst ' <<<"$sim_output" || true)
    packages_security=$(grep '^Inst ' <<<"$sim_output" | grep -c -- '-security' || true)
    packages_normal=$(( packages_total - packages_security ))

    if systemctl is-enabled --quiet unattended-upgrades.service 2>/dev/null \
       || systemctl is-enabled --quiet apt-daily-upgrade.timer 2>/dev/null; then
        if apt-config dump 2>/dev/null | grep -q 'APT::Periodic::Unattended-Upgrade "1"'; then
            auto_update_enabled=1
        fi
    fi

    if [[ -f /var/run/reboot-required ]]; then
        reboot_required=1
    else
        local latest running
        latest=$(dpkg-query -W -f='${Package}\n' 'linux-image-[0-9]*' 2>/dev/null \
            | sed -E 's/^linux-image-//' | sort -V | tail -n1) || true
        running=$(uname -r)
        [[ -n "$latest" && "$latest" != "$running" ]] && reboot_required=1
    fi

    printf '{"packages_total":%d,"packages_security":%d,"packages_normal":%d,"auto_update_enabled":%d,"reboot_required":%d}\n' \
        "$packages_total" "$packages_security" "$packages_normal" \
        "$auto_update_enabled" "$reboot_required"
}

# APPLY :-)

do_apply() {
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
        log "Update already in progress, skipping duplicate run" "WARN"
        exit 0
    fi

    log "=== Update started ===" "INFO"
    export DEBIAN_FRONTEND=noninteractive
    export DEBIAN_PRIORITY=critical

    if apt-get update >>"$LOG_FILE" 2>&1 \
        && apt-get full-upgrade -y \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" >>"$LOG_FILE" 2>&1
    then
        apt-get autoremove --purge -y >>"$LOG_FILE" 2>&1 || log "autoremove failed (non-critical)" "WARN"
        apt-get autoclean -y >>"$LOG_FILE" 2>&1 || log "autoclean failed (non-critical)" "WARN"
        log "=== Update completed successfully ===" "INFO"
        echo "0" > "$STATUS_FILE"
    else
        log "apt-get update/full-upgrade failed" "ERROR"
        echo "1" > "$STATUS_FILE"
    fi
}

cmd_apply() {
    [[ "$(id -u)" -eq 0 ]] || { echo "apply must be run as root (via sudo)" >&2; exit 1; }
    [[ -d "$LOG_DIR" ]] || { mkdir -p "$LOG_DIR"; chown zabbix:zabbix "$LOG_DIR"; }

    do_apply &
    disown
    exit 0
}

# MAIN

case "${1:-check}" in
    check) cmd_check ;;
    apply) cmd_apply ;;
    *) echo "usage: $0 [check|apply]" >&2; exit 2 ;;
esac

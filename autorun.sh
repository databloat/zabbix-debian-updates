#!/bin/bash
# autorun.sh for Zabbix Remote Update Script for Debian Systems v2 - by databloat
# Github: https://github.com/databloat
set -e

# -----------------------------------------------------------------------------
#  Zabbix Template "Debian Package Updates" Auto-Installer v1.3
# -----------------------------------------------------------------------------

# Logging functions
print_success() { echo -e "\033[1;32m$1\033[0m"; }
print_error()   { echo -e "\033[1;31m[ERROR]\033[0m \033[0;31m$1\033[0m"; }
print_info()    { echo -e "\033[1;37m[INFO]\033[0m \033[0;37m$1\033[0m"; }

# Default values
AGENT_CONF="/etc/zabbix/zabbix_agentd.conf"
AGENT_CONF_DIR="/etc/zabbix/zabbix_agentd.conf.d"
AGENT_SERVICE="zabbix-agent"

echo "Zabbix Template \"Debian Package Updates\" Auto-Installer v1.3"

# Detect agent2
if dpkg -l | grep -qw "zabbix-agent2"; then
  AGENT_CONF="/etc/zabbix/zabbix_agent2.conf"
  AGENT_CONF_DIR="/etc/zabbix/zabbix_agent2.d"
  AGENT_SERVICE="zabbix-agent2"
fi

# Check if agent is installed
if ! dpkg -l | grep -qw "$AGENT_SERVICE"; then
  print_error "$AGENT_SERVICE is not installed. Please install it first."
  exit 1
fi
print_info "$AGENT_SERVICE is installed."

# Warn if Docker is detected
if command -v docker &>/dev/null; then
  print_info "Docker detected! Make sure to stop database containers before triggering remote updates from zabbix server."
fi

# Install update script
mkdir -p /etc/zabbix/scripts
if [ ! -f ./zbx_remote_update.sh ]; then
  print_error "The file 'zbx_remote_update.sh' is missing in the current directory!"
  exit 1
fi
cp ./zbx_remote_update.sh /etc/zabbix/scripts/
chmod +x /etc/zabbix/scripts/zbx_remote_update.sh
print_success "Script copied to /etc/zabbix/scripts/"

# add visudo 
if [ ! -f ./visudo ]; then
  print_error "The file 'visudo' is missing in the current directory!"
  exit 1
fi

SUDOERS_ENTRY=$(<./visudo)
if sudo grep -Fxq "$SUDOERS_ENTRY" /etc/sudoers; then
  print_info "Sudoers entry for 'zabbix' user already exists."
else
  echo "$SUDOERS_ENTRY" | sudo EDITOR='tee -a' visudo >/dev/null
  print_success "Sudoers entry for 'zabbix' user has been added."
fi

# cp conf
mkdir -p "$AGENT_CONF_DIR"
CONFIG_FILE="./zabbix_agent2.d/90-debian-update.conf"
if [ ! -f "$CONFIG_FILE" ]; then
  print_error "The file '90-debian-update.conf' is missing!"
  exit 1
fi
cp "$CONFIG_FILE" "$AGENT_CONF_DIR/"
print_success "Configuration file copied to $AGENT_CONF_DIR/"

# Check AllowKey=system.run[*] in zabbix conf
if grep -q '^AllowKey=system.run' "$AGENT_CONF"; then
  print_info "'AllowKey=system.run[*]' already exists in $AGENT_CONF"
else
  echo "AllowKey=system.run[*]" | sudo tee -a "$AGENT_CONF" >/dev/null
  print_success "'AllowKey=system.run[*]' added to $AGENT_CONF"
fi

# restart services
if systemctl restart "$AGENT_SERVICE"; then
  print_success "$AGENT_SERVICE restarted successfully."
else
  print_error "Failed to restart $AGENT_SERVICE!"
  exit 1
fi

# done
print_success "Zabbix Debian update template installed successfully."

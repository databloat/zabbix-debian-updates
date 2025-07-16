#!/bin/bash

set -e

# -----------------------------------------------------------------------------
#  Zabbix Template "Debian Package Updates" Installer v1.2
# -----------------------------------------------------------------------------

# Logging functions
print_success() {
  echo -e "\033[1;32m$1\033[0m"
}

print_error() {
  echo -e "\033[1;31m[ERROR]\033[0m \033[0;31m$1\033[0m"
}

print_info() {
  echo -e "\033[1;37m[INFO]\033[0m \033[0;37m$1\033[0m"
}

print_quest() {
  local question="$1"
  local __resultvar="$2"

  echo -ne "\033[1;37m$question\033[0m "
  read -r answer

  if [[ "$__resultvar" ]]; then
    eval $__resultvar="'$answer'"
  else
    echo "$answer"
  fi
}

# Default values
AGENT_CONF="/etc/zabbix/zabbix_agentd.conf"
AGENT_CONF_DIR="/etc/zabbix/zabbix_agentd.conf.d"
AGENT_SERVICE="zabbix-agent"

echo "Zabbix Template \"Linux Package Updates\" Installer v1.2 (CLI Edition)"

# Ask for Agent version
print_quest "Do you want to use Zabbix Agent 2? (y/N): " use_agent2
if [[ "$use_agent2" =~ ^[Yy]$ ]]; then
  AGENT_CONF="/etc/zabbix/zabbix_agent2.conf"
  AGENT_CONF_DIR="/etc/zabbix/zabbix_agent2.d"
  AGENT_SERVICE="zabbix-agent2"
fi

print_quest "Do you want to start the template configuration now? (y/N): " ask_start
if [[ "$ask_start" =~ ^[Yy]$ ]]; then
  print_info "Starting the Zabbix template configuration..."
else
  print_info "Template configuration aborted by user."
  exit 0
fi

# Check if agent is installed
if ! dpkg -l | grep -qw "$AGENT_SERVICE"; then
  print_error "$AGENT_SERVICE is not installed. Please install it first."
  exit 1
fi
print_info "$AGENT_SERVICE is installed."

# Warn if Docker is detected
if command -v docker &>/dev/null; then
  print_info "Docker detected! Make sure to stop database containers before triggering updates."
fi

# Step 1: Install update script
mkdir -p /etc/zabbix/scripts

if [ ! -f ./zbx_remote_update.sh ]; then
  print_error "The file 'zbx_remote_update.sh' is missing in the current directory!"
  exit 1
fi

cp ./zbx_remote_update.sh /etc/zabbix/scripts/
chmod +x /etc/zabbix/scripts/zbx_remote_update.sh
print_success "Script copied to /etc/zabbix/scripts/"

# Step 2: Add sudoers rule
SUDOERS_ENTRY="zabbix ALL=(ALL) NOPASSWD: /usr/bin/apt update, /usr/bin/apt full-upgrade -y, /usr/bin/apt autoremove --purge -y, /usr/bin/apt autoclean -y, /sbin/reboot"

if sudo grep -Fxq "$SUDOERS_ENTRY" /etc/sudoers; then
  print_info "Sudoers entry for 'zabbix' user already exists."
else
  echo "$SUDOERS_ENTRY" | sudo EDITOR='tee -a' visudo >/dev/null
  print_success "Sudoers entry for 'zabbix' user has been added."
fi


# Step 3: Copy config
mkdir -p "$AGENT_CONF_DIR"

if [ ! -f ./zabbix_agent2.d/90-debian-update.conf ]; then
  print_error "The file 'zabbix_agent2.d/90-debian-update.conf' is missing!"
  exit 1
fi

cp ./zabbix_agent2.d/90-debian-update.conf "$AGENT_CONF_DIR/"
print_success "Configuration file copied to $AGENT_CONF_DIR/"

# Step 4: Ensure AllowKey=system.run[*] is present
if grep -q '^AllowKey=system.run' "$AGENT_CONF"; then
  print_info "'AllowKey=system.run[*]' already exists in $AGENT_CONF"
else
  echo "AllowKey=system.run[*]" | sudo tee -a "$AGENT_CONF" >/dev/null
  print_success "'AllowKey=system.run[*]' added to $AGENT_CONF"
fi

# Step 5: Restart service
print_quest "Do you want to restart the $AGENT_SERVICE now? (y/N): " restart_agent
if [[ "$restart_agent" =~ ^[Yy]$ ]]; then
  if systemctl restart "$AGENT_SERVICE"; then
    print_success "$AGENT_SERVICE restarted successfully."
  else
    print_error "Failed to restart $AGENT_SERVICE!"
    exit 1
  fi
fi

# Done
print_success "Zabbix debian update template installed successfully."

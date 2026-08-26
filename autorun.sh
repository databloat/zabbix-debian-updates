#!/bin/bash
# autorun.sh for Zabbix Remote Update Script for Debian Systems v3 - by databloat
# Github: https://github.com/databloat
#
# Usage: git clone + ./autorun.sh, or curl -fsSL <raw-url>/autorun.sh | sudo bash
set -e

REPO_RAW_BASE="https://raw.githubusercontent.com/databloat/zabbix-debian-updates/main"

print_success() { echo -e "\033[1;32m$1\033[0m"; }
print_error()   { echo -e "\033[1;31m[ERROR]\033[0m \033[0;31m$1\033[0m"; }
print_info()    { echo -e "\033[1;37m[INFO]\033[0m \033[0;37m$1\033[0m"; }

WORKDIR=""
cleanup() { [[ -n "$WORKDIR" ]] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# Use local, else download from REPO.
resolve_file() {
  local rel="$1"
  if [[ -f "./$rel" ]]; then
    echo "./$rel"
    return
  fi
  if [[ -z "$WORKDIR" ]]; then
    WORKDIR=$(mktemp -d)
  fi
  local dest="$WORKDIR/$rel"
  mkdir -p "$(dirname "$dest")"
  if ! curl -fsSL "$REPO_RAW_BASE/$rel" -o "$dest"; then
    print_error "Could not download '$rel' from $REPO_RAW_BASE"
    exit 1
  fi
  echo "$dest"
}

AGENT_CONF="/etc/zabbix/zabbix_agentd.conf"
AGENT_CONF_DIR="/etc/zabbix/zabbix_agentd.conf.d"
AGENT_SERVICE="zabbix-agent"

echo "Zabbix Template \"Debian Package Updates\" Auto-Installer v3"

if dpkg -l | grep -qw "zabbix-agent2"; then
  AGENT_CONF="/etc/zabbix/zabbix_agent2.conf"
  AGENT_CONF_DIR="/etc/zabbix/zabbix_agent2.d"
  AGENT_SERVICE="zabbix-agent2"
fi

if ! dpkg -l | grep -qw "$AGENT_SERVICE"; then
  print_error "$AGENT_SERVICE is not installed. Please install it first."
  exit 1
fi
print_info "$AGENT_SERVICE is installed."

if command -v docker &>/dev/null; then
  print_info "Docker detected! Make sure to stop database containers before triggering remote updates from zabbix server."
fi

# Install script 
mkdir -p /etc/zabbix/scripts
SCRIPT_SRC=$(resolve_file "zbx_remote_update.sh")
cp "$SCRIPT_SRC" /etc/zabbix/scripts/zbx_remote_update.sh
chown root:root /etc/zabbix/scripts/zbx_remote_update.sh
chmod 755 /etc/zabbix/scripts/zbx_remote_update.sh
print_success "Script installed to /etc/zabbix/scripts/ (root:root, 755)"

# Remove pre-v2.0 sudoers rule
if sudo grep -qE '^zabbix ALL=\(ALL\) NOPASSWD: /usr/bin/apt-get' /etc/sudoers; then
  sudo sed -i '/^zabbix ALL=(ALL) NOPASSWD: \/usr\/bin\/apt-get/d' /etc/sudoers
  print_info "Removed legacy unrestricted apt-get sudoers entry."
fi

VISUDO_SRC=$(resolve_file "visudo")
SUDOERS_ENTRY=$(<"$VISUDO_SRC")
if sudo grep -Fxq "$SUDOERS_ENTRY" /etc/sudoers; then
  print_info "Sudoers entry for 'zabbix' user already exists."
else
  echo "$SUDOERS_ENTRY" | sudo EDITOR='tee -a' visudo >/dev/null
  print_success "Sudoers entry for 'zabbix' user has been added."
fi

mkdir -p "$AGENT_CONF_DIR"
CONFIG_SRC=$(resolve_file "zabbix_agent2.d/90-debian-update.conf")
cp "$CONFIG_SRC" "$AGENT_CONF_DIR/90-debian-update.conf"
print_success "Configuration file copied to $AGENT_CONF_DIR/"

#  Check for Include=
if ! grep -qE "^[[:space:]]*Include=${AGENT_CONF_DIR}" "$AGENT_CONF" 2>/dev/null; then
  echo "Include=${AGENT_CONF_DIR}/*.conf" | sudo tee -a "$AGENT_CONF" >/dev/null
  print_success "Added 'Include=${AGENT_CONF_DIR}/*.conf' to $AGENT_CONF"
else
  print_info "Include directive for $AGENT_CONF_DIR already active in $AGENT_CONF."
fi

# Legacy wildcard AllowKey may be needed not by this script
if grep -q '^AllowKey=system\.run\[\*\]$' "$AGENT_CONF" 2>/dev/null; then
  print_info "Note: $AGENT_CONF already has 'AllowKey=system.run[*]'. Left untouched - remove by hand if it was only ever added for this template."
fi

if systemctl restart "$AGENT_SERVICE"; then
  print_success "$AGENT_SERVICE restarted successfully."
else
  print_error "Failed to restart $AGENT_SERVICE!"
  exit 1
fi

print_success "Zabbix Debian update template installed successfully."

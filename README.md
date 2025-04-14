> ⚠️ **This project is still under development.**
> While mostly stable, some features may not yet be complete or fully tested.

# Zabbix APT Update Manager

Monitor and manage APT updates on **Debian/Ubuntu** systems using Zabbix.  
This project provides a script and configuration for checking available package and security updates and triggering alerts in Zabbix.

---

## 📦 Features

- 🔍 **Check for available package updates**
- 🔐 **Detect available security updates**
- 🚨 **Trigger Zabbix problems if updates are found**
- 📄 **Log all actions to `/var/log/zabbix/zbx_remote_update.log`**
- 🧪 **Runs updates and cleanup in background (preparation for auto-update)**
- 📦 **Performs `apt update`, `full-upgrade`, `autoremove`, and `autoclean`**
- 🔜 **Planned**:
  - Automatic package updates via Zabbix
  - Improved and more verbose logfile structure

---

## ⚙️ Installation

### 1. Script Setup

Create the script directory:

```bash
sudo mkdir -p /etc/zabbix/scripts
```
Copy the update script to this location:
```bash
sudo cp zbx_remote_update.sh /etc/zabbix/scripts/
sudo chmod +x /etc/zabbix/scripts/zbx_remote_update.sh
```

### 2. Sudo Rights for Zabbix

Run:
```bash
sudo visudo
```
Insert the content from the provided visudo configuration file (included in this repository) to allow the zabbix user to run APT commands without a password.

### 3. Zabbix Agent Configuration
Copy the agent configuration:
```bash
sudo cp 90-debian-update.conf /etc/zabbix/zabbix_agent2.d/
```

Add system.run[*] to zabbix_agent2.conf

Restart the Zabbix Agent:
```bash
sudo systemctl restart zabbix-agent2
```

### 4. Import Zabbix Template

Import the provided Zabbix template XML file into your Zabbix frontend. Assign the template to the desired hosts.

### 5. Create Script in Zabbix Frontend

In the Zabbix frontend:

- For version **7.0 and above**: go to **Alerts → Scripts → Create script**
- For versions **below 7.0**: go to **Administration → Scripts → Create Script**

Configure the script with the following settings:
- Name: Run APT Update Script
- Type: Script
- Execute on: Agent
- User permissions: Select the appropriate Zabbix user groups

Commands:
```bash
/etc/zabbix/scripts/zbx_remote_update.sh
```
## 📂 Log Output

All output is logged to:
```bash
/var/log/zabbix/zbx_remote_update.log
```

Each action is timestamped and includes the user running the command. Example log entries:
```bash
2025-04-11 18:42:12 - root - Script started
2025-04-11 18:42:13 - root - Running: sudo apt update
...
```

The logfile is owned by zabbix:zabbix


## 📌 Notes
- Ensure the zabbix user has passwordless sudo access only to necessary commands.
- Tested on Debian 12 and Ubuntu 22.04 with Zabbix Server Zabbix 7.2.x / 6.0 LTS
- Uses apt full-upgrade, so it can also install kernel and system updates.


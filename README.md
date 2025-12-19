# Zabbix Remote Update Script for Debian Systems via APT

Monitor and manage APT updates on **Debian/Ubuntu** systems using Zabbix.  
This project provides a script and configuration to check for package and security updates, trigger Zabbix alerts, and install updates 
manually through Zabbix script execution.

## 💬 Feedback & Issues

Feedback, suggestions, and issue reports are always welcome — feel free to open an issue or contact me directly.

---

## 📦 Features

- 🔍 **Check available package and security updates**  
- 🔄 **Manually trigger updates that run automatically in the background**  
- 🔔 **Check if a system reboot is required after updates** 
- ⚙️ **Perform full system update: `apt update`, `full-upgrade`, `autoremove`, `autoclean`**  
- 📄 **Log all actions and update status to `/var/log/zabbix/zbx_remote_update.log` and `/var/log/zabbix/zbx_update_status`**  
- ⚡ **One-touch configuration for easy deployment**  
- 🔜 **Planned enhancements:** improved logging structure and fully automated updates via Zabbix

---
> ⚠️ **Warning for target systems running Docker**
>
> The script triggers system updates via manual Zabbix actions.  
> If the target system is running Docker (e.g., PostgresSQL or other databases in Docker),  
> be aware that system updates might **restart or stop Docker services**.  
> This can cause **data loss or corruption**, especially if containers are not gracefully stopped  
> or if critical services run within Docker.  
>
> **Review and adjust the update behavior carefully** before applying it to systems with Docker.

## 🧩 Compatibility & Requirements

This script and template were tested with the following environments:

**Client systems (monitored hosts):**
- Debian 12
- Ubuntu 22.04 LTS
- Ubuntu 23.04 LTS
- Ubuntu 24.04 LTS

**Zabbix server versions:**
- 6.0 LTS
- 7.0 LTS
- 7.2 
- 7.4 (latest tested version)

## ⚙️ Setup Script with autorun.sh (Easy)

### 1. Clone the Repository
Run the following command on the target system:

```bash
git clone https://github.com/databloat/zabbix-debian-updates.git
```

### 2. Prepare the Installer Script
Navigate to the project directory and make the script executable:

```bash
cd zabbix-debian-updates
chmod +x autorun.sh
```

### 3. Run the Installer
Execute the script and follow the on-screen instructions:

```bash
./autorun.sh
```

Example output during execution:

```bash
root@zabbixtest:~/dev/zbx-debian-update# ./autorun.sh 
Zabbix Template "Debian Package Updates" Auto-Installer v1.3
[INFO] zabbix-agent2 is installed.
Script copied to /etc/zabbix/scripts/
Sudoers entry for 'zabbix' user has been added.
Configuration file copied to /etc/zabbix/zabbix_agent2.d/
'AllowKey=system.run[*]' added to /etc/zabbix/zabbix_agent2.conf
zabbix-agent2 restarted successfully.
Zabbix Debian update template installed successfully.

```

### 4. Import Zabbix Template (Server)

Import the provided Zabbix template XML file into your Zabbix frontend. Assign the template to the desired hosts.

### 5. Create Script in Zabbix Frontend

In the Zabbix frontend:

- For version **7.0 and above**: go to **Alerts → Scripts → Create script**
- For versions **below 7.0**: go to **Administration → Scripts → Create Script**

Configure the script with the following settings:
- Name: Debian Full Update
- Scope: Manual host action
- Type: Script
- Execute on: Zabbix agent

Commands:
```bash
nohup /etc/zabbix/scripts/zbx_remote_update.sh > /dev/null 2>&1 &
```

## 📦 Zabbix Items Overview

| Name                      | Key                                         | Triggers | Description                                           |
|---------------------------|---------------------------------------------|----------|-------------------------------------------------------|
| Available Package Updates | `debian.package.updates`                   | 1        | Shows the number of available system package updates. |
| Available Security Updates| `debian.security.updates`                  | 1        | Shows the number of available **security** updates.   |
| Last Full-Update State    | `vfs.file.contents[/var/log/zabbix/zbx_update_status]` | 1     | Shows the last execution state of the Debian update script (0 = success, 1 = failure) |
| Reboot Required           | `vfs.file.exists[/var/run/reboot-required]`| 1        | 🔄 Checks if a reboot is required after updates.       |

## 🚨 Zabbix Trigger Overview

| Severity | Name                                                  | Expression                                                                 |
|----------|-------------------------------------------------------|----------------------------------------------------------------------------|
| Average  | Reboot required to finish updates on `{HOST.NAME}`    | `last(/Linux Package Updates/vfs.file.exists[/var/run/reboot-required])>0`|
| Disaster  | Remote update failed on `{HOST.NAME}` (Check the log at /var/log/zabbix/zbx_remote_update.log)    | `last(/Debian Package Updates/vfs.file.contents[/var/log/zabbix/zbx_update_status])=1`   |
| Warning  | There are `{ITEM.LASTVALUE}` package updates available on `{HOST.NAME}` | `last(/Linux Package Updates/debian.package.updates)>0`|
| Warning  | There are `{ITEM.LASTVALUE}` security updates available on `{HOST.NAME}` | `last(/Linux Package Updates/debian.security.updates)>0`|


## 📂 Log Output

Last remote Update state:

```bash
/var/log/zabbix/zbx_update_status
```

All output is logged to:
```bash
/var/log/zabbix/zbx_remote_update.log
```

Each action is timestamped and includes the user running the command. Example log entries:
```bash
2025-12-19 21:52:04 - [INFO] - zabbix - === Script started ===
2025-12-19 21:52:04 - [INFO] - zabbix - Updating package lists...

...
```

The logfile is owned by zabbix:zabbix


## 📌 Notes
- Ensure the zabbix user has passwordless sudo access only to necessary commands.
- Uses apt full-upgrade, so it can also install kernel and system updates.

## Examples
<img width="1067" height="61" alt="image" src="https://github.com/user-attachments/assets/bbcb02b5-897d-493f-868a-67acb47ad64f" />


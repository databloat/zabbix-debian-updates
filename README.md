# Zabbix Remote Update for Debian/Ubuntu

Monitors APT updates on Debian/Ubuntu hosts via Zabbix and lets you trigger `apt full-upgrade` remotely through a Zabbix script.

Tracks:
- available package and security updates
- `unattended-upgrades` status
- whether a reboot is required

## 💬 Feedback & Issues

Feedback, suggestions, and issue reports are always welcome. \
Open an issue or ping me directly.

---

## 📦 Features

- Check available package and security updates
- Check whether unattended-upgrades is active
- Trigger updates manually via Zabbix (runs in background)
- Check if reboot is required
- Full update via: `apt update && full-upgrade && autoremove && autoclean`
- Logs to `/var/log/zabbix/zbx_remote_update.log` and `/var/log/zabbix/zbx_update_status`
- Locked-down execution: Zabbix can trigger exactly one privileged action (`apt full-upgrade`)

---
> **Docker warning:** `apt full-upgrade` can restart or stop Docker services (e.g. databases running in containers), risking data loss if they aren't shut down gracefully. Review update behavior before using this on Docker hosts.

## Compatibility

Tested on:

**Clients:** Debian 12, Ubuntu 22.04/23.04/24.04

**Zabbix server:** 6.0, 7.0, 7.2, 7.4 (latest tested)

## Files (v3)

3 files on monitored host:

| File | Deployed to | Purpose |
|---|---|---|
| `zbx_remote_update.sh` | `/etc/zabbix/scripts/` | Two modes: `check` (unprivileged, called via UserParameter) and `apply` (privileged, sudo only) |
| `visudo` | appended to `/etc/sudoers` | Grants `zabbix` user only one privileged command |
| `zabbix_agent2.d/90-debian-update.conf` | `/etc/zabbix/zabbix_agent2.d/` (agent2) or `/etc/zabbix/zabbix_agentd.conf.d/` (classic) | UserParameter + AllowKey/DenyKey restricting `system.run` |

`autorun.sh` dhandles the full setup for installation.

Also import once into the Zabbix frontend: `7.4/zbx_template_debian_package_updates.yaml`

## Security model

`zabbix` can trigger only one privileged command: `sudo /etc/zabbix/scripts/zbx_remote_update.sh apply`, no `system.run`, no `apt-get` option injection, script is `root:root` and not writable by `zabbix`.

Upgrading from v2: re-run `autorun.sh`, it removes the old unrestricted sudoers entry automatically.

## ⚙️ Setup Script with autorun.sh

### Option A: one-liner

```bash
curl -fsSL https://raw.githubusercontent.com/databloat/zabbix-debian-updates/main/autorun.sh | sudo bash
```

### Option B: git clone

```bash
git clone https://github.com/databloat/zabbix-debian-updates.git
cd zabbix-debian-updates
sudo ./autorun.sh
```

Needs root, writes to `/etc/zabbix/`, `/etc/sudoers`, and restarts the agent.

### Import template (server)

Import `7.4/zbx_template_debian_package_updates.yaml` in **Data collection → Templates → Import**, then assign to hosts.

### Create script (server)

**Alerts → Scripts → Create script** (7.0+) or **Administration → Scripts** (below 7.0):

- Name: Debian Full Update
- Scope: Manual host action
- Type: Script
- Execute on: Zabbix agent
- Command: `sudo /etc/zabbix/scripts/zbx_remote_update.sh apply`

Runs in background.

## Zabbix Items

| Name | Key | Triggers | Description |
|---|---|---|---|
| Debian Update Status (raw) | `debian.update.status` | – | Master item: raw JSON from the collector, not for direct alerting |
| Available Package Updates (total) (default:disabled) | `debian.package.updates` | 1 | Total available package updates |
| Available Security Updates | `debian.security.updates` | 1 | Available security updates |
| Available Normal Updates | `debian.normal.updates` | 1 | Available non-security updates |
| Automatic Security Updates Enabled | `debian.autoupdate.enabled` | 1 | Whether `unattended-upgrades` is active |
| Last Full-Update State | `vfs.file.contents[/var/log/zabbix/zbx_update_status]` | 1 | Result of last update run (0 = success, 1 = failure) |
| Reboot Required | `debian.reboot.required` | 1 | Whether a reboot is needed |

All items besides the raw status are dependent items with JSONPath preprocessing.

## Zabbix Triggers

| Severity | Name | Expression |
|---|---|---|
| Disaster | Remote update failed on `{HOST.NAME}` (check `/var/log/zabbix/zbx_remote_update.log`) | `last(/Debian Package Updates/vfs.file.contents[/var/log/zabbix/zbx_update_status])=1` |
| Average | There are {ITEM.LASTVALUE} security updates available on `{HOST.NAME}` | `last(/Debian Package Updates/debian.security.updates)>0` |
| Average | Reboot required to finish updates on `{HOST.NAME}` | `last(/Debian Package Updates/debian.reboot.required)>0` |
| Warning | Automatic security updates (unattended-upgrades) are disabled on `{HOST.NAME}` | `last(/Debian Package Updates/debian.autoupdate.enabled)=0` |
| Info | There are {ITEM.LASTVALUE} non-security updates available on `{HOST.NAME}` | `last(/Debian Package Updates/debian.package.updates)>0` / `debian.normal.updates>0` |

There is also a trigger for "Automatic security updates disabled on `{HOST.NAME}`". `unattended-upgrades` is disabled by default on most systems, enable it if you want automatic security alert.

## Logs

- Last run state: `/var/log/zabbix/zbx_update_status`
- Full log: `/var/log/zabbix/zbx_remote_update.log`

Each entry is timestamped with the executing user:

```bash
2026-08-26 17:54:48 - [INFO] - root - === Update started ===
2026-08-26 17:54:55 - [INFO] - root - === Update completed successfully ===
```

Log directory is owned by `zabbix:zabbix`

## Examples
<img width="1248" height="71" alt="image" src="https://github.com/user-attachments/assets/ef57949c-2917-4006-b5b9-9ac26ebaa0b0" />


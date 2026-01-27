# Scripts Guide

This document provides comprehensive documentation for all scripts in the `scripts/` folder.

---

## Overview

Scripts are organized by their role in the deployment lifecycle.

**See also:** [MIGRATION_PROVISIONING_GUIDE.md](MIGRATION_PROVISIONING_GUIDE.md) for complete deployment walkthrough.

| Phase | Scripts | Purpose |
|-------|---------|---------|
| **Admin** | `validate-env.sh`, `cli.sh`, `menu.sh` | Configuration validation and management |
| **Provision** | `azure-provision.sh` | Create Azure resources |
| **Mount** | `azure-mount.sh` | Mount Azure Files locally |
| **Deploy** | (Docker commands) | Build and run containers |
| **Migrate** | (Future) | Data migration from legacy systems |

---

## Script Reference

### `cli.sh` - Command Line Interface

The main entry point for all management tasks. Acts as a dispatcher for other scripts.

**Location:** `scripts/cli.sh`

**Usage:**
```bash
./scripts/cli.sh <command> [options]
```

**Commands:**

| Command | Description | Options |
|---------|-------------|---------|
| `validate-env` | Validate .env file | `--quiet`, `--errors-only` |
| `provision` | Run Azure resource provisioning | `-y`, `--yes` |
| `mount` | Mount Azure Files locally | `-y`, `--yes` (requires sudo) |
| `unmount` | Unmount Azure Files | `-y`, `--yes` (requires sudo) |
| `backup-db-source [name]` | Backup source database (full) | Optional name component |
| `backup-schema-source <name>` | Backup source schema only | Required name component |
| `show-log-provision` | Show latest provision log | |
| `show-log-mount` | Show latest mount log | |
| `list-logs` | List all available logs | |
| `help` | Show help message | |

**Examples:**
```bash
# Validate environment
./scripts/cli.sh validate-env

# Provision Azure resources (interactive)
./scripts/cli.sh provision

# Provision Azure resources (non-interactive)
./scripts/cli.sh provision -y

# Mount Azure Files (requires sudo)
sudo ./scripts/cli.sh mount

# Backup source database
./scripts/cli.sh backup-db-source pre_migration
```

**Lifecycle Phase:** Admin

---

### `menu.sh` - Interactive Menu

A cascading interactive menu system for all CLI commands.

**Location:** `scripts/menu.sh`

**Usage:**
```bash
./scripts/menu.sh
```

**Features:**
- Status indicators (Azure login, Docker, mounts, .env validation)
- Organized submenus: Environment, Azure, Docker, Database, Logs
- Quick Actions menu for common workflows
- Color-coded interface

**Menu Structure:**
```
Main Menu
├── Environment (validate, edit .env)
├── Azure (login, provision, mount/unmount)
├── Docker (build, start, stop, logs)
├── Database (backups)
├── Logs (view logs)
├── Quick Actions (full setup, restart)
└── Exit
```

**Lifecycle Phase:** Admin

---

### `validate-env.sh` - Environment Validation

Validates the `.env` file for completeness and correct values.

**Location:** `scripts/validate-env.sh`

**Usage:**
```bash
./scripts/validate-env.sh [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `-q`, `--quiet` | Minimal output, just pass/fail |
| `-e`, `--errors-only` | Only show errors (for scripted calls) |
| `-h`, `--help` | Show help message |

**Exit Codes:**
- `0` - All validations passed (may have warnings)
- `1` - One or more validations failed (errors)

**What It Validates:**
- Required Azure configuration (subscription ID, location, prefix)
- Database connection settings
- SuiteCRM application settings
- Password length and complexity
- Placeholder detection (your-*, CHANGE_ME, etc.)

**Output Format:**
```
✓ AZURE_SUBSCRIPTION_ID [561dd34b-5a5...] - Azure billing account
✗ SUITECRM_RUNTIME_MYSQL_PASSWORD [short] - MySQL connection password
⚠ MIGRATION_SOURCE_MYSQL_USER [your_username] - Legacy DB username (set before migration)
```

**Lifecycle Phase:** Admin (runs before provision/mount)

---

### `azure-provision.sh` - Azure Resource Provisioning

Creates all required Azure resources for the SuiteCRM deployment.

**Location:** `scripts/azure-provision.sh`

**Usage:**
```bash
./scripts/azure-provision.sh [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `-y`, `--yes` | Non-interactive mode (no prompts) |
| `-h`, `--help` | Show help message |

**Resources Created:**
1. **Resource Group** - Container for all resources
2. **MySQL Flexible Server** - Database server
3. **MySQL Database** - SuiteCRM database
4. **Firewall Rules** - Dev IP + Azure services access
5. **Storage Account** - For Azure Files
6. **File Shares** - suitecrm-upload, suitecrm-custom, suitecrm-cache
7. **Container Registry** - Docker image repository

**Prerequisites:**
- Azure CLI installed (`az`)
- Logged into Azure (`az login`)
- Valid `.env` file (runs `validate-env.sh` automatically)

**Logging:**
- Log file: `logs/latest_azure-provision_YYYYMMDD_HHMMSS.log`
- Timezone: America/New_York (Eastern US)
- Previous logs renamed (without "latest_" prefix)

**Interactive Mode (default):**
- Prompts before each step
- Press Enter to continue, Ctrl+C to abort

**Non-Interactive Mode (`-y`):**
- Runs all steps automatically
- Useful for CI/CD pipelines

**Lifecycle Phase:** Provision

---

### `azure-mount.sh` - Azure Files Mount

Mounts Azure File shares locally using SMB/CIFS.

**Location:** `scripts/azure-mount.sh`

**Usage:**
```bash
sudo ./scripts/azure-mount.sh [action] [options]
```

**Actions:**

| Action | Description |
|--------|-------------|
| `mount` (default) | Mount Azure File shares |
| `unmount` | Unmount Azure File shares |

**Options:**

| Option | Description |
|--------|-------------|
| `-y`, `--yes` | Non-interactive mode |
| `-h`, `--help` | Show help message |

**Prerequisites:**
- Root/sudo access
- `cifs-utils` package installed
- Azure Storage account created (via `azure-provision.sh`)
- Storage key available (in `.azure-secrets`)

**What It Does (mount):**
1. Validates environment
2. Retrieves storage key from `.azure-secrets` or Azure
3. Creates mount directories
4. Creates credentials file (`/etc/azure-suitecrm-credentials`)
5. Mounts file shares via SMB
6. Adds entries to `/etc/fstab` for persistence

**Mount Points:**
```
/mnt/azure/suitecrm/
├── upload/   → suitecrm-upload share
├── custom/   → suitecrm-custom share
└── cache/    → suitecrm-cache share
```

**What It Does (unmount):**
1. Unmounts all SuiteCRM file shares
2. Optionally removes fstab entries

**Logging:**
- Log file: `logs/latest_azure-mount_YYYYMMDD_HHMMSS.log`
- Timezone: America/New_York (Eastern US)

**Lifecycle Phase:** Mount

---

## Script Dependencies

```
┌─────────────────────────────────────────────────────────────────┐
│                        User / Admin                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     menu.sh (interactive)                       │
│                        OR                                       │
│                     cli.sh (command line)                       │
└─────────────────────────────────────────────────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────┐      ┌─────────────────┐    ┌─────────────┐
│validate-env │      │azure-provision  │    │azure-mount  │
│    .sh      │◀─────│      .sh        │────│    .sh      │
└─────────────┘      └─────────────────┘    └─────────────┘
         │                    │                    │
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────┐      ┌─────────────────┐    ┌─────────────┐
│   .env      │      │  Azure Cloud    │    │ Local Mount │
│   file      │      │  Resources      │    │  Points     │
└─────────────┘      └─────────────────┘    └─────────────┘
```

---

## Logging

All major scripts write timestamped logs to the `logs/` folder.

**Log Naming Convention:**
```
logs/
├── latest_azure-provision_20260126_143022.log   ← Most recent
├── latest_azure-mount_20260126_144515.log       ← Most recent
├── azure-provision_20260125_091234.log          ← Previous
└── azure-mount_20260125_092045.log              ← Previous
```

**Log Format:**
```
[2026-01-26 14:30:22 EST] [INFO] Starting Azure provisioning...
[2026-01-26 14:30:25 EST] [SUCCESS] Resource group created
[2026-01-26 14:35:12 EST] [ERROR] MySQL server creation failed
```

**Viewing Logs:**
```bash
# Via CLI
./scripts/cli.sh show-log-provision
./scripts/cli.sh show-log-mount
./scripts/cli.sh list-logs

# Directly
cat logs/latest_azure-provision_*.log
tail -f logs/latest_azure-mount_*.log
```

---

## Error Handling

All scripts follow consistent error handling:

1. **Validation First** - Scripts run `validate-env.sh` before critical operations
2. **Step-by-Step Logging** - Each step is logged with INFO/SUCCESS/ERROR
3. **Diagnostic Output** - On failure, possible causes are logged
4. **Non-Zero Exit Codes** - Failed scripts return exit code 1
5. **Console Messages** - Clear, colored error messages on console

**Interactive Mode Recovery:**
- In interactive mode, you can abort (Ctrl+C) before a problematic step
- Review the log, fix the issue, and re-run
- Existing resources are detected and skipped

---

## Deployment Workflow

Typical deployment sequence:

```bash
# 1. Configure environment
cp .env.example .env
nano .env

# 2. Validate configuration
./scripts/cli.sh validate-env

# 3. Provision Azure resources
./scripts/cli.sh provision

# 4. Mount Azure Files
sudo ./scripts/cli.sh mount

# 5. Build and start Docker
docker compose up --build -d

# 6. Access SuiteCRM
open http://localhost
```

Or use the interactive menu:
```bash
./scripts/menu.sh
# Select: Quick Actions → Full Setup
```

---

## Adding New Scripts

When adding new scripts to the `scripts/` folder:

1. **Update `cli.sh`** - Add command dispatcher entry
2. **Update `menu.sh`** - Add menu option in appropriate submenu
3. **Update this guide** - Document the new script
4. **Follow conventions:**
   - Use consistent logging (if long-running)
   - Support `-y`/`--yes` for non-interactive mode
   - Support `-h`/`--help` for help
   - Call `validate-env.sh` if using `.env` variables
   - Write logs to `logs/` folder with timestamp

---

## Troubleshooting

### Script won't run
```bash
# Check permissions
chmod +x scripts/*.sh

# Check shebang
head -1 scripts/cli.sh  # Should be #!/bin/bash
```

### Azure CLI errors
```bash
# Check login status
az account show

# Re-login if needed
az login

# Check subscription
az account set --subscription <SUBSCRIPTION_ID>
```

### Mount errors
```bash
# Check cifs-utils is installed
sudo apt install cifs-utils

# Check mount status
mount | grep suitecrm

# Check credentials file
sudo cat /etc/azure-suitecrm-credentials
```

### Docker errors
```bash
# Check Docker is running
docker info

# Check container status
docker compose ps

# View container logs
docker compose logs -f
```

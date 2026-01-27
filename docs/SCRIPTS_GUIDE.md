# Scripts Guide

This document provides comprehensive documentation for all scripts in the `scripts/` folder.

---

## Overview

Scripts are organized by their role in the deployment lifecycle.

**See also:** [MIGRATION_PROVISIONING_GUIDE.md](MIGRATION_PROVISIONING_GUIDE.md) for complete deployment walkthrough.

| Phase | Scripts | Purpose |
|-------|---------|---------|
| **Admin** | `validate-env.sh`, `cli.sh`, `menu.sh`, `azure-test-capabilities.sh`, `azure-validate-resources.sh` | Configuration validation and management |
| **Provision** | `azure-provision-infra.sh` | Create Azure resources |
| **Teardown** | `azure-teardown-infra.sh` | Delete Azure resources |
| **Mount** | `azure-mount-fileshare-to-local.sh` | Mount Azure Files locally |
| **Deploy** | `docker-build.sh`, `docker-start.sh`, `docker-stop.sh`, `docker-validate.sh`, `docker-teardown.sh` | Build and run containers |
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
| `test-azure-capabilities` | Test Azure CLI capabilities and permissions | |
| `validate-resources` | Check if Azure resources exist | |
| `teardown` | Delete all Azure infrastructure (DESTRUCTIVE) | |
| `docker-build` | Build Docker image | `-y`, `--yes`, `--no-cache` |
| `docker-start` | Start SuiteCRM container | `-y`, `--yes` |
| `docker-stop` | Stop SuiteCRM container | `-y`, `--yes` |
| `docker-validate` | Validate Docker environment | |
| `docker-teardown` | Remove Docker artifacts (DESTRUCTIVE) | `-y`, `--yes`, `--prune` |
| `docker-logs` | View container logs | |
| `backup-db-source [name]` | Backup source database (full) | Optional name component |
| `backup-schema-source <name>` | Backup source schema only | Required name component |
| `show-log-provision` | Show latest provision log | |
| `show-log-mount` | Show latest mount log | |
| `list-logs` | List all available logs | |
| `generate-env-example` | Generate .env.example from .env | |
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

# Test Azure capabilities before provisioning
./scripts/cli.sh test-azure-capabilities

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
├── Azure (login, provision, mount/unmount, test, teardown)
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

### `azure-provision-infra.sh` - Azure Resource Provisioning

Creates all required Azure resources for the SuiteCRM deployment.

**Location:** `scripts/azure-provision-infra.sh`

**Usage:**
```bash
./scripts/azure-provision-infra.sh [options]
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

### `azure-mount-fileshare-to-local.sh` - Azure Files Mount

Mounts Azure File shares locally using SMB/CIFS.

**Location:** `scripts/azure-mount-fileshare-to-local.sh`

**Usage:**
```bash
sudo ./scripts/azure-mount-fileshare-to-local.sh [action] [options]
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
- Azure Storage account created (via `azure-provision-infra.sh`)
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

### `azure-test-capabilities.sh` - Azure Capability Testing

Tests Azure CLI capabilities and permissions before provisioning resources.

**Location:** `scripts/azure-test-capabilities.sh`

**Usage:**
```bash
./scripts/azure-test-capabilities.sh
```

**Via CLI:**
```bash
./scripts/cli.sh test-azure-capabilities
```

**Via Menu:**
```
Main Menu → Azure Setup → Test Azure Capabilities
```

**What It Tests:**

1. **Azure Login Status** - Verifies user is logged into Azure CLI
2. **Environment Variables** - Loads and validates `.env` file
3. **Resource Group Creation** - Tests ability to create resource groups
4. **Storage Account Creation** - Tests ability to create storage accounts (required for Azure Files)
5. **MySQL Provider Registration** - Checks if `Microsoft.DBforMySQL` provider is registered
6. **ACR Service Accessibility** - Verifies Container Registry service is accessible

**Prerequisites:**
- Azure CLI installed (`az`)
- Logged into Azure (`az login`)
- Valid `.env` file with `AZURE_SUBSCRIPTION_ID` set

**What It Does:**

1. Checks Azure CLI login status and displays current user
2. Loads environment variables from `.env` file
3. Sets Azure subscription from `AZURE_SUBSCRIPTION_ID`
4. Creates temporary test resource group
5. Creates temporary test storage account (name truncated to 24 chars)
6. Checks MySQL provider registration status (registers if needed)
7. Tests ACR name availability as proxy for service access
8. Cleans up test resources (deletes resource group in background)
9. Displays summary of all test results

**Output Format:**
```
[STEP] Azure Login Check
[SUCCESS] Azure Login Check (User: ami@ITProtects.onmicrosoft.com)
[STEP] Load .env Variables
[SUCCESS] Load .env Variables
[STEP] Resource Group Creation
[SUCCESS] Resource Group Creation
...
============================================================================
                       TEST CAPABILITY SUMMARY
============================================================================
✔ Azure Login Check (User: ...)
✔ Load .env Variables
✔ Resource Group Creation
✔ Storage Account Creation
✔ MySQL Provider Status (Registered)
✔ ACR Service Check
✔ Cleanup Complete
============================================================================
```

**Exit Codes:**
- `0` - All tests completed (some may have failed, but script ran)
- `1` - Critical failure (not logged in, missing .env, etc.)

**When to Use:**
- Before running `azure-provision-infra.sh` to verify permissions
- After Azure subscription changes or permission updates
- Troubleshooting provisioning failures
- Verifying provider registrations

**Lifecycle Phase:** Admin (runs before Provision)

---

### `azure-teardown-infra.sh` - Azure Infrastructure Teardown

Permanently deletes all Azure resources created by `azure-provision-infra.sh`.

**Location:** `scripts/azure-teardown-infra.sh`

**Usage:**
```bash
./scripts/azure-teardown-infra.sh
```

**Via CLI:**
```bash
./scripts/cli.sh teardown
```

**Via Menu:**
```
Main Menu → Azure Setup → Teardown Infrastructure (DESTRUCTIVE)
```

**⚠️ WARNING: This is a destructive operation that cannot be undone!**

**What It Deletes (in order):**

1. **MySQL Flexible Server** - `buzzmag-mysql`
2. **Container Registry (ACR)** - `buzzmagacr`
3. **Resource Group** (cascading) - `rg-buzzmag-suitecrm`
   - This deletes Storage Account and all remaining resources

**Prerequisites:**
- Azure CLI installed (`az`)
- Logged into Azure (`az login`)
- Valid `.env` file with `AZURE_RESOURCE_PREFIX` set

**Output Format:**
```
[STEP] Loading environment configuration...
[SUCCESS] Environment loaded from .env
[STEP] Checking Azure Authentication...
[SUCCESS] Authenticated to Azure
[STEP] Deleting MySQL Flexible Server...
[SUCCESS] MySQL Server 'buzzmag-mysql' deleted
[STEP] Deleting Container Registry (ACR)...
[SUCCESS] ACR 'buzzmagacr' deleted
[STEP] Deleting Resource Group (Cascading Deletion)...
[SUCCESS] Resource Group 'rg-buzzmag-suitecrm' and all its contents deleted

============================================================================
                       TEARDOWN RESULTS SUMMARY
============================================================================
✔ Environment loaded from .env
✔ Authenticated to Azure
✔ MySQL Server 'buzzmag-mysql' deleted
✔ ACR 'buzzmagacr' deleted
✔ Resource Group 'rg-buzzmag-suitecrm' and all its contents deleted
============================================================================
```

**Exit Codes:**
- `0` - Teardown completed (resources deleted or not found)
- `1` - Critical failure (not logged in, missing .env)

**When to Use:**
- Starting fresh after a failed provisioning
- Cleaning up after testing
- Removing all Azure resources before re-provisioning

**Lifecycle Phase:** Admin (cleanup/reset)

---

### `azure-validate-resources.sh` - Azure Resource Validation

Validates that all Azure resources defined in `.env` exist (or don't exist). Useful for verifying provisioning status before deploying or troubleshooting.

**Location:** `scripts/azure-validate-resources.sh`

**Usage:**
```bash
./scripts/azure-validate-resources.sh
```

**Via CLI:**
```bash
./scripts/cli.sh validate-resources
```

**Via Menu:**
```
Main Menu → Azure Setup → Validate Resources
```

**What It Checks:**

| Resource | Service Type | Description |
|----------|--------------|-------------|
| `$AZURE_RESOURCE_GROUP` | Resource Group | Container for all Azure resources |
| `$AZURE_PROVISION_MYSQL_SERVER_NAME` | MySQL Flexible Server | Database server for SuiteCRM |
| `$SUITECRM_RUNTIME_MYSQL_NAME` | MySQL Database | SuiteCRM application database |
| `$AZURE_STORAGE_ACCOUNT_NAME` | Storage Account | Azure Files for persistent storage |
| `suitecrm-upload` | File Share | User uploaded files (documents, images) |
| `suitecrm-custom` | File Share | Custom modules and extensions |
| `suitecrm-cache` | File Share | Application cache files |
| `$AZURE_ACR_NAME` | Container Registry | Docker image repository |

**Prerequisites:**
- Azure CLI installed (`az`)
- Logged into Azure (`az login`)
- Valid `.env` file

**Output Format:**
```
============================================================================
                    AZURE RESOURCE VALIDATION SUMMARY
============================================================================

Configuration from .env:
  Subscription:    561dd34b-5a54-486f-abce-23ce53d2a1b4
  Location:        southcentralus
  Resource Prefix: buzz

RESOURCE NAME            SERVICE TYPE            DESCRIPTION                               EXISTS
============================================================================================
buzz-rg                  Resource Group          Container for all Azure resources         YES
buzz-mysql               MySQL Flexible Server   Database server for SuiteCRM              YES
suitecrm                 MySQL Database          SuiteCRM application database             YES
buzzmagstorage           Storage Account         Azure Files for persistent storage        YES
suitecrm-upload          File Share              User uploaded files (documents, images)   YES
suitecrm-custom          File Share              Custom modules and extensions             YES
suitecrm-cache           File Share              Application cache files                   YES
buzzacr                  Container Registry      Docker image repository                   NO
============================================================================================

Summary: 7 exist, 1 missing (of 8 resources)

○ Some resources are missing. Run: ./scripts/azure-provision-infra.sh

Log file: logs/latest_azure-validate-resources_20260127_143500.log
============================================================================
```

**Exit Codes:**
- `0` - Validation completed successfully
- `1` - Critical failure (not logged in, missing .env)

**When to Use:**
- After running provisioning to verify all resources were created
- Before deployment to ensure infrastructure is ready
- When troubleshooting connection issues
- After teardown to verify cleanup was complete

**Lifecycle Phase:** Admin (verification)

---

### `docker-build.sh` - Build Docker Image

Builds the SuiteCRM Docker image with logging and validation.

**Location:** `scripts/docker-build.sh`

**Usage:**
```bash
./scripts/docker-build.sh              # Interactive mode
./scripts/docker-build.sh -y           # Non-interactive mode
./scripts/docker-build.sh --no-cache   # Build without cache
```

**Via CLI:**
```bash
./scripts/cli.sh docker-build
./scripts/cli.sh docker-build --no-cache
```

**Via Menu:**
```
Main Menu → Docker Management → Build Docker Image
```

**What It Does:**
1. Validates Docker is installed and running
2. Checks Dockerfile and docker-compose.yml exist
3. Runs `docker compose build`
4. Displays image size and build time

**Prerequisites:**
- Docker installed and running
- `Dockerfile` in project root
- `docker-compose.yml` in project root

**Lifecycle Phase:** Deploy

---

### `docker-start.sh` - Start Container

Starts the SuiteCRM container with prerequisite validation.

**Location:** `scripts/docker-start.sh`

**Usage:**
```bash
./scripts/docker-start.sh        # Interactive mode
./scripts/docker-start.sh -y     # Non-interactive mode
```

**Via CLI:**
```bash
./scripts/cli.sh docker-start
```

**Via Menu:**
```
Main Menu → Docker Management → Start SuiteCRM
```

**Pre-Start Checks:**
1. Docker image exists (offers to build if not)
2. Azure Files mounted (warns if not)
3. No existing container running (offers to restart)

**What It Does:**
1. Validates all prerequisites
2. Runs `docker compose up -d`
3. Waits for health check to pass
4. Displays access URL

**Prerequisites:**
- Docker image built (`docker-build.sh`)
- Azure Files mounted (recommended for data persistence)

**Lifecycle Phase:** Deploy

---

### `docker-stop.sh` - Stop Container

Gracefully stops the SuiteCRM container without removing volumes.

**Location:** `scripts/docker-stop.sh`

**Usage:**
```bash
./scripts/docker-stop.sh        # Interactive mode
./scripts/docker-stop.sh -y     # Non-interactive mode
```

**Via CLI:**
```bash
./scripts/cli.sh docker-stop
```

**Via Menu:**
```
Main Menu → Docker Management → Stop SuiteCRM
```

**What It Does:**
1. Checks if container is running
2. Runs `docker compose down`
3. Verifies container stopped

**Note:** Volumes and data are preserved. Use `docker-teardown.sh` for complete cleanup.

**Lifecycle Phase:** Deploy

---

### `docker-validate.sh` - Validate Docker Environment

Validates the status of all Docker components for SuiteCRM.

**Location:** `scripts/docker-validate.sh`

**Usage:**
```bash
./scripts/docker-validate.sh
```

**Via CLI:**
```bash
./scripts/cli.sh docker-validate
```

**Via Menu:**
```
Main Menu → Docker Management → Validate Docker Status
```

**What It Checks:**

| Component | Type | Description |
|-----------|------|-------------|
| Docker daemon | Daemon | Docker service running |
| SuiteCRM image | Image | Docker image exists |
| suitecrm-web | Container | Container status |
| suitecrm-web | Health | Container health check |
| thebuzzmagazines_* | Volumes | Docker volumes |
| suitecrm-network | Network | Docker network |
| /mnt/azure/suitecrm/* | Mounts | Azure Files mounts |

**Output:** Summary table with status of all components

**Lifecycle Phase:** Deploy (verification)

---

### `docker-teardown.sh` - Remove Docker Artifacts (DESTRUCTIVE)

Removes all Docker containers, images, volumes, and networks for SuiteCRM.

**Location:** `scripts/docker-teardown.sh`

**Usage:**
```bash
./scripts/docker-teardown.sh           # Interactive (requires confirmation)
./scripts/docker-teardown.sh -y        # Non-interactive mode
./scripts/docker-teardown.sh --prune   # Also prune build cache
```

**Via CLI:**
```bash
./scripts/cli.sh docker-teardown
./scripts/cli.sh docker-teardown --prune
```

**Via Menu:**
```
Main Menu → Docker Management → Teardown Docker (DESTRUCTIVE)
```

**WARNING: This is a destructive operation!**

**What It Removes:**
1. SuiteCRM Docker container
2. SuiteCRM Docker image
3. Docker volumes (thebuzzmagazines_*)
4. Docker network
5. Build cache (with `--prune` flag)

**What It Does NOT Remove:**
- Azure Files mounts and data
- Azure cloud resources

**Safety:** Requires typing 'DELETE' to confirm in interactive mode.

**Lifecycle Phase:** Deploy (cleanup)

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
    ┌─────────────┬───────────┼───────────┬─────────────┐
    │             │           │           │             │
    ▼             ▼           ▼           ▼             ▼
┌────────┐  ┌──────────┐ ┌─────────┐ ┌─────────┐  ┌──────────┐
│validate│  │azure-test│ │azure-   │ │azure-   │  │azure-    │
│-env.sh │  │-capabil- │ │provision│ │teardown │  │mount.sh  │
│        │  │ities.sh  │ │-infra.sh│ │-infra.sh│  │          │
└────────┘  └──────────┘ └────┬────┘ └────┬────┘  └──────────┘
                              │           │
                              ▼           ▼
                      ┌───────────────────────┐
                      │   Azure Cloud         │
                      │   Resources           │
                      │   (create/delete)     │
                      └───────────────────────┘
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

# 2a. (Optional) Test Azure capabilities
./scripts/cli.sh test-azure-capabilities

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

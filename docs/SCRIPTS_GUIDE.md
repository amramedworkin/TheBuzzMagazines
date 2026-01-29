# Scripts Guide

This document provides comprehensive documentation for all scripts in the `scripts/` folder.

---

## Overview

Scripts are organized by their role in the deployment lifecycle.

**See also:** [MIGRATION_PROVISIONING_GUIDE.md](MIGRATION_PROVISIONING_GUIDE.md) for complete deployment walkthrough.

| Phase | Scripts | Purpose |
|-------|---------|---------|
| **Admin** | `env-validate.sh`, `env-show.sh`, `cli.sh`, `menu.sh`, `azure-test-capabilities.sh`, `azure-validate-resources.sh`, `azure-mysql-status.sh` | Configuration validation and management |
| **Provision** | `azure-provision-infra.sh` | Create Azure resources |
| **Teardown** | `azure-teardown-infra.sh` | Delete Azure resources |
| **Mount** | `azure-mount-fileshare-to-local.sh` | Mount Azure Files locally |
| **Deploy** | `docker-build.sh`, `docker-start.sh`, `docker-stop.sh`, `docker-validate.sh`, `docker-validate-lifecycle.sh`, `docker-teardown.sh` | Build and run containers |
| **Migrate** | (Future) | Data migration from legacy systems |

---

## Shared Library: `lib/common.sh`

All scripts share common functionality through the `scripts/lib/common.sh` library. This provides consistent colors, logging, and utilities across all scripts.

**Location:** `scripts/lib/common.sh`

### Sourcing the Library

Every script sources the library near the top:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
```

### What It Provides

| Category | Functions/Variables | Description |
|----------|---------------------|-------------|
| **Colors** | `RED`, `GREEN`, `YELLOW`, `BLUE`, `CYAN`, `MAGENTA`, `BOLD`, `DIM`, `NC` | Terminal color codes for consistent output |
| **Logging Setup** | `setup_logging()` | Creates timestamped log file with "latest_" prefix |
| **Core Logging** | `log()` | Logs to file and console with level-based coloring |
| **Log Helpers** | `log_info`, `log_success`, `log_warn`, `log_error`, `log_step` | Standard logging shortcuts |
| **Validation Helpers** | `log_check`, `log_ok`, `log_fail`, `log_skip` | For validation script output |
| **Log Finalization** | `finalize_log()` | Writes completion footer to log file |
| **Environment Loading** | `load_env_common()` | Loads `.env` with proper variable expansion |
| **Interactive Helpers** | `confirm_step()` | Interactive step confirmation prompts |
| **Error Handling** | `handle_error()` | Consistent error handling with diagnostics |
| **Menu Helpers** | `print_header`, `print_section`, `print_submenu_option`, `print_action_option` | Consistent menu formatting |

### Logging Levels

The `log()` function supports multiple levels with appropriate coloring:

| Level | Color | Symbol | Usage |
|-------|-------|--------|-------|
| `INFO` | Blue | `[INFO]` | Informational messages |
| `SUCCESS` | Green | `[SUCCESS]` | Successful operations |
| `WARN` | Yellow | `[WARN]` | Warnings (non-fatal) |
| `ERROR` | Red | `[ERROR]` | Errors (fatal) |
| `STEP` | Cyan | `[STEP]` | Step indicators |
| `CHECK` | Cyan | `[CHECK]` | Validation checks |
| `OK` | Green | `[OK]` | Validation passed |
| `FAIL` | Red | `[FAIL]` | Validation failed |
| `PASS` | Green | `[✓]` | Unicode pass (lifecycle) |
| `FAILED` | Red | `[✗]` | Unicode fail (lifecycle) |
| `WARNING` | Yellow | `[⚠]` | Unicode warning (lifecycle) |

### Environment Loading

`load_env_common()` handles all variable expansion including:

- **Global prefixes:** `AZURE_RESOURCE_PREFIX`, `DOCKER_PREFIX` from `GLOBAL_PREFIX`
- **Global passwords:** `SUITECRM_PASSWORD`, `AZURE_PASSWORD`, `DOCKER_PASSWORD` from `GLOBAL_PASSWORD`
- **Azure resources:** Resource group, MySQL server, storage account, ACR, Container App Environment
- **Azure Files:** `AZURE_FILES_SHARE_PREFIX`, `AZURE_FILES_CREDENTIALS_FILE` from `DOCKER_PREFIX`/`GLOBAL_PREFIX`
- **Docker resources:** Image name, container name, network name
- **MySQL connection:** Host derived from MySQL server name, passwords

### Timezone Configuration

The scripts use two separate timezone settings:

| Variable | Purpose | Default |
|----------|---------|---------|
| `TZ` | Application timezone for Docker containers and Azure resources | `America/Chicago` |
| `LOGGING_TZ` | Timezone for script log timestamps | `America/New_York` |

All logging functions use `LOGGING_TZ` so logs appear in Eastern US time regardless of where containers run.

### Example Usage in Scripts

```bash
#!/bin/bash
SCRIPT_NAME="my-script"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"
LOGS_DIR="${PROJECT_ROOT}/logs"

# Source shared library
source "$SCRIPT_DIR/lib/common.sh"

main() {
    setup_logging
    load_env_common
    
    log_info "Starting operation..."
    log_step "Step 1: Do something"
    
    if some_operation; then
        log_success "Operation completed"
    else
        log_error "Operation failed"
        exit 1
    fi
    
    trap finalize_log EXIT
}

main "$@"
```

### Custom Overrides

Some scripts override `log()` for specialized behavior:

- **`docker-teardown.sh`** and **`azure-teardown-infra.sh`**: Override `log()` to also track results in a `RESULTS` array for summary display
- **`docker-validate-lifecycle.sh`**: Override `log()` to use Unicode symbols (`✓`, `✗`, `⚠`) for validation output

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
| `show-env` | Display expanded .env variables | `all`, `global`, `azure`, `docker`, `mysql`, `suitecrm`, `migration` |
| `provision` | Run Azure resource provisioning | `-y`, `--yes`, `--status`, `--retry-shares` |
| `mount` | Mount Azure Files locally | `-y`, `--yes` (requires sudo) |
| `unmount` | Unmount Azure Files | `-y`, `--yes` (requires sudo) |
| `mount-status` | Check Azure Files mount status | (no sudo required) |
| `test-azure-capabilities` | Test Azure CLI capabilities and permissions | |
| `validate-resources` | Check if Azure resources exist | |
| `mysql-status` | Check Azure MySQL database status | `--quick`, `--connect` |
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
| `build-status` | Show build cycle status summary | Checks env, Azure, mounts, Docker |
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
├── 1. Environment (validate, edit .env)
├── 2. Azure (login, provision, mount/unmount, test, teardown)
├── 3. Docker (build, start, stop, logs)
├── 4. Database (backups)
├── 5. Logs (view logs)
├── 6. Quick Actions (full setup, restart)
├── b. Build Cycle (step-by-step local build with validation)
└── 0. Exit
```

**Lifecycle Phase:** Admin

---

### Build Cycle Menu

The Build Cycle menu provides a step-by-step guided workflow for the complete local development build process with validation gates between each phase.

**Access:**
```
Main Menu → b. Build Cycle
```

**Menu Structure:**
```
BUILD CYCLE - Local Development
├── BUILD STEPS (execute in order):
│   1. Validate Environment       Check .env configuration
│   2. Azure Provisioning         Create Azure resources
│   3. Validate Azure Resources   Verify resources exist
│   4. Mount Azure Files          Mount file shares locally
│   5. Pre-Build Validation       Check Docker prerequisites
│   6. Build Docker Image         Build the SuiteCRM image
│   7. Start Container            Start SuiteCRM container
│   8. Post-Build Validation      Verify container health
├── ACTIONS:
│   a. Run All Steps (with validation gates)
│   s. Show Status Summary
└── 0. Back to Main Menu
```

**Build Cycle Sequence:**

```
┌─────────────────────────┐
│ 1. Validate Environment │
└───────────┬─────────────┘
            ▼
┌─────────────────────────┐
│ 2. Azure Provisioning   │
└───────────┬─────────────┘
            ▼
┌─────────────────────────┐
│ 3. Validate Azure       │
└───────────┬─────────────┘
            ▼
┌─────────────────────────┐
│ 4. Mount Azure Files    │
└───────────┬─────────────┘
            ▼
┌─────────────────────────┐
│ 5. Pre-Build Validation │
└───────────┬─────────────┘
            ▼
┌─────────────────────────┐
│ 6. Build Docker Image   │
└───────────┬─────────────┘
            ▼
┌─────────────────────────┐
│ 7. Start Container      │
└───────────┬─────────────┘
            ▼
┌─────────────────────────┐
│ 8. Post-Build Validation│
└─────────────────────────┘
```

**Features:**

| Feature | Description |
|---------|-------------|
| **Individual Steps** | Execute any step independently (resume from any point) |
| **Run All** | Execute all 8 steps in sequence with validation gates |
| **Validation Gates** | "Run All" stops on first failure, doesn't skip ahead |
| **Status Summary** | Check current state of each component |
| **Idempotent Steps** | Safe to re-run (skips already-completed work) |
| **Step Numbering** | Clear 1-8 numbering reinforces the sequence |

**Run All Behavior:**

When selecting "Run All Steps":
1. Displays confirmation prompt
2. Executes each step in order
3. Stops on first failure with clear error message
4. Shows progress indicator (Step X of 8)
5. Provides summary at end

**Status Summary Output:**

```
Step   Component                      Status
───────────────────────────────────────────────────────────────
1      Environment (.env)             ✓
2-3    Azure Resources                ✓
4      Azure Files Mounts             ✓
5-6    Docker Image                   ✓
7-8    Container Running              ✓
───────────────────────────────────────────────────────────────

Recommendations:
  ✓ All components ready. SuiteCRM should be accessible.
```

**CLI Alternative:**

To check build status from command line:
```bash
./scripts/cli.sh build-status
```

**When to Use:**

- **First-time setup:** Run all steps in sequence
- **After partial failure:** Check status, then resume from failed step
- **Quick status check:** Use "Show Status Summary" to see what's ready
- **Troubleshooting:** Identify which component is not ready

---

### `env-validate.sh` - Environment Validation

Validates the `.env` file for completeness and correct values.

**Location:** `scripts/env-validate.sh`

**Usage:**
```bash
./scripts/env-validate.sh [options]
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
- Global configuration (GLOBAL_PREFIX, GLOBAL_PASSWORD)
- Derived prefixes (AZURE_RESOURCE_PREFIX, DOCKER_PREFIX)
- Derived passwords (SUITECRM_PASSWORD, AZURE_PASSWORD)
- Required Azure configuration (subscription ID, location)
- Database connection settings
- SuiteCRM application settings
- Password length and complexity
- Placeholder detection (your-*, CHANGE_ME, [YOUR_*], etc.)

**Output Format:**
```
✓ AZURE_SUBSCRIPTION_ID [561dd34b-5a5...] - Azure billing account
✗ SUITECRM_RUNTIME_MYSQL_PASSWORD [short] - MySQL connection password
⚠ MIGRATION_SOURCE_MYSQL_USER [your_username] - Legacy DB username (set before migration)
```

**Lifecycle Phase:** Admin (runs before provision/mount)

---

### `env-show.sh` - Display Environment Variables

Displays `.env` variables with fully expanded values, grouped by category. Shows actual resolved values instead of `${}` references.

**Location:** `scripts/env-show.sh`

**Usage:**
```bash
./scripts/env-show.sh [category]
```

**Via CLI:**
```bash
./scripts/cli.sh show-env [category]
```

**Via Menu:**
```
Main Menu → Environment → Show Environment Variables → [category]
```

**Categories:**

| Category | Description |
|----------|-------------|
| `all` | Show all variables (default) |
| `global` | Global prefix and password settings |
| `azure` | Azure resource configuration |
| `docker` | Docker build configuration |
| `mysql` | MySQL/database connection settings |
| `suitecrm` | SuiteCRM application settings |
| `migration` | Migration source/destination settings |

**Features:**
- All derived variables fully expanded (e.g., `${GLOBAL_PREFIX}` → `buzzmag`)
- Passwords masked in output (first 2 and last 2 chars shown)
- Grouped by logical category with descriptions
- Color-coded output for readability

**Output Example:**
```
═══════════════════════════════════════════════════════════════════════════
  DOCKER CONFIGURATION
═══════════════════════════════════════════════════════════════════════════

--- Container Naming ---
  DOCKER_IMAGE_NAME=buzzmag-suitecrm
      Image name
  DOCKER_CONTAINER_NAME=buzzmag-suitecrm-web
      Container name
  DOCKER_NETWORK_NAME=buzzmag-suitecrm-network
      Network name
```

**Lifecycle Phase:** Admin

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
| `--status` | Check what resources exist vs need creation |
| `--retry-shares` | Only retry file share creation (useful after partial failures) |
| `-h`, `--help` | Show help message |

**Re-run Safety:**

This script is safe to re-run after partial failures:
- Each resource is checked before creation
- Existing resources are skipped with a warning
- Only missing resources are created
- Use `--status` to see what exists before running
- Use `--retry-shares` to specifically retry file share creation

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
- Valid `.env` file (runs `env-validate.sh` automatically)

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
| `mount` (default) | Mount Azure File shares (requires sudo) |
| `unmount` | Unmount Azure File shares (requires sudo) |
| `status` | Check current mount status (no sudo required) |

**Options:**

| Option | Description |
|--------|-------------|
| `-y`, `--yes` | Non-interactive mode |
| `-h`, `--help` | Show help message |

**Status Check (no sudo):**

The `status` action can be run without sudo to check what's mounted:

```bash
./scripts/azure-mount-fileshare-to-local.sh status
# or
./scripts/cli.sh mount-status
```

This is useful for automated scripts to verify mount state before starting containers.

**Sudo Handling:**

The script uses sudo internally for privileged operations (creating directories in /mnt, mounting filesystems, writing to /etc/fstab). You will be prompted for your password when the script runs - you don't need to run the entire script with sudo.

**Prerequisites (for mount/unmount):**
- sudo access (password will be prompted)
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

### `azure-mysql-status.sh` - Azure MySQL Database Status

Tests the creation status and connectivity of the Azure MySQL database. Provides detailed information about server state, properties, firewall rules, and optional connection testing.

**Location:** `scripts/azure-mysql-status.sh`

**Usage:**
```bash
./scripts/azure-mysql-status.sh [options]

# Or via CLI
./scripts/cli.sh mysql-status [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--quick`, `-q` | Quick check - server existence only |
| `--connect`, `-c` | Test actual MySQL connection with credentials |
| `--help`, `-h` | Show help message |

**Checks Performed:**

| Check | Description |
|-------|-------------|
| Azure CLI Auth | Verifies Azure CLI is installed and authenticated |
| MySQL Server | Checks if the MySQL Flexible Server exists |
| Server State | Verifies server is in "Ready" state (not Stopped/Stopping) |
| Server Properties | Displays SKU, MySQL version, storage, FQDN |
| Database | Checks if the SuiteCRM database exists |
| Firewall Rules | Lists configured firewall rules |
| SSL Config | Shows SSL enforcement settings |
| Connection Test | Attempts actual MySQL connection (with `--connect`) |

**Environment Variables Used:**

| Variable | Purpose |
|----------|---------|
| `AZURE_SUBSCRIPTION_ID` | Azure subscription |
| `AZURE_RESOURCE_GROUP` | Resource group name |
| `AZURE_PROVISION_MYSQL_SERVER_NAME` | MySQL server name |
| `SUITECRM_RUNTIME_MYSQL_HOST` | Connection host |
| `SUITECRM_RUNTIME_MYSQL_PORT` | Connection port |
| `SUITECRM_RUNTIME_MYSQL_USER` | Connection username |
| `SUITECRM_RUNTIME_MYSQL_PASSWORD` | Connection password |
| `SUITECRM_RUNTIME_MYSQL_NAME` | Database name |
| `SUITECRM_RUNTIME_MYSQL_SSL_ENABLED` | SSL enabled flag |

**Example Output:**
```
============================================================================
                    AZURE MYSQL DATABASE STATUS CHECK
============================================================================

  Server: buzzmag-mysql
  Resource Group: buzzmag-rg

----------------------------------------------------------------------------

[INFO] Loaded environment from: /home/user/project/.env
[CHECK] Azure CLI authentication
[PASS] Logged into Azure: My Subscription
[CHECK] MySQL Server existence: buzzmag-mysql
[PASS] MySQL Server exists: buzzmag-mysql
[CHECK] MySQL Server state
[PASS] Server state: Ready
[CHECK] MySQL Server properties
  SKU:      Standard_B1s
  Version:  MySQL 8.4
  Storage:  20 GB
  FQDN:     buzzmag-mysql.mysql.database.azure.com
[CHECK] Database existence: suitecrm
[PASS] Database 'suitecrm' exists
[CHECK] Firewall rules
[PASS] Firewall rules configured: 2 rule(s)
  - AllowAzureServices: 0.0.0.0 - 0.0.0.0
  - AllowLocalDev: 192.168.1.100 - 192.168.1.100
[CHECK] SSL configuration
[PASS] SSL enforcement: Enabled (require_secure_transport=ON)

============================================================================
                        AZURE MYSQL STATUS SUMMARY
============================================================================

  Check                     Result   Details
  ------------------------- -------- ---------------------------------------------
  Azure CLI Auth            PASS     Subscription: My Subscription
  MySQL Server              PASS     Exists in buzzmag-rg
  Server State              PASS     Ready
  Server Properties         PASS     SKU: Standard_B1s, MySQL 8.4, 20GB
  Database                  PASS     Exists on server
  Firewall Rules            PASS     2 rule(s)
  SSL Config                PASS     SSL required
  ------------------------- -------- ---------------------------------------------

  ✓ All checks passed

  Log file: logs/latest_azure-mysql-status_20260128_100000.log
```

**Menu Access:**
- Main Menu → Azure Setup → MySQL Database Status
  - Full Status Check
  - Quick Check (server only)
  - Connection Test

**Exit Codes:**
- `0` - All checks passed
- `1` - One or more checks failed

**When to Use:**
- After provisioning to verify MySQL was created successfully
- Before deploying containers to ensure database is accessible
- When troubleshooting database connection issues
- To check if the server has been stopped (cost savings feature)

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

### `docker-validate-lifecycle.sh` - Docker Lifecycle Validation

Comprehensive validation script with three distinct phases for the Docker build and deployment lifecycle: **PRE** (before build), **POST** (after build), and **DEPLOYED** (Azure deployment).

**Location:** `scripts/docker-validate-lifecycle.sh`

**Usage:**
```bash
./scripts/docker-validate-lifecycle.sh pre        # Pre-build validation
./scripts/docker-validate-lifecycle.sh post       # Post-build validation  
./scripts/docker-validate-lifecycle.sh deployed   # Azure deployment validation
./scripts/docker-validate-lifecycle.sh all        # Run all phases
```

**Phases:**

| Phase | Purpose | When to Run |
|-------|---------|-------------|
| `pre` | Validate prerequisites before Docker build | Before `docker-build.sh` |
| `post` | Validate build results and container functionality | After `docker-start.sh` |
| `deployed` | Validate Azure cloud deployment | After deploying to Azure |
| `all` | Run all validation phases | Complete verification |

**PRE Phase Checks:**

| Check | Description |
|-------|-------------|
| Docker CLI installed | Docker command available in PATH |
| Docker daemon running | Docker service is responding |
| Docker Compose available | docker compose command works |
| Dockerfile exists | Dockerfile present and has content |
| docker-compose.yml valid | YAML syntax is valid |
| docker-entrypoint.sh | Entrypoint script exists |
| .env file | Environment file exists and passes validation |
| Disk space | Sufficient disk space available (5GB+ recommended) |
| Port 80 available | Port not already in use |
| Azure Files mounts | Mount points status (optional) |

**POST Phase Checks:**

| Check | Description |
|-------|-------------|
| Docker image exists | Image was built successfully |
| Image layer inspection | Image layers are valid |
| Container running | Container is up and running |
| Container health | Health check status (healthy/unhealthy/starting) |
| Container logs | Check for errors in container logs |
| HTTP response | Container responds on port 80 |
| Docker volumes | Volume status |
| Docker network | Network configuration |
| Database connectivity | Container can connect to MySQL |

**DEPLOYED Phase Checks (Azure):**

| Check | Description |
|-------|-------------|
| Azure CLI installed | `az` command available |
| Azure login | Logged into Azure CLI |
| Correct subscription | Expected subscription is active |
| Resource group exists | Azure resource group created |
| Container Registry | ACR exists and accessible |
| ACR images | Images pushed to registry |
| Container Apps Environment | CAE provisioned |
| Container App | App deployed and running |
| Container App replicas | Replicas are running |
| HTTPS response | App responds via HTTPS |
| Azure MySQL | Database server is Ready |
| Storage account | Azure Files storage available |

**Output:**
```
============================================================================
                    VALIDATION SUMMARY
============================================================================

CHECK                                     PHASE     STATUS    DETAILS
─────────────────────────────────────────────────────────────────────────────────────
Docker CLI installed                      PRE       PASS  Docker version 29.1.5
Docker daemon running                     PRE       PASS  Version 29.1.5
docker-compose.yml valid                  PRE       PASS  Syntax validated
.env configuration valid                  PRE       PASS  All required variables set
Port 80 available                         PRE       WARN  In use - may conflict
─────────────────────────────────────────────────────────────────────────────────────

Results: 8 passed, 0 failed, 3 warnings

○ VALIDATION PASSED WITH WARNINGS - 3 warning(s)
```

**Exit Codes:**
- `0` - All validations passed (may have warnings)
- `1` - One or more validations failed

**Logging:**
- Log file: `logs/latest_docker-validate-lifecycle_YYYYMMDD_HHMMSS.log`
- Timezone: America/New_York (Eastern US)

**Lifecycle Phase:** Deploy (verification at all stages)

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
│  env-  │  │azure-test│ │azure-   │ │azure-   │  │azure-    │
│validate│  │-capabil- │ │provision│ │teardown │  │mount.sh  │
│  .sh   │  │ities.sh  │ │-infra.sh│ │-infra.sh│  │          │
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

1. **Validation First** - Scripts run `env-validate.sh` before critical operations
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
# Set GLOBAL_PREFIX, GLOBAL_PASSWORD, AZURE_SUBSCRIPTION_ID

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

**Key Configuration Variables:**

| Variable | Purpose | Example |
|----------|---------|---------|
| `GLOBAL_PREFIX` | Naming prefix for all resources | `buzzmag` |
| `GLOBAL_PASSWORD` | Default password for dev | `q2w3e4R%` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription GUID | `561dd34b-...` |

Or use the interactive menu:
```bash
./scripts/menu.sh
# Select: Quick Actions → Full Setup
```

---

## Adding New Scripts

When adding new scripts to the `scripts/` folder:

1. **Source `lib/common.sh`** - Use the shared library for colors, logging, and utilities
2. **Update `cli.sh`** - Add command dispatcher entry
3. **Update `menu.sh`** - Add menu option in appropriate submenu
4. **Update this guide** - Document the new script
5. **Follow conventions:**
   - Source `lib/common.sh` for consistent look and feel
   - Use `setup_logging()` and `finalize_log()` for log files
   - Use `load_env_common()` instead of custom `.env` loading
   - Support `-y`/`--yes` for non-interactive mode
   - Support `-h`/`--help` for help
   - Write logs to `logs/` folder with timestamp

**Script Template:**

```bash
#!/bin/bash
# ============================================================================
# Script Name - Description
# ============================================================================

SCRIPT_NAME="my-script"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"
LOGS_DIR="${PROJECT_ROOT}/logs"

# Source common utilities
source "$SCRIPT_DIR/lib/common.sh"

# Options
INTERACTIVE_MODE=true

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes) INTERACTIVE_MODE=false; shift ;;
            -h|--help) show_help; exit 0 ;;
            *) echo "Unknown option: $1"; exit 1 ;;
        esac
    done
}

main() {
    parse_args "$@"
    setup_logging
    load_env_common
    
    trap finalize_log EXIT
    
    log_info "Starting..."
    # Your script logic here
    log_success "Completed"
}

main "$@"
```

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

# Environment Variables Guide

This document provides a comprehensive reference for all environment variables used in the TheBuzzMagazines SuiteCRM deployment.

---

## Overview

Environment variables are organized into logical groups based on their purpose:

| Group Prefix | Purpose | Used By |
|--------------|---------|---------|
| `AZURE_PROVISION_MYSQL_*` | Azure MySQL server infrastructure creation | `azure-provision-infra.sh` |
| `AZURE_RESOURCE_*` | Azure resource naming and location | `azure-provision-infra.sh` |
| `AZURE_STORAGE_*` | Azure Files storage account | `azure-provision-infra.sh`, `azure-mount-fileshare-to-local.sh` |
| `AZURE_ACR_*` | Azure Container Registry | `azure-provision-infra.sh` |
| `AZURE_CONTAINER_*` | Azure Container Apps settings | Deployment scripts |
| `SUITECRM_RUNTIME_MYSQL_*` | Docker container DB connection | `docker-compose.yml`, `docker-entrypoint.sh` |
| `SUITECRM_*` | SuiteCRM application settings | `docker-entrypoint.sh` |
| `MIGRATION_SOURCE_MYSQL_*` | Legacy MySQL database (source) | `cli.sh`, migration scripts |
| `MIGRATION_DEST_MYSQL_*` | SuiteCRM MySQL database (destination) | Migration scripts |
| `BUZZ_ADVERT_MSACCESS_*` | Legacy MS Access database | Migration scripts (optional) |

> **Note:** SuiteCRM's actual configuration files (`config.php`, `config_override.php`) are generated inside the Docker container at runtime by `docker-entrypoint.sh`. Those files are ephemeral and outside the scope of this `.env` file.

**See also:** [MIGRATION_PROVISIONING_GUIDE.md](MIGRATION_PROVISIONING_GUIDE.md) for complete deployment walkthrough.

---

## Variable Group Details

### 1. Azure Resource Configuration

Core Azure settings used for resource naming and location.

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `AZURE_SUBSCRIPTION_ID` | ✅ | Azure subscription GUID | `561dd34b-5a54-486f-abce-23ce53d2a1b4` |
| `AZURE_LOCATION` | ✅ | Azure region for all resources | `southcentralus`, `eastus` |
| `AZURE_RESOURCE_PREFIX` | ✅ | Naming prefix (3-15 chars, lowercase, alphanumeric) | `buzzmag` |
| `AZURE_RESOURCE_GROUP` | Auto | Resource group name (derived) | `rg-buzzmag-suitecrm` |

**How to get `AZURE_SUBSCRIPTION_ID`:**
```bash
az account show --query id -o tsv
```

---

### 2. Azure Provisioning: MySQL Server (`AZURE_PROVISION_MYSQL_*`)

Settings for **creating** the Azure MySQL Flexible Server. These control the infrastructure tier, storage, and version.

| Variable | Required | Description | Default | Example |
|----------|----------|-------------|---------|---------|
| `AZURE_PROVISION_MYSQL_SERVER_NAME` | Auto | MySQL server name (derived) | `${AZURE_RESOURCE_PREFIX}-mysql` | `buzzmag-mysql` |
| `AZURE_PROVISION_MYSQL_SKU` | No | Compute tier | `Standard_B1ms` | `Standard_B2ms`, `Standard_D2ds_v4` |
| `AZURE_PROVISION_MYSQL_STORAGE_GB` | No | Storage in GB | `32` | `64`, `128` |
| `AZURE_PROVISION_MYSQL_VERSION` | No | MySQL version | `8.0-lts` | `8.0-lts`, `5.7` |

**SKU Options:**
- `Standard_B1ms` - Burstable, 1 vCore, 2 GB RAM (cheapest, dev/test)
- `Standard_B2ms` - Burstable, 2 vCores, 8 GB RAM
- `Standard_D2ds_v4` - General Purpose, 2 vCores, 8 GB RAM (production)

---

### 3. Azure Storage Account (`AZURE_STORAGE_*`)

Persistent file storage for SuiteCRM uploads, customizations, and cache.

| Variable | Required | Description | Default | Example |
|----------|----------|-------------|---------|---------|
| `AZURE_STORAGE_ACCOUNT_NAME` | Auto | Storage account name (derived) | `${AZURE_RESOURCE_PREFIX}storage` | `buzzmagstorage` |
| `AZURE_STORAGE_SKU` | No | Storage redundancy | `Standard_LRS` | `Standard_GRS` |

**Storage SKU Options:**
- `Standard_LRS` - Locally redundant (cheapest)
- `Standard_GRS` - Geo-redundant (production)

---

### 4. Azure Container Registry (`AZURE_ACR_*`)

Docker image repository in Azure.

| Variable | Required | Description | Default | Example |
|----------|----------|-------------|---------|---------|
| `AZURE_ACR_NAME` | Auto | Registry name (derived) | `${AZURE_RESOURCE_PREFIX}acr` | `buzzmagacr` |
| `AZURE_ACR_SKU` | No | Registry tier | `Basic` | `Standard`, `Premium` |

---

### 5. Azure Container Apps (`AZURE_CONTAINER_*`)

Serverless container hosting configuration.

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `AZURE_CONTAINER_APP_ENV` | Auto | Container Apps environment name | `${AZURE_RESOURCE_PREFIX}-cae` |
| `AZURE_CONTAINER_APP_NAME` | No | Container app name | `suitecrm` |

---

### 6. SuiteCRM Runtime: MySQL Connection (`SUITECRM_RUNTIME_MYSQL_*`)

How the Docker container **connects** to the database at runtime. These variables are passed to `docker-entrypoint.sh`, which generates SuiteCRM's configuration files.

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `SUITECRM_RUNTIME_MYSQL_HOST` | ✅ | Database hostname | `${AZURE_PROVISION_MYSQL_SERVER_NAME}.mysql.database.azure.com` |
| `SUITECRM_RUNTIME_MYSQL_PORT` | No | Database port | `3306` |
| `SUITECRM_RUNTIME_MYSQL_NAME` | ✅ | Database name | `suitecrm` |
| `SUITECRM_RUNTIME_MYSQL_USER` | ✅ | Database username | `suitecrm` |
| `SUITECRM_RUNTIME_MYSQL_PASSWORD` | ✅ | Database password | (none) |
| `SUITECRM_RUNTIME_MYSQL_SSL_ENABLED` | No | Enable SSL for MySQL | `true` |
| `SUITECRM_RUNTIME_MYSQL_SSL_VERIFY` | No | Verify SSL certificate | `true` |

**Password Requirements (Azure MySQL):**
- Minimum 8 characters
- Must contain uppercase, lowercase, and numbers
- Example: `MyP@ssw0rd123`

---

### 7. SuiteCRM Application Settings (`SUITECRM_*`)

Application-level configuration for SuiteCRM.

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `SUITECRM_SITE_URL` | ✅ | Public URL for SuiteCRM | `http://localhost` |
| `SUITECRM_ADMIN_USER` | ✅ | Admin username | `admin` |
| `SUITECRM_ADMIN_PASSWORD` | ✅ | Admin password | (none) |
| `SUITECRM_LOG_LEVEL` | No | Log verbosity | `debug` |
| `SUITECRM_INSTALLER_LOCKED` | No | Lock installer after setup | `false` |

**Log Levels:** `fatal`, `error`, `warning`, `notice`, `info`, `debug`

---

### 8. Migration Source: MySQL (`MIGRATION_SOURCE_MYSQL_*`)

Connection to the **existing** MySQL database containing data migrated from MS Access. Migration scripts **read** from this database.

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `MIGRATION_SOURCE_MYSQL_HOST` | ⚠️ | Source database host | `localhost` |
| `MIGRATION_SOURCE_MYSQL_PORT` | No | Source database port | `3306` |
| `MIGRATION_SOURCE_MYSQL_NAME` | ⚠️ | Source database name | `advertisers` |
| `MIGRATION_SOURCE_MYSQL_USER` | ⚠️ | Source database username | (placeholder) |
| `MIGRATION_SOURCE_MYSQL_PASSWORD` | ⚠️ | Source database password | (placeholder) |

⚠️ = Required before running migration

---

### 9. Migration Destination: MySQL (`MIGRATION_DEST_MYSQL_*`)

Connection to the SuiteCRM database for **writing** migrated data.

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `MIGRATION_DEST_MYSQL_HOST` | ⚠️ | Destination database host | `localhost` |
| `MIGRATION_DEST_MYSQL_PORT` | No | Destination database port | `3306` |
| `MIGRATION_DEST_MYSQL_NAME` | ⚠️ | Destination database name | `suitecrm` |
| `MIGRATION_DEST_MYSQL_USER` | ⚠️ | Destination database username | (placeholder) |
| `MIGRATION_DEST_MYSQL_PASSWORD` | ⚠️ | Destination database password | (placeholder) |

⚠️ = Required before running migration

---

### 10. Legacy MS Access Database (`BUZZ_ADVERT_MSACCESS_*`)

Direct connection to the original MS Access database if needed for migration.

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `BUZZ_ADVERT_MSACCESS_PATH` | No | Path to .mdb file | `/path/to/BuzzAdvertisers.mdb` |
| `BUZZ_ADVERT_MSACCESS_DRIVER` | No | ODBC driver | `MDBTools` |
| `BUZZ_ADVERT_MSACCESS_USER` | No | Access username | (empty) |
| `BUZZ_ADVERT_MSACCESS_PASSWORD` | No | Access password | (empty) |

---

### 11. General Configuration

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `TZ` | No | Timezone | `America/Chicago` |
| `SKIP_DB_WAIT` | No | Skip database connection wait | `false` |
| `AZURE_FILES_MOUNT_BASE` | No | Local mount path for Azure Files | `/mnt/azure/suitecrm` |
| `BACKUP_DIR` | No | Backup directory | `database/backups` |

---

## Variable Flow Diagram

```
┌────────────────────────────────────────────────────────────────────┐
│                         .env File                                   │
└────────────────────────────────────────────────────────────────────┘
                                    │
         ┌──────────────────────────┼──────────────────────────┐
         │                          │                          │
         ▼                          ▼                          ▼
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│ azure-provision │      │  docker-compose │      │     cli.sh      │
│      .sh        │      │      .yml       │      │  (backups/etc)  │
└─────────────────┘      └─────────────────┘      └─────────────────┘
         │                          │                          │
         │                          │                          │
         ▼                          ▼                          ▼
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│  Azure MySQL    │      │ Docker Container│      │  Local MySQL    │
│  Azure Storage  │      │ ┌─────────────┐ │      │  (advertisers)  │
│  Azure ACR      │      │ │entrypoint.sh│ │      │                 │
└─────────────────┘      │ └──────┬──────┘ │      └─────────────────┘
                         │        │        │
                         │        ▼        │
                         │ ┌─────────────┐ │
                         │ │config_over- │ │
                         │ │ride.php     │ │
                         │ │(generated)  │ │
                         │ └─────────────┘ │
                         └─────────────────┘
```

---

## Validation

Run the validation script to check your `.env` file:

```bash
./scripts/validate-env.sh
```

Options:
- `--quiet` - Minimal output
- `--errors-only` - Only show errors

---

## Quick Setup

1. Copy the example file:
   ```bash
   cp .env.example .env
   ```

2. Edit with your values:
   ```bash
   nano .env
   ```

3. Validate:
   ```bash
   ./scripts/validate-env.sh
   ```

4. Provision Azure resources:
   ```bash
   ./scripts/azure-provision-infra.sh
   ```

5. Mount Azure Files:
   ```bash
   sudo ./scripts/azure-mount-fileshare-to-local.sh
   ```

6. Start Docker:
   ```bash
   docker compose up --build -d
   ```

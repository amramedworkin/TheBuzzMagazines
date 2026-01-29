# Environment Variables Guide

This document provides a comprehensive reference for all environment variables used in the TheBuzzMagazines SuiteCRM deployment.

---

## Overview

Environment variables are organized into logical groups based on their purpose:

| Group Prefix | Purpose | Used By |
|--------------|---------|---------|
| `GLOBAL_*` | Global prefix and password settings (single source of truth) | All scripts |
| `AZURE_PROVISION_MYSQL_*` | Azure MySQL server infrastructure creation | `azure-provision-infra.sh` |
| `AZURE_RESOURCE_*` | Azure resource naming and location | `azure-provision-infra.sh` |
| `AZURE_STORAGE_*` | Azure Files storage account | `azure-provision-infra.sh`, `azure-mount-fileshare-to-local.sh` |
| `AZURE_FILES_*` | Azure Files share names and mount configuration | `azure-mount-fileshare-to-local.sh`, `docker-validate-lifecycle.sh` |
| `AZURE_ACR_*` | Azure Container Registry | `azure-provision-infra.sh` |
| `AZURE_CONTAINER_*` | Azure Container Apps settings | Deployment scripts |
| `DOCKER_*` | Docker build configuration (template generation) | `docker-generate.sh`, `Dockerfile.template` |
| `SUITECRM_RUNTIME_MYSQL_*` | Docker container DB connection | `docker-compose.yml`, `docker-entrypoint.sh` |
| `SUITECRM_*` | SuiteCRM application settings | `docker-entrypoint.sh` |
| `MIGRATION_SOURCE_MYSQL_*` | Legacy MySQL database (source) | `cli.sh`, migration scripts |
| `MIGRATION_DEST_MYSQL_*` | SuiteCRM MySQL database (destination) | Migration scripts |
| `BUZZ_ADVERT_MSACCESS_*` | Legacy MS Access database | Migration scripts (optional) |
| `LOGGING_*` | Script logging configuration | All scripts with logging |

> **Note:** SuiteCRM's actual configuration files (`config.php`, `config_override.php`) are generated inside the Docker container at runtime by `docker-entrypoint.sh`. Those files are ephemeral and outside the scope of this `.env` file.

**See also:** [MIGRATION_PROVISIONING_GUIDE.md](MIGRATION_PROVISIONING_GUIDE.md) for complete deployment walkthrough.

---

## Variable Group Details

### 1. Global Configuration (`GLOBAL_*`)

**Single Source of Truth** for naming prefixes and passwords across all services.

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `GLOBAL_PREFIX` | ✅ | Global naming prefix (3-8 chars, lowercase, alphanumeric) | `buzzmag` |
| `GLOBAL_PASSWORD` | ✅ | Default password for all services (development only) | `q2w3e4R%` |

**Derived Variables:**

| Variable | Inherits From | Description |
|----------|---------------|-------------|
| `AZURE_RESOURCE_PREFIX` | `${GLOBAL_PREFIX}` | Prefix for Azure resource names |
| `DOCKER_PREFIX` | `${GLOBAL_PREFIX}` | Prefix for Docker container/image names |
| `SUITECRM_PASSWORD` | `${GLOBAL_PASSWORD}` | Password for SuiteCRM DB, admin, migration |
| `AZURE_PASSWORD` | `${GLOBAL_PASSWORD}` | Password for Azure MySQL admin |
| `DOCKER_PASSWORD` | `${GLOBAL_PASSWORD}` | Password for Docker container auth |

**Why Global Variables?**

- **Consistency**: All resources use the same naming convention
- **Single Source of Truth**: Change prefix/password in ONE place
- **Development Simplicity**: One password for quick local setup
- **Production Security**: Override individual passwords for production

**Production Password Security:**

In production, override individual passwords for security:

```bash
# Development (uses GLOBAL_PASSWORD for all)
GLOBAL_PASSWORD=q2w3e4R%
SUITECRM_PASSWORD=${GLOBAL_PASSWORD}

# Production (unique passwords for each service)
# SUITECRM_PASSWORD=YourUniqueSuiteCRMPwd1!
# AZURE_PASSWORD=YourUniqueAzurePwd2@
# DOCKER_PASSWORD=YourUniqueDockerPwd3#
```

---

### 2. Azure Resource Configuration

Core Azure settings used for resource naming and location.

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `AZURE_SUBSCRIPTION_ID` | ✅ | Azure subscription GUID | `561dd34b-5a54-486f-abce-23ce53d2a1b4` |
| `AZURE_LOCATION` | ✅ | Azure region for all resources | `southcentralus`, `eastus` |
| `AZURE_RESOURCE_PREFIX` | Auto | Naming prefix (derived from `GLOBAL_PREFIX`) | `buzzmag` |
| `AZURE_RESOURCE_GROUP` | Auto | Resource group name (derived) | `buzzmag-rg` |

**How to get `AZURE_SUBSCRIPTION_ID`:**
```bash
az account show --query id -o tsv
```

---

### 3. Azure Provisioning: MySQL Server (`AZURE_PROVISION_MYSQL_*`)

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

### 4. Azure Storage Account (`AZURE_STORAGE_*`)

Persistent file storage for SuiteCRM uploads, customizations, and cache.

| Variable | Required | Description | Default | Example |
|----------|----------|-------------|---------|---------|
| `AZURE_STORAGE_ACCOUNT_NAME` | Auto | Storage account name (derived) | `${AZURE_RESOURCE_PREFIX}storage` | `buzzmagstorage` |
| `AZURE_STORAGE_SKU` | No | Storage redundancy | `Standard_LRS` | `Standard_GRS` |
| `AZURE_FILES_SHARE_PREFIX` | No | Prefix for file share names | `${DOCKER_PREFIX}-suitecrm` | `buzzmag-suitecrm` |
| `AZURE_FILES_SHARE_UPLOAD` | No | Upload share name component | `upload` | `upload` |
| `AZURE_FILES_SHARE_CUSTOM` | No | Custom share name component | `custom` | `custom` |
| `AZURE_FILES_SHARE_CACHE` | No | Cache share name component | `cache` | `cache` |
| `AZURE_FILES_CREDENTIALS_FILE` | No | SMB credentials file path | `/etc/azure-${GLOBAL_PREFIX}-credentials` | `/etc/azure-buzzmag-credentials` |

**Storage SKU Options:**
- `Standard_LRS` - Locally redundant (cheapest)
- `Standard_GRS` - Geo-redundant (production)

---

### 5. Azure Container Registry (`AZURE_ACR_*`)

Docker image repository in Azure.

| Variable | Required | Description | Default | Example |
|----------|----------|-------------|---------|---------|
| `AZURE_ACR_NAME` | Auto | Registry name (derived) | `${AZURE_RESOURCE_PREFIX}acr` | `buzzmagacr` |
| `AZURE_ACR_SKU` | No | Registry tier | `Basic` | `Standard`, `Premium` |

---

### 6. Azure Container Apps (`AZURE_CONTAINER_*`)

Serverless container hosting configuration.

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `AZURE_CONTAINER_APP_ENV` | Auto | Container Apps environment name | `${AZURE_RESOURCE_PREFIX}-cae` |
| `AZURE_CONTAINER_APP_NAME` | No | Container app name | `suitecrm` |

---

### 7. Docker Build Configuration (`DOCKER_*`)

Settings for Docker image **build-time** configuration. These variables are used by `docker-generate.sh` to create `Dockerfile` and `docker-compose.yml` from templates via `envsubst`.

> **Important:** These are **build-time** variables baked into the Docker image. They differ from `SUITECRM_*` variables which are **runtime** variables passed to the container at startup.

#### 7.1 Base Image and Versions

| Variable | Required | Description | Default | Suggested Values |
|----------|----------|-------------|---------|------------------|
| `DOCKER_PHP_BASE_IMAGE` | No | Base PHP Docker image | `php:8.3-apache` | `php:8.2-apache`, `php:8.1-apache` |
| `DOCKER_SUITECRM_VERSION` | No | SuiteCRM version to install | `8.8.0` | Check [SuiteCRM releases](https://github.com/salesagility/SuiteCRM-Core/releases) |
| `DOCKER_PLATFORM` | No | Target platform architecture | `linux/amd64` | `linux/arm64` for ARM-based systems |

**Version Compatibility:**
- SuiteCRM 8.x requires PHP 8.1, 8.2, or 8.3
- Azure Container Apps requires `linux/amd64`

#### 7.2 Container Naming

Container names now use `DOCKER_PREFIX` for consistent naming:

| Variable | Required | Description | Default | Example |
|----------|----------|-------------|---------|---------|
| `DOCKER_PREFIX` | Auto | Naming prefix (from `GLOBAL_PREFIX`) | `${GLOBAL_PREFIX}` | `buzzmag` |
| `DOCKER_IMAGE_NAME` | No | Docker image name | `${DOCKER_PREFIX}-suitecrm` | `buzzmag-suitecrm` |
| `DOCKER_IMAGE_TAG` | No | Docker image tag | `latest` | Version number, `dev`, `prod` |
| `DOCKER_CONTAINER_NAME` | No | Running container name | `${DOCKER_PREFIX}-suitecrm-web` | `buzzmag-suitecrm-web` |
| `DOCKER_NETWORK_NAME` | No | Docker network name | `${DOCKER_PREFIX}-suitecrm-network` | `buzzmag-suitecrm-network` |

#### 7.3 Image Labels

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `DOCKER_LABEL_MAINTAINER` | No | Image maintainer info | `TheBuzzMagazines DevOps` |
| `DOCKER_LABEL_DESCRIPTION` | No | Image description | `SuiteCRM Cloud-Native for Azure Container Apps` |

#### 7.4 PHP Configuration

These settings are baked into the PHP configuration at build time.

| Variable | Required | Description | Default | Suggested Range |
|----------|----------|-------------|---------|-----------------|
| `DOCKER_PHP_MEMORY_LIMIT` | No | PHP memory limit | `512M` | `256M` - `1G` |
| `DOCKER_PHP_UPLOAD_MAX_FILESIZE` | No | Maximum upload file size | `100M` | `20M` - `200M` |
| `DOCKER_PHP_POST_MAX_SIZE` | No | Maximum POST data size | `100M` | Should be ≥ upload_max_filesize |
| `DOCKER_PHP_MAX_EXECUTION_TIME` | No | Script timeout (seconds) | `300` | `60` - `600` |
| `DOCKER_PHP_MAX_INPUT_TIME` | No | Input parsing timeout | `300` | `60` - `600` |
| `DOCKER_PHP_MAX_INPUT_VARS` | No | Maximum input variables | `10000` | `3000` - `10000` |

**Tuning Guidelines:**
- **Development:** Lower memory (`256M`), higher timeouts for debugging
- **Production:** Higher memory (`512M`+), strict timeouts (`120s`)
- **Large file uploads:** Increase both `UPLOAD_MAX_FILESIZE` and `POST_MAX_SIZE`

#### 7.5 OPcache Configuration

PHP opcode cache settings for performance optimization.

| Variable | Required | Description | Default | Suggested Range |
|----------|----------|-------------|---------|-----------------|
| `DOCKER_OPCACHE_MEMORY` | No | OPcache memory in MB | `256` | `128` - `512` |
| `DOCKER_OPCACHE_INTERNED_STRINGS` | No | Interned strings buffer in MB | `16` | `8` - `32` |
| `DOCKER_OPCACHE_MAX_FILES` | No | Maximum cached files | `10000` | `5000` - `20000` |

**Tuning Guidelines:**
- SuiteCRM has ~8000 PHP files; `10000` provides headroom
- Increase memory for complex customizations
- Production: Higher values improve performance

#### 7.6 Networking

| Variable | Required | Description | Default | Notes |
|----------|----------|-------------|---------|-------|
| `DOCKER_HOST_PORT` | No | Port exposed on host machine | `80` | Change if port 80 is in use |
| `DOCKER_CONTAINER_PORT` | No | Port inside container | `80` | Typically leave as `80` |

**Example:** To run on port 8080 locally:
```bash
DOCKER_HOST_PORT=8080
DOCKER_CONTAINER_PORT=80
```

#### 7.7 Health Check

Container health check configuration for Docker and orchestrators.

| Variable | Required | Description | Default | Notes |
|----------|----------|-------------|---------|-------|
| `DOCKER_HEALTHCHECK_INTERVAL` | No | Time between health checks | `30s` | Lower = faster detection |
| `DOCKER_HEALTHCHECK_TIMEOUT` | No | Timeout for health check | `10s` | Must be < interval |
| `DOCKER_HEALTHCHECK_RETRIES` | No | Retries before unhealthy | `3` | Higher = more tolerance |
| `DOCKER_HEALTHCHECK_START_PERIOD` | No | Grace period after start | `60s` | Allow time for SuiteCRM init |

**Suggested Values:**
- **Development:** `interval=60s`, `start_period=120s` (more lenient)
- **Production:** `interval=30s`, `retries=3` (faster detection)

#### Complete DOCKER_* Example

```bash
# ============================================================================
# DOCKER BUILD CONFIGURATION
# ============================================================================
# Prefix (inherits from GLOBAL_PREFIX)
DOCKER_PREFIX=${GLOBAL_PREFIX}

# Base image and versions
DOCKER_PHP_BASE_IMAGE=php:8.3-apache
DOCKER_SUITECRM_VERSION=8.8.0
DOCKER_PLATFORM=linux/amd64

# Container naming (uses DOCKER_PREFIX)
DOCKER_IMAGE_NAME=${DOCKER_PREFIX}-suitecrm
DOCKER_IMAGE_TAG=latest
DOCKER_CONTAINER_NAME=${DOCKER_PREFIX}-suitecrm-web
DOCKER_NETWORK_NAME=${DOCKER_PREFIX}-suitecrm-network

# Labels
DOCKER_LABEL_MAINTAINER=TheBuzzMagazines DevOps
DOCKER_LABEL_DESCRIPTION=SuiteCRM Cloud-Native for Azure Container Apps

# PHP Configuration
DOCKER_PHP_MEMORY_LIMIT=512M
DOCKER_PHP_UPLOAD_MAX_FILESIZE=100M
DOCKER_PHP_POST_MAX_SIZE=100M
DOCKER_PHP_MAX_EXECUTION_TIME=300
DOCKER_PHP_MAX_INPUT_TIME=300
DOCKER_PHP_MAX_INPUT_VARS=10000

# OPcache Configuration
DOCKER_OPCACHE_MEMORY=256
DOCKER_OPCACHE_INTERNED_STRINGS=16
DOCKER_OPCACHE_MAX_FILES=10000

# Ports
DOCKER_HOST_PORT=80
DOCKER_CONTAINER_PORT=80

# Health check
DOCKER_HEALTHCHECK_INTERVAL=30s
DOCKER_HEALTHCHECK_TIMEOUT=10s
DOCKER_HEALTHCHECK_RETRIES=3
DOCKER_HEALTHCHECK_START_PERIOD=60s
```

---

### 8. SuiteCRM Runtime: MySQL Connection (`SUITECRM_RUNTIME_MYSQL_*`)

How the Docker container **connects** to the database at runtime. These variables are passed to `docker-entrypoint.sh`, which generates SuiteCRM's configuration files.

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `SUITECRM_RUNTIME_MYSQL_HOST` | ✅ | Database hostname | `${AZURE_PROVISION_MYSQL_SERVER_NAME}.mysql.database.azure.com` |
| `SUITECRM_RUNTIME_MYSQL_PORT` | No | Database port | `3306` |
| `SUITECRM_RUNTIME_MYSQL_NAME` | ✅ | Database name | `suitecrm` |
| `SUITECRM_RUNTIME_MYSQL_USER` | ✅ | Database username | `suitecrm` |
| `SUITECRM_RUNTIME_MYSQL_PASSWORD` | ✅ | Database password | `${SUITECRM_PASSWORD}` |
| `SUITECRM_RUNTIME_MYSQL_SSL_ENABLED` | No | Enable SSL for MySQL | `true` |
| `SUITECRM_RUNTIME_MYSQL_SSL_VERIFY` | No | Verify SSL certificate | `true` |
| `SUITECRM_RUNTIME_MYSQL_SSL_CA` | No | Path to SSL CA certificate | `/etc/ssl/certs/ca-certificates.crt` |

**Password Inheritance:**
- Uses `${SUITECRM_PASSWORD}` which inherits from `${GLOBAL_PASSWORD}`
- Override for production: `SUITECRM_RUNTIME_MYSQL_PASSWORD=YourUniquePwd`

**Password Requirements (Azure MySQL):**
- Minimum 8 characters
- Must contain uppercase, lowercase, and numbers
- Example: `MyP@ssw0rd123`

---

### 9. SuiteCRM Application Settings (`SUITECRM_*`)

Application-level configuration for SuiteCRM.

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `SUITECRM_PASSWORD` | Auto | Shared password for SuiteCRM services | `${GLOBAL_PASSWORD}` |
| `SUITECRM_SITE_URL` | ✅ | Public URL for SuiteCRM | `http://localhost` |
| `SUITECRM_ADMIN_USER` | ✅ | Admin username | `admin` |
| `SUITECRM_ADMIN_PASSWORD` | ✅ | Admin password | `${SUITECRM_PASSWORD}` |
| `SUITECRM_LOG_LEVEL` | No | Log verbosity | `debug` |
| `SUITECRM_INSTALLER_LOCKED` | No | Lock installer after setup | `false` |

**Log Levels:** `fatal`, `error`, `warning`, `notice`, `info`, `debug`

---

### 10. Migration Source: MySQL (`MIGRATION_SOURCE_MYSQL_*`)

Connection to the **existing** MySQL database containing data migrated from MS Access. Migration scripts **read** from this database.

> **Note:** These are LEGACY system credentials and do NOT use `GLOBAL_*` variables.

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `MIGRATION_SOURCE_MYSQL_HOST` | ⚠️ | Source database host | `localhost` |
| `MIGRATION_SOURCE_MYSQL_PORT` | No | Source database port | `3306` |
| `MIGRATION_SOURCE_MYSQL_NAME` | ⚠️ | Source database name | `advertisers` |
| `MIGRATION_SOURCE_MYSQL_USER` | ⚠️ | Source database username | (placeholder) |
| `MIGRATION_SOURCE_MYSQL_PASSWORD` | ⚠️ | Source database password | (placeholder) |

⚠️ = Required before running migration

---

### 11. Migration Destination: MySQL (`MIGRATION_DEST_MYSQL_*`)

Connection to the SuiteCRM database for **writing** migrated data.

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `MIGRATION_DEST_MYSQL_HOST` | ⚠️ | Destination database host | `localhost` |
| `MIGRATION_DEST_MYSQL_PORT` | No | Destination database port | `3306` |
| `MIGRATION_DEST_MYSQL_NAME` | ⚠️ | Destination database name | `suitecrm` |
| `MIGRATION_DEST_MYSQL_USER` | ⚠️ | Destination database username | `suitecrm` |
| `MIGRATION_DEST_MYSQL_PASSWORD` | ⚠️ | Destination database password | `${SUITECRM_PASSWORD}` |

⚠️ = Required before running migration

---

### 12. Legacy MS Access Database (`BUZZ_ADVERT_MSACCESS_*`)

Direct connection to the original MS Access database if needed for migration.

> **Note:** These are LEGACY system credentials and do NOT use `GLOBAL_*` variables.

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `BUZZ_ADVERT_MSACCESS_PATH` | No | Path to .mdb file | `/path/to/BuzzAdvertisers.mdb` |
| `BUZZ_ADVERT_MSACCESS_DRIVER` | No | ODBC driver | `MDBTools` |
| `BUZZ_ADVERT_MSACCESS_USER` | No | Access username | (empty) |
| `BUZZ_ADVERT_MSACCESS_PASSWORD` | No | Access password | (empty) |

---

### 13. General Configuration

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `TZ` | No | Application timezone (Docker/Azure containers) | `America/Chicago` |
| `SKIP_DB_WAIT` | No | Skip database connection wait | `false` |
| `AZURE_FILES_MOUNT_BASE` | No | Local mount path for Azure Files | `/mnt/azure/suitecrm` |
| `BACKUP_DIR` | No | Backup directory | `database/backups` |
| `SCHEMA_BACKUP_DIR` | No | Schema backup directory | `database/backups` |

---

### 14. Logging Configuration

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `LOGGING_TZ` | No | Timezone for script logging and log timestamps | `America/New_York` |

**Note:** `LOGGING_TZ` is separate from `TZ` to allow logs in a different timezone than the application. For example, you may run Docker containers in `America/Chicago` (southcentralus Azure region) but want log timestamps in `America/New_York` (Eastern US) for your team.

---

## Variable Flow Diagram

```
┌────────────────────────────────────────────────────────────────────────────┐
│                              .env File                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │  GLOBAL_*   │  │  AZURE_*    │  │  DOCKER_*   │  │ SUITECRM_*  │        │
│  │ Prefix/Pwd  │──│ Infra setup │  │ Build-time  │  │  Runtime    │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
│         │                │                │                │               │
│         ▼                ▼                ▼                ▼               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    DERIVED VARIABLES                                │   │
│  │  AZURE_RESOURCE_PREFIX = ${GLOBAL_PREFIX}                           │   │
│  │  DOCKER_PREFIX = ${GLOBAL_PREFIX}                                   │   │
│  │  SUITECRM_PASSWORD = ${GLOBAL_PASSWORD}                             │   │
│  │  AZURE_PASSWORD = ${GLOBAL_PASSWORD}                                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────────┘
         │                   │                   │                   │
         │                   │                   │                   │
         ▼                   ▼                   │                   ▼
┌─────────────────┐  ┌─────────────────┐         │         ┌─────────────────┐
│ azure-provision │  │ docker-generate │         │         │     cli.sh      │
│      .sh        │  │      .sh        │         │         │  (backups/etc)  │
│                 │  │   (envsubst)    │         │         │                 │
└─────────────────┘  └─────────────────┘         │         └─────────────────┘
         │                   │                   │                   │
         ▼                   ▼                   │                   ▼
┌─────────────────┐  ┌─────────────────┐         │         ┌─────────────────┐
│  Azure MySQL    │  │  Dockerfile     │         │         │  Local MySQL    │
│  Azure Storage  │  │  docker-compose │         │         │  (advertisers)  │
│  Azure ACR      │  │  (generated)    │         │         │                 │
└─────────────────┘  └─────────────────┘         │         └─────────────────┘
                             │                   │
                             ▼                   │
                     ┌─────────────────┐         │
                     │  docker build   │         │
                     │  docker start   │◀────────┘
                     └─────────────────┘  SUITECRM_* passed
                             │            at container startup
                             ▼
                     ┌─────────────────┐
                     │ Docker Container│
                     │ ┌─────────────┐ │
                     │ │entrypoint.sh│ │
                     │ └──────┬──────┘ │
                     │        │        │
                     │        ▼        │
                     │ ┌─────────────┐ │
                     │ │config_over- │ │
                     │ │ride.php     │ │
                     │ │(generated)  │ │
                     │ └─────────────┘ │
                     └─────────────────┘
```

**Key Insight:** 
- `GLOBAL_*` variables are the **single source of truth** for prefixes and passwords
- `DOCKER_*` variables are used at **build-time** to generate `Dockerfile` and `docker-compose.yml`
- `SUITECRM_*` variables are passed at **runtime** to the container and used by `docker-entrypoint.sh`

---

## Validation

Run the validation script to check your `.env` file:

```bash
./scripts/env-validate.sh
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

2. Edit with your values (minimum required):
   ```bash
   # Set these in .env:
   GLOBAL_PREFIX=yourprefix        # 3-8 chars, lowercase
   GLOBAL_PASSWORD=YourPwd123!     # 8+ chars, mixed case, numbers
   AZURE_SUBSCRIPTION_ID=<your-subscription-guid>
   ```

3. Validate:
   ```bash
   ./scripts/env-validate.sh
   ```

4. Provision Azure resources:
   ```bash
   ./scripts/azure-provision-infra.sh
   ```

5. Generate Docker files from templates:
   ```bash
   ./scripts/cli.sh docker-generate
   ```

6. Build Docker image:
   ```bash
   ./scripts/cli.sh docker-build
   ```

7. Mount Azure Files:
   ```bash
   sudo ./scripts/azure-mount-fileshare-to-local.sh
   ```

8. Start Docker:
   ```bash
   ./scripts/cli.sh docker-start
   ```

9. Validate everything:
   ```bash
   ./scripts/cli.sh docker-validate
   ```

---

## Production Security Checklist

When deploying to production, override the default passwords:

```bash
# In .env for production:

# Keep global defaults for development reference
GLOBAL_PREFIX=yourprefix
GLOBAL_PASSWORD=DevPassword123!

# Override each password for production
SUITECRM_PASSWORD=UniqueSuiteCRMPwd1!
AZURE_PASSWORD=UniqueAzurePwd2@
DOCKER_PASSWORD=UniqueDockerPwd3#

# Override specific service passwords if needed
SUITECRM_RUNTIME_MYSQL_PASSWORD=UniqueMySQLPwd4$
SUITECRM_ADMIN_PASSWORD=UniqueAdminPwd5%
MIGRATION_DEST_MYSQL_PASSWORD=UniqueMigDestPwd6^
```

**Security Best Practices:**
- [ ] Each service has a unique password
- [ ] Passwords are at least 12 characters
- [ ] Passwords contain uppercase, lowercase, numbers, and special characters
- [ ] `.env` file is git-ignored and not committed
- [ ] Secrets are rotated periodically

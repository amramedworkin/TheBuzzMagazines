# Migration & Provisioning Guide

This document provides a comprehensive, step-by-step guide for standing up the TheBuzzMagazines SuiteCRM environment from scratch, including local development setup and full Azure deployment.

**Last Updated:** January 2026
**Target Environment:** Azure Container Apps (Serverless)
**SuiteCRM Version:** 8.8.0

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Stack Components](#2-stack-components)
3. [Docker Container Build Process](#3-docker-container-build-process)
4. [Azure Resource Provisioning](#4-azure-resource-provisioning)
5. [Mounted File Systems](#5-mounted-file-systems)
6. [Architecture Diagram](#6-architecture-diagram)
7. [Step-by-Step Instructions](#7-step-by-step-instructions)
   - [7.1 Local Environment Setup](#71-local-environment-setup)
   - [7.2 Azure Provisioning](#72-azure-provisioning)
   - [7.3 Local Azure Files Mounting](#73-local-azure-files-mounting)
   - [7.4 Docker Image Creation](#74-docker-image-creation)
   - [7.5 Data Migration](#75-data-migration)
   - [7.6 Azure Deployment](#76-azure-deployment-complete-walkthrough)

---

## 1. Architecture Overview

### Design Principles

1. **Stateless Containers** - The Docker container contains no persistent data. All state lives in Azure services.
2. **Configuration via Environment Variables** - No hardcoded configuration files. All settings are injected at runtime.
3. **Cloud-Native** - Designed for Azure Container Apps (serverless), not traditional VMs.
4. **Portable** - Can run locally with Docker Compose connected to Azure backend, or fully in Azure.

### High-Level Data Flow

```
User Request
     │
     ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Azure Container Apps                         │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                  SuiteCRM Container                       │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐│  │
│  │  │   Apache    │  │     PHP     │  │  SuiteCRM 8.8.0     ││  │
│  │  │   (Port 80) │──│   8.3       │──│  Application        ││  │
│  │  └─────────────┘  └─────────────┘  └─────────────────────┘│  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
         │                                           │
         │ Database Queries                          │ File I/O
         │ (SSL Required)                            │
         ▼                                           ▼
┌─────────────────────────┐              ┌─────────────────────────┐
│   Azure Database for    │              │   Azure Files           │
│   MySQL Flexible Server │              │   (SMB Shares)          │
│   ─────────────────────│              │   ─────────────────────  │
│   • suitecrm database   │              │   • suitecrm-upload     │
│   • SSL/TLS encrypted   │              │   • suitecrm-custom     │
│   • Auto-backups        │              │   • suitecrm-cache      │
└─────────────────────────┘              └─────────────────────────┘
```

---

## 2. Stack Components

### Container Stack

| Layer | Technology | Version | Purpose |
|-------|------------|---------|---------|
| OS | Debian (via PHP image) | Bookworm | Base operating system |
| Web Server | Apache | 2.4.x | HTTP server, mod_rewrite |
| Runtime | PHP | 8.3 | Application runtime |
| Application | SuiteCRM | 8.8.0 | CRM application |

### PHP Extensions Installed

| Extension | Purpose |
|-----------|---------|
| `mysqli` | MySQL database connectivity |
| `pdo_mysql` | PDO MySQL driver |
| `gd` | Image processing (with freetype, jpeg) |
| `zip` | Archive handling |
| `intl` | Internationalization |
| `xml` | XML processing |
| `opcache` | PHP bytecode caching |
| `imap` | Email integration |
| `bcmath` | Arbitrary precision mathematics |

### Azure Services

| Service | SKU | Purpose |
|---------|-----|---------|
| Azure Container Apps | Consumption | Serverless container hosting |
| Azure Database for MySQL | Flexible Server (B1ms) | CRM data storage |
| Azure Storage Account | Standard LRS | File shares for uploads/customizations |
| Azure Container Registry | Basic | Docker image repository |

### Local Development Tools

| Tool | Purpose |
|------|---------|
| Docker Desktop | Container runtime |
| Azure CLI | Azure resource management |
| cifs-utils | SMB mounting for Azure Files |
| MySQL Client | Database operations |

---

## 3. Docker Container Build Process

This section explains exactly how the Docker image is constructed.

### 3.1 Dockerfile Structure

The Dockerfile is located at the project root: `./Dockerfile`

#### Stage 1: Base Image Selection

```dockerfile
FROM --platform=linux/amd64 php:8.3-apache
```

**Why this image:**
- Official PHP image with Apache bundled
- Debian-based (Bookworm) for package availability
- `linux/amd64` platform specified for Azure Container Apps compatibility
- PHP 8.3 is the latest stable version supported by SuiteCRM 8.8.0

#### Stage 2: System Dependencies

```dockerfile
RUN apt-get update && apt-get install -y \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libzip-dev \
    libicu-dev \
    libxml2-dev \
    libc-client-dev \
    libkrb5-dev \
    unzip \
    wget \
    curl \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
```

**Package purposes:**
- `libfreetype6-dev`, `libjpeg62-turbo-dev`, `libpng-dev` - Required for GD image library
- `libzip-dev` - Required for ZIP extension
- `libicu-dev` - Required for intl extension
- `libxml2-dev` - Required for XML extension
- `libc-client-dev`, `libkrb5-dev` - Required for IMAP extension with Kerberos
- `unzip`, `wget`, `curl` - Utility tools for downloading SuiteCRM
- `ca-certificates` - SSL certificates for Azure MySQL connection

#### Stage 3: PHP Extension Installation

```dockerfile
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-install -j$(nproc) \
        mysqli \
        gd \
        zip \
        intl \
        xml \
        opcache \
        imap \
        bcmath \
        pdo \
        pdo_mysql
```

**Build optimization:**
- `-j$(nproc)` uses all available CPU cores for parallel compilation
- GD is configured with freetype and jpeg support for image manipulation
- IMAP is configured with Kerberos and SSL for secure email

#### Stage 4: Apache Configuration

```dockerfile
# Enable required Apache modules
RUN a2enmod rewrite headers

# Set DocumentRoot for SuiteCRM 8
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Enable .htaccess overrides
RUN sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

# Listen on 0.0.0.0:80 (required for containers)
RUN sed -i 's/Listen 80/Listen 0.0.0.0:80/' /etc/apache2/ports.conf
```

**Critical configurations:**
- `mod_rewrite` - Required for SuiteCRM's URL routing
- `mod_headers` - Required for security headers
- `DocumentRoot` set to `/var/www/html/public` - SuiteCRM 8 requires this (different from SuiteCRM 7)
- `AllowOverride All` - Enables `.htaccess` processing
- `Listen 0.0.0.0:80` - Container must listen on all interfaces

#### Stage 5: PHP Configuration

```dockerfile
# Use production PHP settings
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Custom SuiteCRM settings
RUN { \
    echo 'memory_limit = 512M'; \
    echo 'upload_max_filesize = 100M'; \
    echo 'post_max_size = 100M'; \
    echo 'max_execution_time = 300'; \
    echo 'max_input_time = 300'; \
    echo 'max_input_vars = 10000'; \
    echo 'date.timezone = UTC'; \
    echo 'session.cookie_httponly = 1'; \
    echo 'session.cookie_secure = 1'; \
    echo 'session.use_strict_mode = 1'; \
    } > "$PHP_INI_DIR/conf.d/suitecrm.ini"

# OPcache for production performance
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.interned_strings_buffer=16'; \
    echo 'opcache.max_accelerated_files=10000'; \
    echo 'opcache.revalidate_freq=0'; \
    echo 'opcache.validate_timestamps=0'; \
    echo 'opcache.save_comments=1'; \
    echo 'opcache.fast_shutdown=1'; \
    } > "$PHP_INI_DIR/conf.d/opcache-recommended.ini"

# Force SSL for MySQL connections (Azure requirement)
RUN { \
    echo 'mysqli.default_ssl = true'; \
    } > "$PHP_INI_DIR/conf.d/mysqli-ssl.ini"
```

**Setting explanations:**
- `memory_limit = 512M` - SuiteCRM needs substantial memory for complex operations
- `upload_max_filesize = 100M` - Allow large file uploads
- `max_input_vars = 10000` - SuiteCRM forms can have many fields
- `opcache.validate_timestamps=0` - Disable timestamp checking in production (faster)
- `mysqli.default_ssl = true` - Force SSL for Azure MySQL connections

#### Stage 6: SuiteCRM Installation

```dockerfile
WORKDIR /var/www/html

RUN wget -q https://github.com/salesagility/SuiteCRM-Core/releases/download/v${SUITECRM_VERSION}/SuiteCRM-${SUITECRM_VERSION}.zip \
    && unzip -q SuiteCRM-${SUITECRM_VERSION}.zip \
    && mv SuiteCRM-${SUITECRM_VERSION}/* . \
    && mv SuiteCRM-${SUITECRM_VERSION}/.[!.]* . 2>/dev/null || true \
    && rmdir SuiteCRM-${SUITECRM_VERSION} \
    && rm SuiteCRM-${SUITECRM_VERSION}.zip
```

**This is critical:** SuiteCRM is baked INTO the image at build time. The application code is immutable once built. This ensures:
- Consistent deployments
- No need to download SuiteCRM at runtime
- Faster container startup
- Version control of the exact SuiteCRM release

#### Stage 7: Directory Setup and Permissions

```dockerfile
# Create persistent data directories
RUN mkdir -p /var/www/html/public/legacy/upload \
    && mkdir -p /var/www/html/public/legacy/custom \
    && mkdir -p /var/www/html/public/legacy/cache

# Set ownership and permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 775 /var/www/html/public/legacy/upload \
    && chmod -R 775 /var/www/html/public/legacy/custom \
    && chmod -R 775 /var/www/html/public/legacy/cache
```

**Directory purposes:**
- `upload/` - User-uploaded files (documents, attachments)
- `custom/` - Customizations, custom modules, themes
- `cache/` - Compiled templates, metadata cache

These directories will be **mounted from Azure Files** at runtime, replacing the empty directories created here.

#### Stage 8: Entrypoint Script

```dockerfile
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["apache2-foreground"]
```

The entrypoint script (`docker-entrypoint.sh`) runs before Apache starts and:
1. Sets permissions on mounted volumes
2. Generates `public/legacy/.env` with database connection string
3. Generates `public/legacy/config_override.php` with runtime settings
4. Waits for database to be available
5. Starts Apache

### 3.2 Entrypoint Script Details

The entrypoint script dynamically generates SuiteCRM configuration from environment variables:

**Generated files:**

1. `/var/www/html/public/legacy/.env`:
```
DATABASE_URL="mysql://user:pass@host:3306/dbname"
```

2. `/var/www/html/public/legacy/config_override.php`:
```php
$sugar_config['dbconfig']['db_host_name'] = 'host';
$sugar_config['dbconfig']['db_user_name'] = 'user';
$sugar_config['dbconfig']['db_password'] = 'pass';
$sugar_config['dbconfig']['db_name'] = 'dbname';
$sugar_config['dbconfig']['db_ssl_enabled'] = true;
$sugar_config['site_url'] = 'https://yoursite.com';
// ... more settings
```

**Why this approach:**
- Configuration files are regenerated on every container start
- No secrets baked into the image
- Easy to change settings without rebuilding
- Works with Azure Container Apps secrets management

### 3.3 Environment Variables Used by Container

| Variable | Purpose | Required |
|----------|---------|----------|
| `SUITECRM_RUNTIME_MYSQL_HOST` | Database hostname | Yes |
| `SUITECRM_RUNTIME_MYSQL_PORT` | Database port | No (default: 3306) |
| `SUITECRM_RUNTIME_MYSQL_NAME` | Database name | Yes |
| `SUITECRM_RUNTIME_MYSQL_USER` | Database username | Yes |
| `SUITECRM_RUNTIME_MYSQL_PASSWORD` | Database password | Yes |
| `SUITECRM_RUNTIME_MYSQL_SSL_ENABLED` | Enable SSL | No (default: true) |
| `SUITECRM_RUNTIME_MYSQL_SSL_VERIFY` | Verify SSL cert | No (default: true) |
| `SUITECRM_SITE_URL` | Public URL | Yes |
| `SUITECRM_ADMIN_USER` | Admin username | Yes (for setup) |
| `SUITECRM_ADMIN_PASSWORD` | Admin password | Yes (for setup) |
| `SUITECRM_LOG_LEVEL` | Logging verbosity | No (default: warning) |
| `SUITECRM_INSTALLER_LOCKED` | Lock installer | No (default: false) |
| `TZ` | Timezone | No (default: UTC) |
| `SKIP_DB_WAIT` | Skip DB connection wait | No (default: false) |

---

## 4. Azure Resource Provisioning

### 4.1 Resources Created

The `azure-provision.sh` script creates the following resources:

| Resource | Naming Convention | Purpose |
|----------|-------------------|---------|
| Resource Group | `rg-{prefix}-suitecrm` | Container for all resources |
| MySQL Flexible Server | `{prefix}-mysql` | Database server |
| MySQL Database | `suitecrm` | CRM database |
| Storage Account | `{prefix}storage` | File storage |
| File Shares | `suitecrm-upload`, `suitecrm-custom`, `suitecrm-cache` | Persistent files |
| Container Registry | `{prefix}acr` | Docker image repository |

### 4.2 Azure MySQL Configuration

**Server Settings:**
- SKU: `Standard_B1ms` (burstable, cost-effective for dev/small production)
- Storage: 32 GB (expandable)
- Version: MySQL 8.0 LTS
- SSL: Required (enforced by Azure)
- Backups: Automatic, 7-day retention

**Firewall Rules:**
- Development machine IP (for local testing)
- Azure services (0.0.0.0) for Container Apps access

### 4.3 Azure Storage Configuration

**Account Settings:**
- SKU: `Standard_LRS` (locally redundant)
- Kind: `StorageV2` (general purpose v2)
- Access tier: Hot

**File Shares:**
- Protocol: SMB 3.0
- Quota: 5 GB each (adjustable)
- Permissions: Read/Write

---

## 5. Mounted File Systems

### 5.1 Why Mounted File Systems?

Azure Container Apps are **ephemeral**. When a container restarts:
- All local file changes are lost
- Container starts fresh from the image
- Any uploaded files would disappear

To persist data, we mount Azure File shares into the container.

### 5.2 Mount Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Azure Storage Account                        │
│                         (buzzmagstorage)                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐   │
│  │ suitecrm-upload  │  │ suitecrm-custom  │  │ suitecrm-cache   │   │
│  │ (File Share)     │  │ (File Share)     │  │ (File Share)     │   │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘   │
│           │                     │                     │             │
└───────────┼─────────────────────┼─────────────────────┼─────────────┘
            │                     │                     │
            │ SMB Mount           │ SMB Mount           │ SMB Mount
            │                     │                     │
┌───────────┼─────────────────────┼─────────────────────┼─────────────┐
│           ▼                     ▼                     ▼             │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐   │
│  │ /var/www/html/   │  │ /var/www/html/   │  │ /var/www/html/   │   │
│  │ public/legacy/   │  │ public/legacy/   │  │ public/legacy/   │   │
│  │ upload/          │  │ custom/          │  │ cache/           │   │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘   │
│                                                                     │
│                     Docker Container (SuiteCRM)                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.3 Local Development Mount

For local development, we mount Azure Files to the local machine using SMB:

```
Azure Files (Cloud)
       │
       │ SMB 3.0 over Internet
       │ (Port 445, encrypted)
       ▼
┌─────────────────────────────────────┐
│     Local Linux Machine             │
│  /mnt/azure/suitecrm/               │
│  ├── upload/   (mounted share)      │
│  ├── custom/   (mounted share)      │
│  └── cache/    (mounted share)      │
└─────────────────────────────────────┘
       │
       │ Docker Volume Bind
       ▼
┌─────────────────────────────────────┐
│     Docker Container                │
│  /var/www/html/public/legacy/       │
│  ├── upload/   (from host mount)    │
│  ├── custom/   (from host mount)    │
│  └── cache/    (from host mount)    │
└─────────────────────────────────────┘
```

### 5.4 Azure Container Apps Mount

In production, Azure Container Apps mounts the shares directly:

```yaml
# Azure Container Apps YAML configuration
volumes:
  - name: upload-volume
    storageName: suitecrm-upload
    storageType: AzureFile
volumeMounts:
  - volumeName: upload-volume
    mountPath: /var/www/html/public/legacy/upload
```

No intermediate host mount needed - Container Apps handles it natively.

### 5.5 Mount Credentials

**Credentials file:** `/etc/azure-suitecrm-credentials`

```
username=buzzmagstorage
password=<storage_account_key>
```

**Security:**
- File permissions: `600` (owner read/write only)
- Owner: `root`
- Not committed to version control

### 5.6 fstab Entry (Persistent Mounts)

The `azure-mount.sh` script adds entries to `/etc/fstab` for automatic mounting:

```
//buzzmagstorage.file.core.windows.net/suitecrm-upload /mnt/azure/suitecrm/upload cifs credentials=/etc/azure-suitecrm-credentials,uid=33,gid=33,dir_mode=0775,file_mode=0775,serverino,nosharesock,actimeo=30 0 0
```

**Mount options explained:**
- `credentials=...` - Path to credentials file
- `uid=33,gid=33` - www-data user/group (Apache)
- `dir_mode=0775,file_mode=0775` - Permissions for web server
- `serverino` - Use server-provided inode numbers
- `nosharesock` - Don't share sockets (better for multiple mounts)
- `actimeo=30` - Attribute cache timeout (30 seconds)

---

## 6. Architecture Diagram

### Complete Azure Architecture

![TheBuzzMagazines SuiteCRM Azure Architecture](./docs/images/buzz_architecture.png)

*PlantUML source: [docs/puml/buzz_architecture.puml](./docs/puml/buzz_architecture.puml)*

### Rendered Diagram (ASCII Approximation)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Azure Resource Group: rg-buzzmag-suitecrm                │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │              Container Apps Environment: buzzmag-cae                    ││
│  │  ┌───────────────────────────────────────────────────────────────────┐  ││
│  │  │                   Container App: suitecrm                         │  ││
│  │  │  ┌─────────────┐   ┌─────────────┐   ┌─────────────────────────┐  │  ││
│  │  │  │   Apache    │──▶│   PHP 8.3   │──▶│   SuiteCRM 8.8.0        │  │  ││
│  │  │  │  Port 443   │   │             │   │                         │  │  ││
│  │  │  └─────────────┘   └─────────────┘   └───────────┬─────────────┘  │  ││
│  │  │                                                   │               │  ││
│  │  └───────────────────────────────────────────────────┼───────────────┘  ││
│  └──────────────────────────────────────────────────────┼──────────────────┘│
│                           │                             │                   │
│                           │ MySQL (SSL)                 │ Volume Mounts     │
│                           ▼                             ▼                   │
│  ┌─────────────────────────────────────┐  ┌────────────────────────────────┐│
│  │   Azure Database for MySQL          │  │    Azure Storage Account       ││
│  │   buzzmag-mysql                     │  │    buzzmagstorage              ││
│  │   ─────────────────────────────     │  │    ─────────────────────────── ││
│  │   • suitecrm database               │  │    • suitecrm-upload (share)   ││
│  │   • Standard_B1ms                   │  │    • suitecrm-custom (share)   ││
│  │   • SSL/TLS enforced                │  │    • suitecrm-cache (share)    ││
│  │   • Auto-backup enabled             │  │    • Standard LRS              ││
│  └─────────────────────────────────────┘  └────────────────────────────────┘│
│                                                                             │
│  ┌─────────────────────────────────────┐                                    │
│  │   Azure Container Registry          │                                    │
│  │   buzzmagacr.azurecr.io             │                                    │
│  │   ─────────────────────────────     │                                    │
│  │   • suitecrm:8.8.0 image            │                                    │
│  │   • Basic SKU                       │                                    │
│  └─────────────────────────────────────┘                                    │
└─────────────────────────────────────────────────────────────────────────────┘

         ▲                    ▲
         │ HTTPS              │ HTTPS
         │                    │
     ┌───┴───┐            ┌───┴───┐
     │ Users │            │ Admin │
     └───────┘            └───────┘
```

---

## 7. Step-by-Step Instructions

### 7.1 Local Environment Setup

#### Prerequisites

**Required Software:**

| Software | Version | Installation |
|----------|---------|--------------|
| Docker Desktop | 4.x+ | https://docker.com |
| Azure CLI | 2.x+ | `curl -sL https://aka.ms/InstallAzureCLIDeb \| sudo bash` |
| cifs-utils | Latest | `sudo apt install cifs-utils` |
| MySQL Client | 8.x | `sudo apt install mysql-client` |
| Git | 2.x+ | `sudo apt install git` |

**Verify installations:**

```bash
# Docker
docker --version
docker compose version

# Azure CLI
az --version

# cifs-utils
mount.cifs --version

# MySQL client
mysql --version
```

#### Clone Repository

```bash
cd ~/src
git clone <repository-url> TheBuzzMagazines
cd TheBuzzMagazines
```

#### Configure Environment

1. **Copy the example environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your values:**
   ```bash
   nano .env
   ```

3. **Required values to configure:**
   
   | Variable | How to Get |
   |----------|------------|
   | `AZURE_SUBSCRIPTION_ID` | Run: `az account show --query id -o tsv` |
   | `AZURE_LOCATION` | Choose: `eastus`, `westus2`, `southcentralus`, etc. |
   | `AZURE_RESOURCE_PREFIX` | Choose unique prefix (e.g., `buzzmag`) |
   | `SUITECRM_RUNTIME_MYSQL_PASSWORD` | Create strong password (8+ chars, mixed case, numbers) |
   | `SUITECRM_ADMIN_PASSWORD` | Create admin password |

4. **Validate the configuration:**
   ```bash
   ./scripts/validate-env.sh
   ```
   
   All items should show `✓` (green checkmark).

---

### 7.2 Azure Provisioning

#### Login to Azure

```bash
# Open browser for login
az login

# Verify subscription
az account show

# If wrong subscription, list and set correct one
az account list --output table
az account set --subscription "Your Subscription Name"
```

#### Run Provisioning Script

**Interactive mode (recommended for first run):**
```bash
./scripts/cli.sh provision
```

Or directly:
```bash
./scripts/azure-provision.sh
```

**Non-interactive mode (for automation):**
```bash
./scripts/cli.sh provision -y
```

#### What the Script Does (Step by Step)

1. **Validates environment** - Checks `.env` file
2. **Validates prerequisites** - Checks Azure CLI login
3. **Sets subscription** - Configures `az` to use your subscription
4. **Creates resource group** - `rg-{prefix}-suitecrm`
5. **Creates MySQL server** - Takes 5-10 minutes
6. **Creates database** - `suitecrm` database
7. **Adds firewall rules** - Your IP + Azure services
8. **Creates storage account** - For file shares
9. **Creates file shares** - upload, custom, cache
10. **Creates container registry** - For Docker images

#### Verify Resources in Azure Portal

1. Go to https://portal.azure.com
2. Navigate to **Resource groups**
3. Select `rg-{prefix}-suitecrm`
4. Verify all resources are present:
   - MySQL server
   - Storage account
   - Container registry

#### Check Provisioning Log

```bash
./scripts/cli.sh show-log-provision
```

Or:
```bash
cat logs/latest_azure-provision_*.log
```

---

### 7.3 Local Azure Files Mounting

#### Prerequisites

Ensure `cifs-utils` is installed:
```bash
sudo apt install cifs-utils
```

#### Run Mount Script

**Interactive mode:**
```bash
sudo ./scripts/cli.sh mount
```

Or directly:
```bash
sudo ./scripts/azure-mount.sh
```

**Non-interactive mode:**
```bash
sudo ./scripts/cli.sh mount -y
```

#### What the Script Does

1. **Validates environment** - Checks `.env` file
2. **Retrieves storage key** - From Azure or `.azure-secrets`
3. **Creates credentials file** - `/etc/azure-suitecrm-credentials`
4. **Creates mount directories** - `/mnt/azure/suitecrm/{upload,custom,cache}`
5. **Mounts shares** - Using SMB 3.0
6. **Updates fstab** - For persistent mounts

#### Verify Mounts

```bash
# Check mount status
mount | grep suitecrm

# Expected output:
# //buzzmagstorage.file.core.windows.net/suitecrm-upload on /mnt/azure/suitecrm/upload type cifs ...
# //buzzmagstorage.file.core.windows.net/suitecrm-custom on /mnt/azure/suitecrm/custom type cifs ...
# //buzzmagstorage.file.core.windows.net/suitecrm-cache on /mnt/azure/suitecrm/cache type cifs ...

# Test write access
touch /mnt/azure/suitecrm/upload/test.txt
ls -la /mnt/azure/suitecrm/upload/
rm /mnt/azure/suitecrm/upload/test.txt
```

#### Troubleshooting Mounts

**Error: "mount error(13): Permission denied"**
- Check storage key is correct in `.azure-secrets`
- Verify storage account firewall allows your IP

**Error: "mount error(2): No such file or directory"**
- Create mount directories: `sudo mkdir -p /mnt/azure/suitecrm/{upload,custom,cache}`

**Error: "Connection timed out"**
- Port 445 may be blocked by your ISP
- Try from a different network or use VPN

---

### 7.4 Docker Image Creation

#### Build the Image

```bash
# Navigate to project root
cd ~/src/TheBuzzMagazines

# Build the image
docker build -t suitecrm:8.8.0 .

# Build with no cache (if you need a fresh build)
docker build --no-cache -t suitecrm:8.8.0 .
```

#### Verify Build

```bash
# List images
docker images | grep suitecrm

# Expected output:
# suitecrm    8.8.0    abc123def456    2 minutes ago    1.2GB
```

#### Run Locally with Docker Compose

```bash
# Start the container
docker compose up -d

# View logs
docker compose logs -f

# Check container status
docker compose ps
```

#### Access SuiteCRM

1. Open browser: http://localhost
2. If first run, SuiteCRM installer will appear
3. Complete installation wizard (database credentials from `.env`)

#### Stop Container

```bash
docker compose down
```

---

### 7.5 Data Migration

Data migration from the legacy Advertisers MySQL database to SuiteCRM is covered in a separate document:

**See:** `docs/DATA_MIGRATION_GUIDE.md` (to be created)

**High-level process:**

1. **Backup source database:**
   ```bash
   ./scripts/cli.sh backup-db-source pre_migration
   ```

2. **Run migration scripts** (to be developed):
   - Map Advertisers → Accounts
   - Map AdvContacts → Contacts
   - Map Comments → Notes/Calls
   - Map Account Executives → Users

3. **Verify migrated data** in SuiteCRM

4. **Lock installer:**
   ```bash
   # Update .env
   SUITECRM_INSTALLER_LOCKED=true
   ```

---

### 7.6 Azure Deployment (Complete Walkthrough)

This section provides exhaustive, click-by-click instructions for deploying to Azure Container Apps.

#### Step 1: Tag and Push Docker Image to ACR

**1.1 Login to Azure Container Registry:**

```bash
# Get ACR login credentials
az acr login --name buzzmagacr
```

**Expected output:**
```
Login Succeeded
```

**1.2 Tag the image for ACR:**

```bash
docker tag suitecrm:8.8.0 buzzmagacr.azurecr.io/suitecrm:8.8.0
```

**1.3 Push the image:**

```bash
docker push buzzmagacr.azurecr.io/suitecrm:8.8.0
```

**Expected output:**
```
The push refers to repository [buzzmagacr.azurecr.io/suitecrm]
abc123: Pushed
def456: Pushed
...
8.8.0: digest: sha256:... size: 3456
```

**1.4 Verify image in ACR:**

```bash
az acr repository list --name buzzmagacr --output table
az acr repository show-tags --name buzzmagacr --repository suitecrm --output table
```

#### Step 2: Create Container Apps Environment

**2.1 Create the environment:**

```bash
az containerapp env create \
  --name buzzmag-cae \
  --resource-group rg-buzzmag-suitecrm \
  --location southcentralus
```

**Expected duration:** 2-5 minutes

**2.2 Verify environment:**

```bash
az containerapp env show \
  --name buzzmag-cae \
  --resource-group rg-buzzmag-suitecrm \
  --query "properties.provisioningState"
```

**Expected output:**
```
"Succeeded"
```

#### Step 3: Add Storage Mounts to Environment

**3.1 Get storage account key:**

```bash
STORAGE_KEY=$(az storage account keys list \
  --resource-group rg-buzzmag-suitecrm \
  --account-name buzzmagstorage \
  --query '[0].value' -o tsv)

echo "Storage key retrieved: ${STORAGE_KEY:0:10}..."
```

**3.2 Add upload storage:**

```bash
az containerapp env storage set \
  --name buzzmag-cae \
  --resource-group rg-buzzmag-suitecrm \
  --storage-name suitecrm-upload \
  --azure-file-account-name buzzmagstorage \
  --azure-file-account-key "$STORAGE_KEY" \
  --azure-file-share-name suitecrm-upload \
  --access-mode ReadWrite
```

**3.3 Add custom storage:**

```bash
az containerapp env storage set \
  --name buzzmag-cae \
  --resource-group rg-buzzmag-suitecrm \
  --storage-name suitecrm-custom \
  --azure-file-account-name buzzmagstorage \
  --azure-file-account-key "$STORAGE_KEY" \
  --azure-file-share-name suitecrm-custom \
  --access-mode ReadWrite
```

**3.4 Add cache storage:**

```bash
az containerapp env storage set \
  --name buzzmag-cae \
  --resource-group rg-buzzmag-suitecrm \
  --storage-name suitecrm-cache \
  --azure-file-account-name buzzmagstorage \
  --azure-file-account-key "$STORAGE_KEY" \
  --azure-file-share-name suitecrm-cache \
  --access-mode ReadWrite
```

**3.5 Verify storage mounts:**

```bash
az containerapp env storage list \
  --name buzzmag-cae \
  --resource-group rg-buzzmag-suitecrm \
  --output table
```

**Expected output:**
```
Name              AzureFileAccountName    AzureFileShareName    AccessMode
----------------  ----------------------  --------------------  ------------
suitecrm-upload   buzzmagstorage          suitecrm-upload       ReadWrite
suitecrm-custom   buzzmagstorage          suitecrm-custom       ReadWrite
suitecrm-cache    buzzmagstorage          suitecrm-cache        ReadWrite
```

#### Step 4: Get ACR Credentials

```bash
ACR_USERNAME=$(az acr credential show \
  --name buzzmagacr \
  --query username -o tsv)

ACR_PASSWORD=$(az acr credential show \
  --name buzzmagacr \
  --query "passwords[0].value" -o tsv)

echo "ACR Username: $ACR_USERNAME"
echo "ACR Password: ${ACR_PASSWORD:0:10}..."
```

#### Step 5: Create Container App

**5.1 Get database password from .env:**

```bash
source .env
echo "Database password ready: ${SUITECRM_RUNTIME_MYSQL_PASSWORD:0:3}..."
```

**5.2 Create the container app:**

```bash
az containerapp create \
  --name suitecrm \
  --resource-group rg-buzzmag-suitecrm \
  --environment buzzmag-cae \
  --image buzzmagacr.azurecr.io/suitecrm:8.8.0 \
  --registry-server buzzmagacr.azurecr.io \
  --registry-username "$ACR_USERNAME" \
  --registry-password "$ACR_PASSWORD" \
  --target-port 80 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 1 \
  --memory 2Gi \
  --env-vars \
    SUITECRM_RUNTIME_MYSQL_HOST=buzzmag-mysql.mysql.database.azure.com \
    SUITECRM_RUNTIME_MYSQL_PORT=3306 \
    SUITECRM_RUNTIME_MYSQL_NAME=suitecrm \
    SUITECRM_RUNTIME_MYSQL_USER=suitecrm \
    SUITECRM_RUNTIME_MYSQL_SSL_ENABLED=true \
    SUITECRM_RUNTIME_MYSQL_SSL_VERIFY=true \
    SUITECRM_SITE_URL=https://suitecrm.azurecontainerapps.io \
    SUITECRM_LOG_LEVEL=warning \
    SUITECRM_INSTALLER_LOCKED=false \
    TZ=America/Chicago \
  --secrets \
    db-password="$SUITECRM_RUNTIME_MYSQL_PASSWORD" \
  --env-vars \
    SUITECRM_RUNTIME_MYSQL_PASSWORD=secretref:db-password
```

**Expected duration:** 2-3 minutes

#### Step 6: Add Volume Mounts

Container Apps doesn't support volume mounts in the `create` command. Use YAML update:

**6.1 Create YAML file:**

Create file `containerapp-update.yaml`:

```yaml
properties:
  template:
    containers:
      - name: suitecrm
        image: buzzmagacr.azurecr.io/suitecrm:8.8.0
        resources:
          cpu: 1
          memory: 2Gi
        volumeMounts:
          - volumeName: upload-volume
            mountPath: /var/www/html/public/legacy/upload
          - volumeName: custom-volume
            mountPath: /var/www/html/public/legacy/custom
          - volumeName: cache-volume
            mountPath: /var/www/html/public/legacy/cache
    volumes:
      - name: upload-volume
        storageName: suitecrm-upload
        storageType: AzureFile
      - name: custom-volume
        storageName: suitecrm-custom
        storageType: AzureFile
      - name: cache-volume
        storageName: suitecrm-cache
        storageType: AzureFile
```

**6.2 Apply the update:**

```bash
az containerapp update \
  --name suitecrm \
  --resource-group rg-buzzmag-suitecrm \
  --yaml containerapp-update.yaml
```

#### Step 7: Get Application URL

```bash
APP_URL=$(az containerapp show \
  --name suitecrm \
  --resource-group rg-buzzmag-suitecrm \
  --query "properties.configuration.ingress.fqdn" -o tsv)

echo "SuiteCRM URL: https://$APP_URL"
```

**Expected output:**
```
SuiteCRM URL: https://suitecrm.livelyrock-abc123.southcentralus.azurecontainerapps.io
```

#### Step 8: Update SUITECRM_SITE_URL

The Container App URL is now known. Update the environment variable:

```bash
az containerapp update \
  --name suitecrm \
  --resource-group rg-buzzmag-suitecrm \
  --set-env-vars "SUITECRM_SITE_URL=https://$APP_URL"
```

#### Step 9: Verify Deployment

**9.1 Check container status:**

```bash
az containerapp show \
  --name suitecrm \
  --resource-group rg-buzzmag-suitecrm \
  --query "properties.runningStatus"
```

**Expected output:**
```
"Running"
```

**9.2 View container logs:**

```bash
az containerapp logs show \
  --name suitecrm \
  --resource-group rg-buzzmag-suitecrm \
  --follow
```

**9.3 Access the application:**

Open browser to the URL from Step 7.

#### Step 10: Complete SuiteCRM Installation

1. Navigate to `https://<your-app-url>`
2. SuiteCRM installer wizard appears
3. Fill in:
   - **Database Host:** `buzzmag-mysql.mysql.database.azure.com`
   - **Database Name:** `suitecrm`
   - **Database User:** `suitecrm`
   - **Database Password:** (from .env)
   - **Site URL:** (auto-detected)
   - **Admin User:** (from .env)
   - **Admin Password:** (from .env)
4. Click **Install**
5. Wait for installation to complete

#### Step 11: Lock Installer (IMPORTANT!)

After installation, lock the installer to prevent re-installation:

```bash
az containerapp update \
  --name suitecrm \
  --resource-group rg-buzzmag-suitecrm \
  --set-env-vars "SUITECRM_INSTALLER_LOCKED=true"
```

#### Step 12: Configure Custom Domain (Optional)

**12.1 Add custom domain:**

```bash
az containerapp hostname add \
  --name suitecrm \
  --resource-group rg-buzzmag-suitecrm \
  --hostname crm.yourdomain.com
```

**12.2 Get validation token:**

```bash
az containerapp hostname list \
  --name suitecrm \
  --resource-group rg-buzzmag-suitecrm
```

**12.3 Add DNS records:**

In your DNS provider, add:
- CNAME: `crm` → `<app-url>.azurecontainerapps.io`
- TXT: `asuid.crm` → `<validation-token>`

**12.4 Enable managed certificate:**

```bash
az containerapp hostname bind \
  --name suitecrm \
  --resource-group rg-buzzmag-suitecrm \
  --hostname crm.yourdomain.com \
  --environment buzzmag-cae \
  --validation-method CNAME
```

**12.5 Update site URL:**

```bash
az containerapp update \
  --name suitecrm \
  --resource-group rg-buzzmag-suitecrm \
  --set-env-vars "SUITECRM_SITE_URL=https://crm.yourdomain.com"
```

---

## Appendix A: Troubleshooting

### Container Won't Start

**Check logs:**
```bash
az containerapp logs show \
  --name suitecrm \
  --resource-group rg-buzzmag-suitecrm \
  --tail 100
```

**Common issues:**
- Database connection failed → Check MySQL firewall rules
- Permission denied on volumes → Check storage mount configuration
- PHP errors → Check environment variables

### Database Connection Errors

**Test from container:**
```bash
az containerapp exec \
  --name suitecrm \
  --resource-group rg-buzzmag-suitecrm \
  --command "php -r \"new mysqli('buzzmag-mysql.mysql.database.azure.com', 'suitecrm', 'password', 'suitecrm', 3306);\""
```

**Check firewall:**
```bash
az mysql flexible-server firewall-rule list \
  --resource-group rg-buzzmag-suitecrm \
  --name buzzmag-mysql \
  --output table
```

### Volume Mount Issues

**Check storage configuration:**
```bash
az containerapp env storage list \
  --name buzzmag-cae \
  --resource-group rg-buzzmag-suitecrm \
  --output table
```

**Verify file share exists:**
```bash
az storage share list \
  --account-name buzzmagstorage \
  --output table
```

---

## Appendix B: Cost Estimation

| Resource | SKU | Estimated Monthly Cost |
|----------|-----|------------------------|
| Container Apps | Consumption | $0-50 (pay per use) |
| MySQL Flexible Server | Standard_B1ms | ~$25-30 |
| Storage Account | Standard LRS | ~$2-5 |
| Container Registry | Basic | ~$5 |
| **Total** | | **~$35-90/month** |

*Costs vary by region and usage.*

---

## Appendix C: Security Checklist

- [ ] Strong passwords for MySQL and SuiteCRM admin
- [ ] MySQL SSL enforced
- [ ] Installer locked after setup
- [ ] HTTPS only (no HTTP)
- [ ] Custom domain with managed certificate
- [ ] Azure Key Vault for secrets (production)
- [ ] Private endpoints for MySQL/Storage (production)
- [ ] Regular backups verified
- [ ] Access logs enabled

---

## Appendix D: Maintenance Tasks

### Update SuiteCRM Version

1. Update `SUITECRM_VERSION` in Dockerfile
2. Rebuild image: `docker build -t suitecrm:X.X.X .`
3. Push to ACR
4. Update Container App image

### Scale Resources

**MySQL:**
```bash
az mysql flexible-server update \
  --resource-group rg-buzzmag-suitecrm \
  --name buzzmag-mysql \
  --sku-name Standard_D2ds_v4
```

**Container Apps:**
```bash
az containerapp update \
  --name suitecrm \
  --resource-group rg-buzzmag-suitecrm \
  --cpu 2 \
  --memory 4Gi \
  --max-replicas 5
```

### Backup Database

**Manual backup:**
```bash
az mysql flexible-server backup create \
  --resource-group rg-buzzmag-suitecrm \
  --name buzzmag-mysql \
  --backup-name manual-backup-$(date +%Y%m%d)
```

**Export data:**
```bash
mysqldump -h buzzmag-mysql.mysql.database.azure.com \
  -u suitecrm -p \
  --ssl-mode=REQUIRED \
  suitecrm > backup.sql
```

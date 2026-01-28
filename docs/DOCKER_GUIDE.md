# Docker Build & Deployment Guide

## Complete Reference for .env-Driven Docker Configuration

**Purpose:** Comprehensive guide for building SuiteCRM 8.x Docker images with full configuration driven from `.env` using template generation.

**Last Updated:** January 2026

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Configuration Philosophy](#2-configuration-philosophy)
3. [Template Generation System](#3-template-generation-system)
4. [Environment Variables Reference](#4-environment-variables-reference)
5. [Local Development Workflow](#5-local-development-workflow)
6. [Docker Image Build](#6-docker-image-build)
7. [Push to Azure Container Registry](#7-push-to-azure-container-registry)
8. [Azure Container Apps Deployment](#8-azure-container-apps-deployment)
9. [Post-Deployment & Testing](#9-post-deployment--testing)
10. [Script Reference](#10-script-reference)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Architecture Overview

### 1.1 Design Principles

The Docker configuration follows these core principles:

| Principle | Implementation |
|-----------|----------------|
| **Single Source of Truth** | All configuration lives in `.env` |
| **Template Generation** | Dockerfile and docker-compose.yml are generated from templates |
| **Runtime Configuration** | Application settings injected at container startup |
| **Immutable Images** | Build-time values baked in, runtime values passed as env vars |

### 1.2 Configuration Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         .env (Single Source of Truth)                   │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────┐  │
│  │ DOCKER_* variables  │  │ SUITECRM_* vars     │  │ AZURE_* vars    │  │
│  │ Build-time config   │  │ Runtime config      │  │ Infrastructure  │  │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
         ┌──────────────────┐ ┌──────────────┐ ┌──────────────────┐
         │ docker-generate  │ │ docker-start │ │ azure-provision  │
         │ ──────────────── │ │ ──────────── │ │ ──────────────── │
         │ Generates:       │ │ Passes env   │ │ Creates Azure    │
         │ • Dockerfile     │ │ vars to      │ │ resources        │
         │ • docker-compose │ │ container    │ │                  │
         └──────────────────┘ └──────────────┘ └──────────────────┘
                    │               │
                    ▼               ▼
         ┌──────────────────┐ ┌──────────────────────────────────────┐
         │ docker build     │ │ docker-entrypoint.sh (runtime)       │
         │ ──────────────── │ │ ────────────────────────────────────  │
         │ Creates image    │ │ • Reads SUITECRM_RUNTIME_MYSQL_*     │
         │ with baked-in    │ │ • Generates config_override.php      │
         │ PHP settings     │ │ • Generates legacy/.env              │
         └──────────────────┘ │ • Sets permissions                   │
                              │ • Waits for database                 │
                              │ • Starts Apache                      │
                              └──────────────────────────────────────┘
```

### 1.3 Template Generation Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Source Files (Committed to Git)                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  .env                      Dockerfile.template       docker-compose.    │
│  ────                      ───────────────────       template.yml       │
│  DOCKER_PHP_BASE_IMAGE=    FROM ${DOCKER_PHP_...}    container_name:    │
│  DOCKER_SUITECRM_VERSION=  ENV SUITECRM_VERSION=     ${DOCKER_CONTAI... │
│  DOCKER_PHP_MEMORY_LIMIT=  memory_limit = ${...}     ports: ${...}      │
│  ...                       ...                       ...                │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │  docker-generate.sh
                                    │  (runs envsubst)
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       Generated Files (Git-ignored)                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Dockerfile                           docker-compose.yml                │
│  ──────────                           ──────────────────                │
│  FROM php:8.3-apache                  container_name: suitecrm-web      │
│  ENV SUITECRM_VERSION=8.8.0           ports: "80:80"                    │
│  memory_limit = 512M                  ...                               │
│  ...                                                                    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │  docker build
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                            Docker Image                                 │
├─────────────────────────────────────────────────────────────────────────┤
│  suitecrm:8.8.0                                                         │
│  • PHP 8.3 + Apache                                                     │
│  • All extensions installed                                             │
│  • SuiteCRM 8.8.0 source code                                           │
│  • PHP settings baked in (memory, uploads, opcache)                     │
│  • docker-entrypoint.sh for runtime config                              │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Configuration Philosophy

### 2.1 Build-Time vs. Runtime Configuration

| Type | When Applied | Where Defined | Examples |
|------|--------------|---------------|----------|
| **Build-Time** | During `docker build` | `DOCKER_*` variables | PHP version, memory limits, SuiteCRM version |
| **Runtime** | During container startup | `SUITECRM_*` variables | Database connection, site URL, admin credentials |

### 2.2 Why Template Generation?

| Approach | Pros | Cons |
|----------|------|------|
| **Hardcoded Dockerfile** | Simple, no generation step | Change requires editing file |
| **Docker ARG** | Docker-native | Limited to certain instructions, verbose |
| **Template Generation** | Full flexibility, any value anywhere | Requires generation step |

**We use Template Generation because:**
- Complete flexibility - any value can be parameterized
- Single source of truth - all config in `.env`
- No limitations on what can be substituted
- Clean separation of structure (template) from values (.env)

### 2.3 File Responsibilities

| File | Purpose | Committed? |
|------|---------|------------|
| `.env` | All configuration values | No (`.env.example` is) |
| `Dockerfile.template` | Docker build structure with placeholders | Yes |
| `docker-compose.template.yml` | Compose structure with placeholders | Yes |
| `Dockerfile` | Generated, ready-to-build | No (git-ignored) |
| `docker-compose.yml` | Generated, ready-to-run | No (git-ignored) |
| `docker-entrypoint.sh` | Runtime configuration script | Yes |

---

## 3. Template Generation System

### 3.1 How It Works

The `docker-generate.sh` script:
1. Loads all variables from `.env`
2. Exports them for `envsubst`
3. Processes `Dockerfile.template` → `Dockerfile`
4. Processes `docker-compose.template.yml` → `docker-compose.yml`

### 3.2 Template Syntax

Templates use standard shell variable syntax: `${VARIABLE_NAME}`

**Example from Dockerfile.template:**
```dockerfile
FROM --platform=${DOCKER_PLATFORM} ${DOCKER_PHP_BASE_IMAGE}

LABEL maintainer="${DOCKER_LABEL_MAINTAINER}"
LABEL description="${DOCKER_LABEL_DESCRIPTION}"

ENV SUITECRM_VERSION=${DOCKER_SUITECRM_VERSION}

RUN { \
    echo 'memory_limit = ${DOCKER_PHP_MEMORY_LIMIT}'; \
    echo 'upload_max_filesize = ${DOCKER_PHP_UPLOAD_MAX_FILESIZE}'; \
    echo 'post_max_size = ${DOCKER_PHP_POST_MAX_SIZE}'; \
    } > "$PHP_INI_DIR/conf.d/suitecrm.ini"

EXPOSE ${DOCKER_CONTAINER_PORT}
```

**Example from docker-compose.template.yml:**
```yaml
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile
    platform: ${DOCKER_PLATFORM}
    container_name: ${DOCKER_CONTAINER_NAME}
    ports:
      - "${DOCKER_HOST_PORT}:${DOCKER_CONTAINER_PORT}"
    healthcheck:
      interval: ${DOCKER_HEALTHCHECK_INTERVAL}
      timeout: ${DOCKER_HEALTHCHECK_TIMEOUT}
      retries: ${DOCKER_HEALTHCHECK_RETRIES}
```

### 3.3 Generation Script

```bash
# Generate Docker files from templates
./scripts/cli.sh docker-generate

# Or run directly
./scripts/docker-generate.sh
```

**What happens:**
```
$ ./scripts/docker-generate.sh
[INFO] Loading environment from .env...
[INFO] Exporting 47 variables for template substitution...
[STEP] Generating Dockerfile from template...
[SUCCESS] Created Dockerfile (SuiteCRM 8.8.0, PHP 8.3)
[STEP] Generating docker-compose.yml from template...
[SUCCESS] Created docker-compose.yml (container: suitecrm-web)
[SUCCESS] Docker files generated successfully
```

---

## 4. Environment Variables Reference

### 4.1 Docker Build Configuration

These variables control the Docker image build process.

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCKER_PHP_BASE_IMAGE` | `php:8.3-apache` | Base PHP image |
| `DOCKER_SUITECRM_VERSION` | `8.8.0` | SuiteCRM version to install |
| `DOCKER_PLATFORM` | `linux/amd64` | Target platform |
| `DOCKER_IMAGE_NAME` | `suitecrm` | Image name |
| `DOCKER_IMAGE_TAG` | `latest` | Image tag |
| `DOCKER_CONTAINER_NAME` | `suitecrm-web` | Container name |
| `DOCKER_NETWORK_NAME` | `suitecrm-network` | Docker network name |

### 4.2 Docker Labels

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCKER_LABEL_MAINTAINER` | `TheBuzzMagazines DevOps` | Image maintainer |
| `DOCKER_LABEL_DESCRIPTION` | `SuiteCRM Cloud-Native...` | Image description |

### 4.3 PHP Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCKER_PHP_MEMORY_LIMIT` | `512M` | PHP memory limit |
| `DOCKER_PHP_UPLOAD_MAX_FILESIZE` | `100M` | Max upload file size |
| `DOCKER_PHP_POST_MAX_SIZE` | `100M` | Max POST data size |
| `DOCKER_PHP_MAX_EXECUTION_TIME` | `300` | Script timeout (seconds) |
| `DOCKER_PHP_MAX_INPUT_TIME` | `300` | Input parsing timeout |
| `DOCKER_PHP_MAX_INPUT_VARS` | `10000` | Max input variables |

### 4.4 OPcache Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCKER_OPCACHE_MEMORY` | `256` | OPcache memory (MB) |
| `DOCKER_OPCACHE_INTERNED_STRINGS` | `16` | Interned strings buffer (MB) |
| `DOCKER_OPCACHE_MAX_FILES` | `10000` | Max cached files |

### 4.5 Networking

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCKER_HOST_PORT` | `80` | Host port to expose |
| `DOCKER_CONTAINER_PORT` | `80` | Container port |

### 4.6 Health Check

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCKER_HEALTHCHECK_INTERVAL` | `30s` | Check interval |
| `DOCKER_HEALTHCHECK_TIMEOUT` | `10s` | Check timeout |
| `DOCKER_HEALTHCHECK_RETRIES` | `3` | Retries before unhealthy |
| `DOCKER_HEALTHCHECK_START_PERIOD` | `60s` | Initial startup grace period |

### 4.7 Runtime Configuration (SUITECRM_*)

These are passed to the container at runtime, not baked into the image.

| Variable | Required | Description |
|----------|----------|-------------|
| `SUITECRM_RUNTIME_MYSQL_HOST` | Yes | Database server hostname |
| `SUITECRM_RUNTIME_MYSQL_PORT` | No | Database port (default: 3306) |
| `SUITECRM_RUNTIME_MYSQL_NAME` | Yes | Database name |
| `SUITECRM_RUNTIME_MYSQL_USER` | Yes | Database username |
| `SUITECRM_RUNTIME_MYSQL_PASSWORD` | Yes | Database password |
| `SUITECRM_RUNTIME_MYSQL_SSL_ENABLED` | No | Enable SSL (default: true) |
| `SUITECRM_RUNTIME_MYSQL_SSL_VERIFY` | No | Verify SSL cert (default: true) |
| `SUITECRM_SITE_URL` | Yes | Public URL of the application |
| `SUITECRM_ADMIN_USER` | No | Initial admin username |
| `SUITECRM_ADMIN_PASSWORD` | No | Initial admin password |
| `SUITECRM_LOG_LEVEL` | No | Log verbosity (default: warning) |
| `SUITECRM_INSTALLER_LOCKED` | No | Lock installer (default: false) |
| `TZ` | No | Timezone (default: UTC) |

---

## 5. Local Development Workflow

### 5.1 Workflow Order

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ docker-generate │     │   docker-build  │     │   azure-mount   │
│ ─────────────── │────▶│  ─────────────  │────▶│  ─────────────  │
│ Creates         │     │  Builds image   │     │  Mounts Azure   │
│ Dockerfile &    │     │  from template  │     │  Files locally  │
│ compose.yml     │     │                 │     │  (requires sudo)│
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                                                        ▼
                        ┌─────────────────┐     ┌─────────────────┐
                        │ docker-validate │◀────│  docker-start   │
                        │ ─────────────── │     │  ─────────────  │
                        │ Check all       │     │  Starts         │
                        │ components      │     │  container      │
                        └─────────────────┘     └─────────────────┘
```

### 5.2 Step-by-Step

```bash
# Step 1: Configure environment
cp .env.example .env
# Edit .env with your settings

# Step 2: Generate Docker files from templates
./scripts/cli.sh docker-generate

# Step 3: Build the Docker image
./scripts/cli.sh docker-build

# Step 4: Mount Azure Files (requires Azure resources provisioned)
sudo ./scripts/cli.sh azure-mount

# Step 5: Start the container
./scripts/cli.sh docker-start

# Step 6: Validate everything is running
./scripts/cli.sh docker-validate

# Step 7: Access SuiteCRM
open http://localhost
```

### 5.3 Mount Timing (Critical)

| Step | Script | Mount Required? | Notes |
|------|--------|-----------------|-------|
| 1 | `docker-generate` | No | Just generates files |
| 2 | `docker-build` | No | Just builds the image |
| 3 | `azure-mount` | N/A | Creates the mount points |
| 4 | `docker-start` | **Yes** | Warns if mounts missing |
| 5 | `docker-validate` | No | Reports mount state |
| 6 | `docker-stop` | No | Just stops container |

**Why mounts matter:** The generated `docker-compose.yml` maps Azure Files to container paths:

```yaml
volumes:
  - ${AZURE_FILES_MOUNT_BASE}/upload:/var/www/html/public/legacy/upload
  - ${AZURE_FILES_MOUNT_BASE}/custom:/var/www/html/public/legacy/custom
  - ${AZURE_FILES_MOUNT_BASE}/cache:/var/www/html/public/legacy/cache
```

Without mounts, Docker creates empty local directories and **data will not persist** to Azure storage.

---

## 6. Docker Image Build

### 6.1 Build Process

```bash
# Generate + Build in one step
./scripts/cli.sh docker-build

# With no-cache option
./scripts/cli.sh docker-build --no-cache
```

**What happens:**
1. Runs `docker-generate.sh` to create Dockerfile
2. Validates Docker daemon is running
3. Runs `docker compose build`
4. Tags image with version and `latest`

### 6.2 Manual Build

```bash
# Generate files first
./scripts/docker-generate.sh

# Build with docker compose
docker compose build

# Or build directly with docker
docker build \
  --platform linux/amd64 \
  -t suitecrm:8.8.0 \
  -t suitecrm:latest \
  .
```

### 6.3 Build Output

```
$ ./scripts/cli.sh docker-build
[INFO] Docker Build Script
[STEP] Generating Docker files from templates...
[SUCCESS] Dockerfile generated (SuiteCRM 8.8.0)
[SUCCESS] docker-compose.yml generated
[STEP] Building Docker image...
 => [internal] load build definition from Dockerfile
 => [1/12] FROM php:8.3-apache
 => [2/12] RUN apt-get update && apt-get install -y ...
 ...
 => [12/12] CMD ["apache2-foreground"]
 => exporting to image
[SUCCESS] Image built: suitecrm:8.8.0
[INFO] Build time: 3m 42s
[INFO] Image size: 1.2GB
```

---

## 7. Push to Azure Container Registry

### 7.1 Prerequisites

- Azure Container Registry created (via `azure-provision-infra.sh`)
- Azure CLI logged in (`az login`)
- Admin access enabled on ACR

### 7.2 Push Process

```bash
# Login to ACR
az acr login --name ${AZURE_ACR_NAME}

# Tag for ACR
docker tag suitecrm:8.8.0 ${AZURE_ACR_NAME}.azurecr.io/suitecrm:8.8.0
docker tag suitecrm:latest ${AZURE_ACR_NAME}.azurecr.io/suitecrm:latest

# Push
docker push ${AZURE_ACR_NAME}.azurecr.io/suitecrm:8.8.0
docker push ${AZURE_ACR_NAME}.azurecr.io/suitecrm:latest
```

### 7.3 Verify Push

```bash
# List repositories
az acr repository list --name ${AZURE_ACR_NAME} --output table

# Show tags
az acr repository show-tags --name ${AZURE_ACR_NAME} --repository suitecrm --output table
```

---

## 8. Azure Container Apps Deployment

### 8.1 Environment Setup

```bash
# Create Container Apps Environment
az containerapp env create \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --name ${AZURE_CONTAINER_APP_ENV} \
  --location ${AZURE_LOCATION}
```

### 8.2 Configure Storage Mounts

```bash
# Get storage key
STORAGE_KEY=$(az storage account keys list \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --account-name ${AZURE_STORAGE_ACCOUNT_NAME} \
  --query '[0].value' -o tsv)

# Add storage mounts to environment
for share in upload custom cache; do
  az containerapp env storage set \
    --resource-group ${AZURE_RESOURCE_GROUP} \
    --name ${AZURE_CONTAINER_APP_ENV} \
    --storage-name suitecrm-${share} \
    --azure-file-account-name ${AZURE_STORAGE_ACCOUNT_NAME} \
    --azure-file-account-key "$STORAGE_KEY" \
    --azure-file-share-name suitecrm-${share} \
    --access-mode ReadWrite
done
```

### 8.3 Deploy Container App

```bash
# Get ACR credentials
ACR_USERNAME=$(az acr credential show --name ${AZURE_ACR_NAME} --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name ${AZURE_ACR_NAME} --query passwords[0].value -o tsv)

# Create container app
az containerapp create \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --name ${AZURE_CONTAINER_APP_NAME} \
  --environment ${AZURE_CONTAINER_APP_ENV} \
  --image ${AZURE_ACR_NAME}.azurecr.io/suitecrm:8.8.0 \
  --registry-server ${AZURE_ACR_NAME}.azurecr.io \
  --registry-username "$ACR_USERNAME" \
  --registry-password "$ACR_PASSWORD" \
  --target-port 80 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 1 \
  --memory 2Gi \
  --env-vars \
    SUITECRM_RUNTIME_MYSQL_HOST=${SUITECRM_RUNTIME_MYSQL_HOST} \
    SUITECRM_RUNTIME_MYSQL_PORT=${SUITECRM_RUNTIME_MYSQL_PORT} \
    SUITECRM_RUNTIME_MYSQL_NAME=${SUITECRM_RUNTIME_MYSQL_NAME} \
    SUITECRM_RUNTIME_MYSQL_USER=${SUITECRM_RUNTIME_MYSQL_USER} \
    SUITECRM_SITE_URL=https://${AZURE_CONTAINER_APP_NAME}.azurecontainerapps.io \
    TZ=${TZ:-America/Chicago}
```

### 8.4 Volume Mounts (YAML Required)

Create `aca-suitecrm.yaml`:

```yaml
properties:
  template:
    containers:
      - name: suitecrm
        image: ${AZURE_ACR_NAME}.azurecr.io/suitecrm:8.8.0
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

Apply:
```bash
az containerapp update \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --name ${AZURE_CONTAINER_APP_NAME} \
  --yaml aca-suitecrm.yaml
```

---

## 9. Post-Deployment & Testing

### 9.1 Get Application URL

```bash
az containerapp show \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --name ${AZURE_CONTAINER_APP_NAME} \
  --query properties.configuration.ingress.fqdn -o tsv
```

### 9.2 Health Checks

```bash
# Container status
az containerapp show \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --name ${AZURE_CONTAINER_APP_NAME} \
  --query properties.runningStatus

# Container logs
az containerapp logs show \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --name ${AZURE_CONTAINER_APP_NAME} \
  --follow

# HTTP check
curl -I https://${APP_URL}/
```

### 9.3 SuiteCRM First-Time Installation

1. Navigate to `https://${APP_URL}/install.php`
2. Complete the installation wizard
3. After installation, set `SUITECRM_INSTALLER_LOCKED=true`

---

## 10. Script Reference

### 10.1 Docker Scripts

| Script | CLI Command | Description |
|--------|-------------|-------------|
| `docker-generate.sh` | `docker-generate` | Generate Dockerfile and docker-compose.yml from templates |
| `docker-build.sh` | `docker-build` | Build Docker image |
| `docker-start.sh` | `docker-start` | Start container |
| `docker-stop.sh` | `docker-stop` | Stop container |
| `docker-validate.sh` | `docker-validate` | Validate all Docker components |
| `docker-teardown.sh` | `docker-teardown` | Remove all Docker artifacts |

### 10.2 Azure Scripts

| Script | CLI Command | Description |
|--------|-------------|-------------|
| `azure-provision-infra.sh` | `azure-provision` | Create Azure resources |
| `azure-teardown-infra.sh` | `azure-teardown` | Delete Azure resources |
| `azure-validate-resources.sh` | `azure-validate` | Validate Azure resources |
| `azure-mount-fileshare-to-local.sh` | `azure-mount` | Mount Azure Files locally |

### 10.3 Menu Access

```bash
./scripts/menu.sh
```

```
Docker Operations ─────────────────────────────
  1) Generate Docker Files (from templates)
  2) Build Image
  3) Start Container
  4) Stop Container
  5) View Logs
  6) Validate Docker
  7) Teardown Docker
  8) Back
```

---

## 11. Troubleshooting

### 11.1 Template Generation Issues

**Problem:** `envsubst: command not found`

```bash
# Install gettext (contains envsubst)
sudo apt-get install gettext
```

**Problem:** Variables not substituted

```bash
# Ensure variables are exported
source .env
export $(grep -v '^#' .env | grep -v '^$' | cut -d= -f1)
```

### 11.2 Build Issues

**Problem:** Build fails with permission errors

```bash
# Ensure Docker daemon is running
sudo systemctl start docker

# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

**Problem:** Image too large

```bash
# Use multi-stage build or .dockerignore
# Check for large files
du -sh *
```

### 11.3 Runtime Issues

**Problem:** Container can't connect to database

```bash
# Check environment variables
docker compose exec web env | grep MYSQL

# Test connection manually
docker compose exec web php -r "
  \$conn = new mysqli(
    getenv('SUITECRM_RUNTIME_MYSQL_HOST'),
    getenv('SUITECRM_RUNTIME_MYSQL_USER'),
    getenv('SUITECRM_RUNTIME_MYSQL_PASSWORD'),
    getenv('SUITECRM_RUNTIME_MYSQL_NAME')
  );
  echo \$conn->connect_error ? 'Failed: '.\$conn->connect_error : 'Connected!';
"
```

**Problem:** Mounts not working

```bash
# Check mount status
mount | grep azure

# Validate mount script
./scripts/cli.sh docker-validate
```

---

## Appendix A: Complete .env Template

```bash
# ============================================================================
# DOCKER BUILD CONFIGURATION
# ============================================================================
# Base image and versions
DOCKER_PHP_BASE_IMAGE=php:8.3-apache
DOCKER_SUITECRM_VERSION=8.8.0
DOCKER_PLATFORM=linux/amd64

# Container naming
DOCKER_IMAGE_NAME=suitecrm
DOCKER_IMAGE_TAG=latest
DOCKER_CONTAINER_NAME=suitecrm-web
DOCKER_NETWORK_NAME=suitecrm-network

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

## Appendix B: File Structure

```
TheBuzzMagazines/
├── .env                           # Configuration (git-ignored)
├── .env.example                   # Template (committed)
├── Dockerfile                     # Generated (git-ignored)
├── Dockerfile.template            # Template (committed)
├── docker-compose.yml             # Generated (git-ignored)
├── docker-compose.template.yml    # Template (committed)
├── docker-entrypoint.sh           # Runtime script (committed)
├── scripts/
│   ├── docker-generate.sh         # Template generation
│   ├── docker-build.sh            # Build image
│   ├── docker-start.sh            # Start container
│   ├── docker-stop.sh             # Stop container
│   ├── docker-validate.sh         # Validate components
│   ├── docker-teardown.sh         # Remove artifacts
│   ├── cli.sh                     # Command-line interface
│   ├── menu.sh                    # Interactive menu
│   └── validate-env.sh            # Environment validation
└── docs/
    ├── DOCKER_GUIDE.md            # This document
    ├── ENV_GUIDE.md               # Environment variable reference
    └── SCRIPTS_GUIDE.md           # Script documentation
```

---

## Appendix C: Variable Categories Summary

| Category | Prefix | Count | Purpose |
|----------|--------|-------|---------|
| Base Image | `DOCKER_PHP_*`, `DOCKER_SUITECRM_*` | 3 | PHP and SuiteCRM versions |
| Container | `DOCKER_CONTAINER_*`, `DOCKER_IMAGE_*` | 4 | Naming and tagging |
| PHP Settings | `DOCKER_PHP_*` | 6 | PHP configuration |
| OPcache | `DOCKER_OPCACHE_*` | 3 | PHP opcode cache |
| Networking | `DOCKER_*_PORT` | 2 | Port mapping |
| Health Check | `DOCKER_HEALTHCHECK_*` | 4 | Container health |
| Labels | `DOCKER_LABEL_*` | 2 | Image metadata |
| **Total Build-Time** | `DOCKER_*` | **~24** | Baked into image |
| **Total Runtime** | `SUITECRM_*` | **~12** | Passed at startup |

# SuiteCRM Docker Build & Azure Container Apps Migration

## Task Analysis Document

**Purpose:** Comprehensive analysis of requirements to build a SuiteCRM 8.8.0 Docker image and deploy it to Azure Container Apps (ACA).

**Last Updated:** January 2026

---

## Table of Contents

1. [Current State Assessment](#1-current-state-assessment)
2. [Requirements Analysis](#2-requirements-analysis)
3. [Phase 1: Pre-Build Preparation](#3-phase-1-pre-build-preparation)
4. [Phase 2: Docker Image Build](#4-phase-2-docker-image-build)
5. [Phase 3: Push to Azure Container Registry](#5-phase-3-push-to-azure-container-registry)
6. [Phase 4: Container Apps Environment Setup](#6-phase-4-container-apps-environment-setup)
7. [Phase 5: Container App Deployment](#7-phase-5-container-app-deployment)
8. [Phase 6: Post-Deployment & Testing](#8-phase-6-post-deployment--testing)
9. [Script Requirements](#9-script-requirements)
10. [Implementation Task List](#10-implementation-task-list)

---

## 1. Current State Assessment

### What Already Exists

| Component | Status | Location | Notes |
|-----------|--------|----------|-------|
| **Dockerfile** | ✅ Complete | `./Dockerfile` | SuiteCRM 8.8.0, PHP 8.3, Apache, all extensions, SSL support |
| **Entrypoint Script** | ✅ Complete | `./docker-entrypoint.sh` | Dynamic config generation, DB wait, permissions |
| **docker-compose.yml** | ✅ Complete | `./docker-compose.yml` | Local dev with Azure backend |
| **Environment Variables** | ✅ Defined | `./.env` | ACR, Container Apps, MySQL settings |
| **Azure Resources** | 🔄 Scripted | `scripts/azure-provision-infra.sh` | Creates RG, MySQL, Storage, ACR |
| **Local Mounts** | ✅ Scripted | `scripts/azure-mount-fileshare-to-local.sh` | Mounts Azure Files locally |
| **Manual ACA Guide** | ✅ Exists | `./azure-container-apps.md` | Manual deployment steps |

### What Does NOT Exist (Needs to be Created)

| Component | Priority | Description |
|-----------|----------|-------------|
| **Build Script** | High | `scripts/azure-docker-build.sh` - Build & push image |
| **Deploy Script** | High | `scripts/azure-deploy-aca.sh` - Deploy to ACA |
| **SuiteCRM Install Script** | Medium | First-time SuiteCRM installation automation |
| **Health Check Endpoint** | Medium | Dedicated health check for ACA probes |
| **CLI/Menu Integration** | High | Add new commands to cli.sh and menu.sh |

---

## 2. Requirements Analysis

### 2.1 SuiteCRM 8.8.0 Requirements

**PHP Requirements:**
- PHP 8.1, 8.2, or 8.3 (we use 8.3) ✅
- Extensions: mysqli, gd, zip, intl, xml, opcache, imap, bcmath, pdo, pdo_mysql ✅
- Memory: 512MB minimum ✅
- Upload: 100MB recommended ✅

**Web Server:**
- Apache with mod_rewrite ✅
- DocumentRoot: `/var/www/html/public` ✅
- .htaccess support ✅

**Database:**
- MySQL 5.7+ or 8.0 ✅
- SSL/TLS support for Azure MySQL ✅

**Persistent Storage:**
- `/public/legacy/upload` - User uploads (MUST persist)
- `/public/legacy/custom` - Custom modules/code (MUST persist)
- `/public/legacy/cache` - Cache files (SHOULD persist for performance)

### 2.2 Azure Infrastructure Requirements

**Pre-requisites (from azure-provision-infra.sh):**
- ✅ Resource Group: `rg-buzzmag-suitecrm`
- ✅ MySQL Flexible Server: `buzzmag-mysql.mysql.database.azure.com`
- ✅ Storage Account: `buzzmagstorage`
- ✅ File Shares: `suitecrm-upload`, `suitecrm-custom`, `suitecrm-cache`
- ✅ Container Registry: `buzzmagacr.azurecr.io`

**ACA Requirements (need to be created):**
- Container Apps Environment: `buzzmag-cae`
- Container App: `suitecrm`
- Storage mounts linked to environment
- Secrets for passwords

### 2.3 Environment Variable Flow

```
.env (local)
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                   Build-Time (Dockerfile)                    │
│  - ENV defaults baked into image                            │
│  - SSL certificates installed                               │
│  - SuiteCRM source code downloaded                          │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                 Deploy-Time (ACA Configuration)              │
│  - Environment variables passed to container                │
│  - Secrets injected (passwords)                             │
│  - Volume mounts configured                                 │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│               Run-Time (docker-entrypoint.sh)               │
│  - Reads environment variables                              │
│  - Generates SuiteCRM config files                          │
│  - Sets permissions on mounted volumes                      │
│  - Waits for database                                       │
│  - Starts Apache                                            │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Phase 1: Pre-Build Preparation

### 3.1 Verify Dockerfile is Complete

**Checklist:**
- [x] Base image: `php:8.3-apache`
- [x] Platform: `linux/amd64`
- [x] All PHP extensions installed
- [x] Apache configured (mod_rewrite, headers, DocumentRoot)
- [x] PHP settings optimized (memory, uploads, opcache)
- [x] SSL certificates for Azure MySQL
- [x] SuiteCRM downloaded and extracted
- [x] Entrypoint script copied
- [x] Proper permissions set
- [x] Port 80 exposed

**Potential Improvements:**
- [ ] Add health check endpoint script
- [ ] Consider multi-stage build to reduce image size
- [ ] Add version labels for tracking

### 3.2 Verify Entrypoint Script

**Checklist:**
- [x] Generates `/public/legacy/.env` from environment
- [x] Generates `config_override.php` for database settings
- [x] Handles SSL configuration for Azure MySQL
- [x] Sets permissions on mounted volumes
- [x] Waits for database availability
- [x] Logs to stdout for container monitoring

**Potential Improvements:**
- [ ] Add SuiteCRM installation detection/automation
- [ ] Add database migration check
- [ ] Add cache warm-up

### 3.3 Environment Variables Required

**For Build Script:**
```bash
AZURE_ACR_NAME          # Container Registry name
AZURE_RESOURCE_GROUP    # Resource group
```

**For Deploy Script:**
```bash
# Azure Infrastructure
AZURE_RESOURCE_GROUP
AZURE_LOCATION
AZURE_ACR_NAME
AZURE_STORAGE_ACCOUNT_NAME
AZURE_CONTAINER_APP_ENV
AZURE_CONTAINER_APP_NAME

# Database Connection (passed to container)
SUITECRM_RUNTIME_MYSQL_HOST
SUITECRM_RUNTIME_MYSQL_PORT
SUITECRM_RUNTIME_MYSQL_NAME
SUITECRM_RUNTIME_MYSQL_USER
SUITECRM_RUNTIME_MYSQL_PASSWORD  # SECRET

# Application Settings (passed to container)
SUITECRM_SITE_URL
SUITECRM_LOG_LEVEL
SUITECRM_INSTALLER_LOCKED
TZ
```

---

## 4. Phase 2: Docker Image Build

### 4.1 Build Process

```bash
# Step 1: Navigate to project root
cd /home/ami/src/TheBuzzMagazines

# Step 2: Build image with proper tag
docker build \
  --platform linux/amd64 \
  -t ${AZURE_ACR_NAME}.azurecr.io/suitecrm:8.8.0 \
  -t ${AZURE_ACR_NAME}.azurecr.io/suitecrm:latest \
  .

# Step 3: Verify build
docker images | grep suitecrm
```

### 4.2 Build Script Requirements

The `azure-docker-build.sh` script must:

1. **Load environment** from `.env`
2. **Validate prerequisites**:
   - Docker installed and running
   - Dockerfile exists
   - Required env vars set
3. **Build the image**:
   - Tag with version (8.8.0)
   - Tag with `latest`
   - Use linux/amd64 platform
4. **Optionally test locally**:
   - Run with docker-compose
   - Verify container starts
5. **Optionally push to ACR**:
   - Login to ACR
   - Push both tags
6. **Log all actions** to `logs/`

### 4.3 Local Testing Before Push

```bash
# Test with docker-compose (requires Azure backend)
docker compose up --build -d

# Check logs
docker compose logs -f

# Verify health
curl http://localhost/

# Stop
docker compose down
```

---

## 5. Phase 3: Push to Azure Container Registry

### 5.1 ACR Authentication

```bash
# Method 1: Azure CLI (preferred)
az acr login --name ${AZURE_ACR_NAME}

# Method 2: Docker login with admin credentials
ACR_USERNAME=$(az acr credential show --name ${AZURE_ACR_NAME} --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name ${AZURE_ACR_NAME} --query passwords[0].value -o tsv)
docker login ${AZURE_ACR_NAME}.azurecr.io -u $ACR_USERNAME -p $ACR_PASSWORD
```

### 5.2 Push Process

```bash
# Push versioned tag
docker push ${AZURE_ACR_NAME}.azurecr.io/suitecrm:8.8.0

# Push latest tag
docker push ${AZURE_ACR_NAME}.azurecr.io/suitecrm:latest
```

### 5.3 Verify Push

```bash
# List images in ACR
az acr repository list --name ${AZURE_ACR_NAME} --output table

# Show tags for suitecrm
az acr repository show-tags --name ${AZURE_ACR_NAME} --repository suitecrm --output table
```

---

## 6. Phase 4: Container Apps Environment Setup

### 6.1 Create Container Apps Environment

```bash
az containerapp env create \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --name ${AZURE_CONTAINER_APP_ENV} \
  --location ${AZURE_LOCATION}
```

### 6.2 Configure Storage Mounts in Environment

**Critical:** Storage must be added to the ENVIRONMENT, not the container app directly.

```bash
# Get storage key
STORAGE_KEY=$(az storage account keys list \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --account-name ${AZURE_STORAGE_ACCOUNT_NAME} \
  --query '[0].value' -o tsv)

# Add upload share
az containerapp env storage set \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --name ${AZURE_CONTAINER_APP_ENV} \
  --storage-name suitecrm-upload \
  --azure-file-account-name ${AZURE_STORAGE_ACCOUNT_NAME} \
  --azure-file-account-key "$STORAGE_KEY" \
  --azure-file-share-name suitecrm-upload \
  --access-mode ReadWrite

# Add custom share
az containerapp env storage set \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --name ${AZURE_CONTAINER_APP_ENV} \
  --storage-name suitecrm-custom \
  --azure-file-account-name ${AZURE_STORAGE_ACCOUNT_NAME} \
  --azure-file-account-key "$STORAGE_KEY" \
  --azure-file-share-name suitecrm-custom \
  --access-mode ReadWrite

# Add cache share
az containerapp env storage set \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --name ${AZURE_CONTAINER_APP_ENV} \
  --storage-name suitecrm-cache \
  --azure-file-account-name ${AZURE_STORAGE_ACCOUNT_NAME} \
  --azure-file-account-key "$STORAGE_KEY" \
  --azure-file-share-name suitecrm-cache \
  --access-mode ReadWrite
```

### 6.3 Verify Environment Storage

```bash
az containerapp env storage list \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --name ${AZURE_CONTAINER_APP_ENV} \
  --output table
```

---

## 7. Phase 5: Container App Deployment

### 7.1 Get ACR Credentials

```bash
# Enable admin access if not already
az acr update --name ${AZURE_ACR_NAME} --admin-enabled true

# Get credentials
ACR_USERNAME=$(az acr credential show --name ${AZURE_ACR_NAME} --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name ${AZURE_ACR_NAME} --query passwords[0].value -o tsv)
```

### 7.2 Create Container App (Initial Deployment)

```bash
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
    SUITECRM_RUNTIME_MYSQL_SSL_ENABLED=true \
    SUITECRM_RUNTIME_MYSQL_SSL_VERIFY=true \
    SUITECRM_LOG_LEVEL=${SUITECRM_LOG_LEVEL:-warning} \
    SUITECRM_INSTALLER_LOCKED=${SUITECRM_INSTALLER_LOCKED:-false} \
    TZ=${TZ:-America/Chicago} \
  --secrets \
    database-password="${SUITECRM_RUNTIME_MYSQL_PASSWORD}" \
  --secret-env-vars \
    SUITECRM_RUNTIME_MYSQL_PASSWORD=database-password
```

### 7.3 Update with Volume Mounts (YAML Required)

Volume mounts require a YAML configuration file because they can't be set via command line.

**File: `aca-suitecrm.yaml`**

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

**Apply YAML:**
```bash
az containerapp update \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --name ${AZURE_CONTAINER_APP_NAME} \
  --yaml aca-suitecrm.yaml
```

### 7.4 Update Site URL

After deployment, update `SUITECRM_SITE_URL` with the actual ACA URL:

```bash
# Get the URL
APP_URL=$(az containerapp show \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --name ${AZURE_CONTAINER_APP_NAME} \
  --query properties.configuration.ingress.fqdn -o tsv)

# Update environment variable
az containerapp update \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --name ${AZURE_CONTAINER_APP_NAME} \
  --set-env-vars SUITECRM_SITE_URL=https://${APP_URL}
```

---

## 8. Phase 6: Post-Deployment & Testing

### 8.1 Get Application URL

```bash
az containerapp show \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --name ${AZURE_CONTAINER_APP_NAME} \
  --query properties.configuration.ingress.fqdn -o tsv
```

### 8.2 Health Checks

```bash
# Check container status
az containerapp show \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --name ${AZURE_CONTAINER_APP_NAME} \
  --query properties.runningStatus

# View logs
az containerapp logs show \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --name ${AZURE_CONTAINER_APP_NAME} \
  --follow

# HTTP health check
curl -I https://${APP_URL}/
```

### 8.3 SuiteCRM First-Time Installation

If SuiteCRM hasn't been installed yet:

1. Navigate to `https://${APP_URL}/install.php`
2. Complete the installation wizard:
   - Database: Pre-configured via environment variables
   - Admin User: Create admin account
   - Site URL: Should be pre-filled from `SUITECRM_SITE_URL`
3. After installation, set `SUITECRM_INSTALLER_LOCKED=true`

### 8.4 Verify Storage Mounts

```bash
# Check if uploads work by uploading a file through SuiteCRM
# Check Azure portal: Storage Account > File Shares > suitecrm-upload
```

### 8.5 Database Connectivity Test

```bash
# View entrypoint logs for "Database connection successful!"
az containerapp logs show \
  --resource-group ${AZURE_RESOURCE_GROUP} \
  --name ${AZURE_CONTAINER_APP_NAME} \
  | grep -i database
```

---

## 9. Script Requirements

### 9.1 Script: `azure-docker-build.sh`

**Purpose:** Build Docker image and optionally push to ACR

**Features:**
- Load `.env` configuration
- Validate Docker is running
- Validate Dockerfile exists
- Build with proper tags (version + latest)
- Platform: linux/amd64
- Optional local test with docker-compose
- Optional push to ACR
- Logging to `logs/` folder
- Interactive and non-interactive modes

**Usage:**
```bash
./scripts/azure-docker-build.sh              # Build only
./scripts/azure-docker-build.sh --push       # Build and push
./scripts/azure-docker-build.sh --test       # Build and test locally
./scripts/azure-docker-build.sh -y           # Non-interactive
```

### 9.2 Script: `azure-deploy-aca.sh`

**Purpose:** Deploy container to Azure Container Apps

**Features:**
- Load `.env` configuration
- Validate environment variables
- Create Container Apps Environment (if not exists)
- Configure storage mounts
- Create or update Container App
- Configure secrets
- Configure volume mounts (via YAML)
- Configure ingress and scaling
- Update SUITECRM_SITE_URL with actual URL
- Logging to `logs/` folder
- Interactive and non-interactive modes

**Usage:**
```bash
./scripts/azure-deploy-aca.sh                # Deploy
./scripts/azure-deploy-aca.sh --update       # Update existing
./scripts/azure-deploy-aca.sh -y             # Non-interactive
```

### 9.3 Updates to Existing Scripts

**cli.sh additions:**
```
docker-build [options]     Build Docker image
docker-push                Push to ACR
docker-test                Test locally with docker-compose
deploy-aca [options]       Deploy to Azure Container Apps
aca-logs                   View ACA container logs
aca-status                 Show ACA status and URL
```

**menu.sh additions:**
```
Docker submenu:
  - Build Image
  - Push to ACR
  - Test Locally
  
Azure submenu:
  - Deploy to Container Apps
  - View ACA Logs
  - Show ACA Status
```

---

## 10. Implementation Task List

### Order of Implementation

#### Phase A: Build Scripts (Priority: HIGH)

| # | Task | Script/File | Dependencies |
|---|------|-------------|--------------|
| A1 | Create `azure-docker-build.sh` | `scripts/azure-docker-build.sh` | Dockerfile, .env |
| A2 | Add `docker-build` command to cli.sh | `scripts/cli.sh` | A1 |
| A3 | Add Build Image option to menu.sh | `scripts/menu.sh` | A2 |
| A4 | Add `docker-push` command to cli.sh | `scripts/cli.sh` | A1 |
| A5 | Add Push to ACR option to menu.sh | `scripts/menu.sh` | A4 |

#### Phase B: Deployment Scripts (Priority: HIGH)

| # | Task | Script/File | Dependencies |
|---|------|-------------|--------------|
| B1 | Create `azure-deploy-aca.sh` | `scripts/azure-deploy-aca.sh` | Image in ACR, Azure resources |
| B2 | Create ACA YAML template | `templates/aca-suitecrm.yaml` | B1 |
| B3 | Add `deploy-aca` command to cli.sh | `scripts/cli.sh` | B1 |
| B4 | Add Deploy to ACA option to menu.sh | `scripts/menu.sh` | B3 |
| B5 | Add `aca-logs` command to cli.sh | `scripts/cli.sh` | B1 |
| B6 | Add `aca-status` command to cli.sh | `scripts/cli.sh` | B1 |

#### Phase C: Documentation (Priority: MEDIUM)

| # | Task | File | Dependencies |
|---|------|------|--------------|
| C1 | Update SCRIPTS_GUIDE.md | `docs/SCRIPTS_GUIDE.md` | A1-B6 |
| C2 | Update ENV_GUIDE.md | `docs/ENV_GUIDE.md` | If new env vars added |
| C3 | Update .cursorrules | `.cursorrules` | A1-B6 |
| C4 | Update azure-container-apps.md | `azure-container-apps.md` | B1-B6 |

#### Phase D: Testing & Validation (Priority: HIGH)

| # | Task | Description | Dependencies |
|---|------|-------------|--------------|
| D1 | Test build script | Build image locally | A1 |
| D2 | Test push to ACR | Push image to registry | A1, D1 |
| D3 | Test ACA deployment | Deploy to Container Apps | B1, D2 |
| D4 | Test SuiteCRM access | Verify app works | D3 |
| D5 | Test storage mounts | Upload file, verify persistence | D3 |
| D6 | Test database connectivity | Verify MySQL connection | D3 |

---

## Appendix A: Environment Variables Reference

| Variable | Used By | Required | Description |
|----------|---------|----------|-------------|
| `AZURE_ACR_NAME` | Build, Deploy | Yes | Container Registry name |
| `AZURE_RESOURCE_GROUP` | Build, Deploy | Yes | Resource group |
| `AZURE_LOCATION` | Deploy | Yes | Azure region |
| `AZURE_STORAGE_ACCOUNT_NAME` | Deploy | Yes | Storage account for files |
| `AZURE_CONTAINER_APP_ENV` | Deploy | Yes | Container Apps Environment name |
| `AZURE_CONTAINER_APP_NAME` | Deploy | Yes | Container App name |
| `SUITECRM_RUNTIME_MYSQL_HOST` | Deploy | Yes | MySQL server hostname |
| `SUITECRM_RUNTIME_MYSQL_PORT` | Deploy | Yes | MySQL port |
| `SUITECRM_RUNTIME_MYSQL_NAME` | Deploy | Yes | Database name |
| `SUITECRM_RUNTIME_MYSQL_USER` | Deploy | Yes | Database user |
| `SUITECRM_RUNTIME_MYSQL_PASSWORD` | Deploy | Yes | Database password (SECRET) |
| `SUITECRM_SITE_URL` | Deploy | Yes | Public URL (updated after deploy) |
| `SUITECRM_LOG_LEVEL` | Deploy | No | Log verbosity (default: warning) |
| `SUITECRM_INSTALLER_LOCKED` | Deploy | No | Lock installer (default: false) |
| `TZ` | Deploy | No | Timezone (default: America/Chicago) |

---

## Appendix B: File Structure After Implementation

```
TheBuzzMagazines/
├── scripts/
│   ├── azure-docker-build.sh      # NEW: Build and push Docker image
│   ├── azure-deploy-aca.sh        # NEW: Deploy to Azure Container Apps
│   ├── azure-provision-infra.sh   # EXISTS: Create Azure resources
│   ├── azure-teardown-infra.sh    # EXISTS: Delete Azure resources
│   ├── azure-test-capabilities.sh # EXISTS: Test Azure permissions
│   ├── azure-mount-fileshare-to-local.sh # EXISTS: Mount Azure Files
│   ├── cli.sh                     # UPDATE: Add new commands
│   ├── menu.sh                    # UPDATE: Add new menu options
│   └── validate-env.sh            # EXISTS: Validate .env
├── templates/
│   └── aca-suitecrm.yaml          # NEW: ACA deployment template
├── docs/
│   ├── SUITECRM_DOCKER_CREATE_MIGRATE.md # THIS FILE
│   ├── SCRIPTS_GUIDE.md           # UPDATE: Document new scripts
│   └── ENV_GUIDE.md               # UPDATE: If new env vars
├── Dockerfile                     # EXISTS: Container definition
├── docker-entrypoint.sh           # EXISTS: Container startup
├── docker-compose.yml             # EXISTS: Local development
├── azure-container-apps.md        # UPDATE: Reference new scripts
└── .env                           # EXISTS: Configuration
```

---

## Appendix C: Estimated Time & Complexity

| Phase | Estimated Effort | Complexity | Risk |
|-------|------------------|------------|------|
| A (Build Scripts) | 2-3 hours | Medium | Low |
| B (Deploy Scripts) | 4-6 hours | High | Medium |
| C (Documentation) | 1-2 hours | Low | Low |
| D (Testing) | 2-4 hours | Medium | Medium |
| **Total** | **9-15 hours** | | |

**Key Risks:**
1. ACA volume mount configuration complexity
2. SuiteCRM first-time installation requirements
3. MySQL SSL connection issues
4. Storage permission issues

---

## Summary: Precise Implementation Order

1. **A1**: Create `scripts/azure-docker-build.sh`
2. **A2-A3**: Integrate build into cli.sh and menu.sh
3. **A4-A5**: Add push functionality to cli.sh and menu.sh
4. **D1-D2**: Test build and push to ACR
5. **B1**: Create `scripts/azure-deploy-aca.sh`
6. **B2**: Create `templates/aca-suitecrm.yaml`
7. **B3-B6**: Integrate deploy and monitoring into cli.sh and menu.sh
8. **D3-D6**: Full deployment and functionality testing
9. **C1-C4**: Update all documentation

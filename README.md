<p align="center">
  <img src="./docs/images/buzz_readme_heading.png" alt="TheBuzzMagazines" width="600"/>
</p>

<h1 align="center">TheBuzzMagazines CRM Migration Project</h1>

<p align="center">
  <strong>Modernizing a 20+ Year Legacy System to Cloud-Native Architecture</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/SuiteCRM-8.8.0-blue?style=flat-square" alt="SuiteCRM 8.8.0"/>
  <img src="https://img.shields.io/badge/PHP-8.3-purple?style=flat-square" alt="PHP 8.3"/>
  <img src="https://img.shields.io/badge/Azure-Container%20Apps-0078D4?style=flat-square" alt="Azure Container Apps"/>
  <img src="https://img.shields.io/badge/Docker-Containerized-2496ED?style=flat-square" alt="Docker"/>
  <img src="https://img.shields.io/badge/MySQL-8.4-orange?style=flat-square" alt="MySQL 8.4"/>
</p>

---

## Introduction

**TheBuzzMagazines** is a comprehensive CRM migration project that transforms a legacy Microsoft Access database application into a modern, cloud-native Customer Relationship Management system powered by SuiteCRM and hosted on Microsoft Azure.

### The Challenge

The original system—a Microsoft Access database built over 20 years ago—has faithfully served the Buzz Magazines advertising sales team for decades. However, it faces critical limitations:

- **Single-user access** prevents team collaboration
- **No remote access** limits productivity
- **No automated backups** risks catastrophic data loss
- **Aging technology** makes maintenance increasingly difficult
- **No mobile support** in an increasingly mobile workforce

### The Solution

This project migrates the legacy data and workflows to **SuiteCRM 8.8**, a modern open-source CRM, deployed as a containerized application on **Azure Container Apps** with enterprise-grade security, automatic backups, and global accessibility.

---

## Table of Contents

| Section | Description |
|---------|-------------|
| [1. The Legacy System](#1-the-legacy-system) | The original MS Access application |
| [2. Architecture Overview](#2-architecture-overview) | Cloud-native design and data flow |
| [3. Technology Stack](#3-technology-stack) | Components and services used |
| [4. Azure Infrastructure](#4-azure-infrastructure) | Cloud resources and configuration |
| [5. Docker Container](#5-docker-container) | Container build and configuration |
| [6. Development Workflow](#6-development-workflow) | Scripts and automation |
| [7. Deployment Guide](#7-deployment-guide) | Step-by-step instructions |
| [8. Data Migration](#8-data-migration) | Legacy to SuiteCRM migration |
| [9. Security](#9-security) | Authentication and encryption |
| [10. Troubleshooting](#10-troubleshooting) | Common issues and solutions |

---

## 1. The Legacy System

### A 20-Year Journey in Microsoft Access

The original **Buzz Advertisers Database** was built in Microsoft Access in the early 2000s. Despite its age, it remains fully functional and has been the backbone of the advertising sales operation for over two decades.

<p align="center">
  <img src="./docs/images/legacy_main_menu.png" alt="Legacy Main Menu" width="600"/>
  <br/>
  <em>The main menu of the original MS Access application</em>
</p>

### What the Legacy System Does

The Access database manages the complete advertising sales workflow:

| Module | Function |
|--------|----------|
| **Advertiser Management** | Track companies, contacts, and communication history |
| **Prospect Tracking** | Manage sales pipeline and lead status |
| **Account Executives** | Assign territories and track performance |
| **Product Categories** | Organize advertising offerings |
| **Reporting** | Generate sales reports and analytics |

### Advertiser and Prospects Management

The heart of the system is the advertiser management interface, where sales representatives track their accounts and prospects.

<p align="center">
  <img src="./docs/images/legacy_advertiser_list.png" alt="Legacy Advertiser List" width="700"/>
  <br/>
  <em>Advertiser and prospects list view</em>
</p>

### Company Maintenance Forms

Detailed company information is managed through comprehensive data entry forms:

<p align="center">
  <img src="./docs/images/legacy_advertiser_form.png" alt="Legacy Advertiser Form" width="600"/>
  <br/>
  <em>The advertiser maintenance form with contact details and history</em>
</p>

### Reporting Dashboard

The system includes a reporting module for generating sales analytics and territory reports:

<p align="center">
  <img src="./docs/images/legacy_report_dashboard.png" alt="Legacy Report Dashboard" width="600"/>
  <br/>
  <em>Database report selection dashboard</em>
</p>

### Sample Report Output

Reports generate detailed listings by product category, account executive, and other criteria:

<p align="center">
  <img src="./docs/images/legacy_product_report.png" alt="Legacy Product Report" width="600"/>
  <br/>
  <em>All Product Categories report showing advertiser listings</em>
</p>

### Legacy System Limitations

| Limitation | Impact | Modern Solution |
|------------|--------|-----------------|
| Single-user file-based | No concurrent access | Multi-user web application |
| Local network only | No remote work capability | Cloud-hosted, accessible anywhere |
| No backups | Risk of data loss | Automated Azure backups |
| Windows-only | Platform locked | Cross-platform web access |
| No mobile access | Limited field sales | Responsive web design |
| Manual updates | Version control issues | Containerized deployments |

---

## 2. Architecture Overview

### Design Principles

The modernization follows cloud-native best practices:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          DESIGN PRINCIPLES                              │
├─────────────────────────────────────────────────────────────────────────┤
│  1. STATELESS CONTAINERS     No data stored in containers               │
│  2. ENVIRONMENT CONFIG       All settings via environment variables     │
│  3. CLOUD-NATIVE             Designed for serverless container hosting  │
│  4. PORTABLE                 Run locally or in Azure with same image    │
│  5. SECURE BY DEFAULT        SSL/TLS everywhere, no plain text secrets  │
└─────────────────────────────────────────────────────────────────────────┘
```

### Azure Architecture Diagram

<p align="center">
  <img src="./docs/images/buzz_architecture.png" alt="Azure Architecture" width="800"/>
  <br/>
  <em>TheBuzzMagazines SuiteCRM Azure Architecture</em>
</p>

<sub>[View PlantUML source](./docs/puml/buzz_architecture.puml)</sub>

### High-Level Data Flow

```
                                    ┌─────────────────┐
                                    │      Users      │
                                    │  (Sales Team)   │
                                    └────────┬────────┘
                                             │ HTTPS
                                             ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                        AZURE CONTAINER APPS                                │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                     SuiteCRM Container                               │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────────────┐ │  │
│  │  │    Apache    │  │    PHP 8.3   │  │    SuiteCRM 8.8.0           │ │  │
│  │  │   (Port 80)  │──│   Runtime    │──│    Application              │ │  │
│  │  └──────────────┘  └──────────────┘  └─────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────────┘
           │                                                    │
           │ MySQL (SSL)                                        │ SMB
           ▼                                                    ▼
┌───────────────────────────┐                    ┌───────────────────────────┐
│  Azure MySQL Flexible     │                    │     Azure Files           │
│  ───────────────────────  │                    │   ─────────────────────   │
│  • suitecrm database      │                    │   • suitecrm-upload       │
│  • SSL/TLS encrypted      │                    │   • suitecrm-custom       │
│  • 7-day auto backups     │                    │   • suitecrm-cache        │
│  • Point-in-time restore  │                    │   • Hot tier storage      │
└───────────────────────────┘                    └───────────────────────────┘
```

### Development vs Production Architecture

| Component | Local Development | Azure Production |
|-----------|-------------------|------------------|
| Container Runtime | Docker Desktop | Azure Container Apps |
| Database | Azure MySQL (remote) | Azure MySQL Flexible Server |
| File Storage | Azure Files (SMB mount) | Azure Files (native mount) |
| Image Registry | Local Docker | Azure Container Registry |
| HTTPS | localhost:80 (HTTP) | Azure-managed HTTPS |

---

## 3. Technology Stack

### Container Stack

| Layer | Technology | Version | Purpose |
|-------|------------|---------|---------|
| **OS** | Debian | Bookworm | Base operating system |
| **Web Server** | Apache | 2.4.x | HTTP server with mod_rewrite |
| **Runtime** | PHP | 8.3 | Application runtime |
| **Application** | SuiteCRM | 8.8.0 | CRM platform |

### PHP Extensions

| Extension | Purpose |
|-----------|---------|
| `mysqli` | MySQL database connectivity |
| `pdo_mysql` | PDO MySQL driver |
| `gd` | Image processing (freetype, jpeg) |
| `zip` | Archive handling |
| `intl` | Internationalization |
| `xml` | XML processing |
| `opcache` | PHP bytecode caching |
| `imap` | Email integration |
| `bcmath` | Arbitrary precision mathematics |

### Azure Services

| Service | SKU | Purpose | Monthly Cost (Est.) |
|---------|-----|---------|---------------------|
| Container Apps | Consumption | Serverless container hosting | ~$15-50 |
| MySQL Flexible Server | Standard_B1s | CRM data storage | ~$12 |
| Storage Account | Standard LRS | File shares | ~$5 |
| Container Registry | Basic | Docker image repository | ~$5 |

**Estimated Total: ~$40-75/month**

### Development Tools

| Tool | Purpose |
|------|---------|
| Docker Desktop | Container runtime |
| Azure CLI | Azure resource management |
| cifs-utils | SMB mounting for Azure Files |
| MySQL Client | Database operations |
| Git | Version control |

---

## 4. Azure Infrastructure

### Resource Organization

All Azure resources are organized within a single resource group:

```
buzz-rg (Resource Group)
├── buzz-mysql (MySQL Flexible Server)
│   └── suitecrm (Database)
├── buzzmagstorage (Storage Account)
│   ├── suitecrm-upload (File Share)
│   ├── suitecrm-custom (File Share)
│   └── suitecrm-cache (File Share)
├── buzzacr (Container Registry)
└── buzz-cae (Container Apps Environment)
    └── suitecrm (Container App)
```

### MySQL Flexible Server Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| **SKU** | Standard_B1s (Burstable) | 1 vCore, 1GB RAM |
| **Storage** | 20 GB | Auto-grow enabled |
| **Version** | 8.4 | Latest stable |
| **Backup** | 7-day retention | Geo-redundant optional |
| **SSL** | Required | Certificate-based |
| **Firewall** | Azure services + Dev IP | Configurable rules |

### Storage Account File Shares

| Share Name | Mount Path | Purpose |
|------------|------------|---------|
| `suitecrm-upload` | `/var/www/html/public/legacy/upload` | User uploaded files |
| `suitecrm-custom` | `/var/www/html/public/legacy/custom` | Custom modules/extensions |
| `suitecrm-cache` | `/var/www/html/public/legacy/cache` | Application cache |

### Container Apps Configuration

| Setting | Value |
|---------|-------|
| **Min Replicas** | 1 |
| **Max Replicas** | 3 |
| **CPU** | 0.5 cores |
| **Memory** | 1.0 GB |
| **Ingress** | External (HTTPS) |
| **Port** | 80 (container) |

---

## 5. Docker Container

### Container Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DOCKER CONTAINER                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                      ENTRYPOINT SCRIPT                      │    │
│  │  • Generate config from environment variables               │    │
│  │  • Wait for database connection                             │    │
│  │  • Set permissions on mounted volumes                       │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                               │                                     │
│                               ▼                                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐   │
│  │     Apache       │  │      PHP 8.3     │  │   SuiteCRM 8.8   │   │
│  │   mod_rewrite    │──│   mysqli, gd     │──│   Core + Legacy  │   │
│  │   mod_headers    │  │   opcache, imap  │  │   Symfony-based  │   │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘   │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    VOLUME MOUNTS                            │    │
│  │  /var/www/html/public/legacy/upload  → Azure Files          │    │
│  │  /var/www/html/public/legacy/custom  → Azure Files          │    │
│  │  /var/www/html/public/legacy/cache   → Azure Files          │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Environment Variables

The container is configured entirely through environment variables:

| Variable | Required | Description |
|----------|----------|-------------|
| `SUITECRM_RUNTIME_MYSQL_HOST` | Yes | MySQL server hostname |
| `SUITECRM_RUNTIME_MYSQL_PORT` | No | MySQL port (default: 3306) |
| `SUITECRM_RUNTIME_MYSQL_NAME` | Yes | Database name |
| `SUITECRM_RUNTIME_MYSQL_USER` | Yes | Database username |
| `SUITECRM_RUNTIME_MYSQL_PASSWORD` | Yes | Database password |
| `SUITECRM_RUNTIME_MYSQL_SSL_ENABLED` | No | Enable SSL (default: true) |
| `SUITECRM_SITE_URL` | Yes | Public URL for SuiteCRM |
| `SUITECRM_LOG_LEVEL` | No | Logging level (default: warning) |
| `TZ` | No | Timezone (default: UTC) |

### Docker Build Process

The image is built in stages for optimal caching:

```
Stage 1: Base Image (php:8.3-apache)
    ↓
Stage 2: System Dependencies (apt-get)
    ↓
Stage 3: PHP Extensions (docker-php-ext-install)
    ↓
Stage 4: Apache Configuration (mod_rewrite, SSL)
    ↓
Stage 5: PHP Configuration (memory, uploads, opcache)
    ↓
Stage 6: SuiteCRM Installation (download, extract)
    ↓
Stage 7: Entrypoint Script (runtime configuration)
    ↓
Final Image (~800MB)
```

---

## 6. Development Workflow

### Script-Based Automation

All operations are automated through scripts in the `scripts/` directory:

```
scripts/
├── cli.sh                         # Command-line interface
├── menu.sh                        # Interactive menu
├── validate-env.sh                # Environment validation
├── azure-provision-infra.sh       # Create Azure resources
├── azure-teardown-infra.sh        # Delete Azure resources
├── azure-validate-resources.sh    # Check resource status
├── azure-mount-fileshare-to-local.sh  # Mount Azure Files locally
├── azure-test-capabilities.sh     # Test Azure permissions
├── docker-build.sh                # Build Docker image
├── docker-start.sh                # Start container
├── docker-stop.sh                 # Stop container
├── docker-validate.sh             # Check Docker status
└── docker-teardown.sh             # Remove Docker artifacts
```

### Command Reference

**Azure Commands:**

| Command | Description |
|---------|-------------|
| `./scripts/cli.sh provision` | Create all Azure resources |
| `./scripts/cli.sh validate-resources` | Check Azure resource status |
| `./scripts/cli.sh mount` | Mount Azure Files locally (sudo) |
| `./scripts/cli.sh teardown` | Delete all Azure resources |

**Docker Commands:**

| Command | Description |
|---------|-------------|
| `./scripts/cli.sh docker-build` | Build the Docker image |
| `./scripts/cli.sh docker-start` | Start the container |
| `./scripts/cli.sh docker-stop` | Stop the container |
| `./scripts/cli.sh docker-validate` | Check Docker status |
| `./scripts/cli.sh docker-teardown` | Remove all Docker artifacts |

### Interactive Menu

For an interactive experience, run:

```bash
./scripts/menu.sh
```

```
┌─────────────────────────────────────────────────────────────────────┐
│                    THEBUZZMAGAZINES - MAIN MENU                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   1. Environment        Validate .env, edit configuration           │
│   2. Azure Setup        Provision, mount, teardown Azure resources  │
│   3. Docker             Build, start, stop, validate containers     │
│   4. Database           Backup source database                      │
│   5. Logs               View script execution logs                  │
│   6. Quick Actions      Common workflow shortcuts                   │
│                                                                     │
│   0. Exit                                                           │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 7. Deployment Guide

### Workflow Overview

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Step 1    │     │   Step 2    │     │   Step 3    │     │   Step 4    │
│  Configure  │────▶│  Provision  │────▶│   Build     │────▶│   Deploy    │
│    .env     │     │    Azure    │     │   Docker    │     │   & Test    │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

### Step 1: Configure Environment

```bash
# Copy example configuration
cp .env.example .env

# Edit with your values
nano .env

# Validate configuration
./scripts/cli.sh validate-env
```

### Step 2: Provision Azure Resources

```bash
# Login to Azure
az login

# Run provisioning (creates MySQL, Storage, ACR)
./scripts/cli.sh provision

# Verify resources created
./scripts/cli.sh validate-resources
```

### Step 3: Build Docker Image

```bash
# Build the image
./scripts/cli.sh docker-build

# Mount Azure Files locally
sudo ./scripts/cli.sh mount

# Start the container
./scripts/cli.sh docker-start

# Validate everything is running
./scripts/cli.sh docker-validate
```

### Step 4: Access SuiteCRM

Open your browser to: **http://localhost**

Complete the SuiteCRM installation wizard, then lock the installer:

```bash
# Update .env
SUITECRM_INSTALLER_LOCKED=true

# Restart container
./scripts/cli.sh docker-stop
./scripts/cli.sh docker-start
```

---

## 8. Data Migration

### Migration Overview

The migration process transfers data from the legacy MS Access/MySQL database to SuiteCRM:

| Legacy Table | SuiteCRM Module | Notes |
|--------------|-----------------|-------|
| Advertisers | Accounts | Company records |
| AdvContacts | Contacts | Contact persons |
| Comments | Notes/Calls | Communication history |
| AcctExecs | Users | Sales representatives |
| Categories | Custom fields | Product categories |

### Migration Commands

```bash
# Backup source database first
./scripts/cli.sh backup-db-source pre_migration

# Migration scripts (to be developed)
# ./scripts/migrate-advertisers.sh
# ./scripts/migrate-contacts.sh
# ./scripts/migrate-history.sh
```

---

## 9. Security

### Encryption

| Layer | Encryption | Details |
|-------|------------|---------|
| **HTTPS** | TLS 1.2+ | Azure-managed certificates |
| **Database** | SSL Required | MySQL SSL connection mandatory |
| **Storage** | Azure Encryption | Server-side encryption at rest |
| **Secrets** | Environment Variables | Never stored in code |

### Access Control

- **Database**: Firewall rules restrict access to Azure services + developer IPs
- **Storage**: Shared access keys stored in `.azure-secrets` (git-ignored)
- **Container Registry**: Azure RBAC authentication
- **Application**: SuiteCRM role-based access control

### Credentials

| Username | Password | Contact |
|----------|----------|---------|
| manager | *(contact for pwd)* | adworkin@itprotects.com |
| buzz | *(contact for pwd)* | adworkin@itprotects.com |

---

## 10. Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Container won't start | Image not built | Run `./scripts/cli.sh docker-build` |
| Database connection failed | MySQL not ready | Wait 1-2 minutes, check firewall rules |
| Mounts not working | Azure Files not mounted | Run `sudo ./scripts/cli.sh mount` |
| Permission denied | Wrong file ownership | Container sets permissions on start |
| 502 Bad Gateway | Container crashed | Check `docker compose logs` |

### Useful Commands

```bash
# Check all component status
./scripts/cli.sh docker-validate
./scripts/cli.sh validate-resources

# View container logs
docker compose logs -f

# Shell into container
docker compose exec web bash

# Check database connection
docker compose exec web php -r "new mysqli('host', 'user', 'pass', 'db');"
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [ENV_GUIDE.md](./docs/ENV_GUIDE.md) | Environment variable reference |
| [SCRIPTS_GUIDE.md](./docs/SCRIPTS_GUIDE.md) | Script documentation |
| [MIGRATION_PROVISIONING_GUIDE.md](./docs/MIGRATION_PROVISIONING_GUIDE.md) | Detailed Azure provision/deploy guide |
| [SUITECRM_DOCKER_GUIDE.md](./docs/SUITECRM_DOCKER_GUIDE.md) | Detailed Docker provision/deploy guide |

---

## License

This project is proprietary software. See [LICENSE](./LICENSE) for details.

---

<p align="center">
  <strong>TheBuzzMagazines</strong> - Modernizing Sales CRM for the Digital Age
  <br/>
  <sub>Built with SuiteCRM, Docker, and Microsoft Azure</sub>
</p>

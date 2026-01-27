# Azure Container Apps Deployment Guide

This guide covers deploying the SuiteCRM 8.8.0 Docker image to Azure Container Apps.

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- Docker installed for building the image
- Azure Container Registry (ACR) for storing the image
- Azure Database for MySQL Flexible Server
- Azure Storage Account with File shares

---

## Step 1: Create Azure Resources

### Resource Group

```bash
az group create \
  --name rg-suitecrm \
  --location eastus
```

### Azure Container Registry

```bash
az acr create \
  --resource-group rg-suitecrm \
  --name acrsuitecrm \
  --sku Basic

# Enable admin access (for Container Apps)
az acr update \
  --name acrsuitecrm \
  --admin-enabled true
```

### Azure Database for MySQL Flexible Server

```bash
az mysql flexible-server create \
  --resource-group rg-suitecrm \
  --name mysql-suitecrm \
  --admin-user suitecrm \
  --admin-password '<SECURE_PASSWORD>' \
  --sku-name Standard_B1ms \
  --storage-size 32 \
  --version 8.0

# Create the database
az mysql flexible-server db create \
  --resource-group rg-suitecrm \
  --server-name mysql-suitecrm \
  --database-name suitecrm

# Allow Azure services to connect
az mysql flexible-server firewall-rule create \
  --resource-group rg-suitecrm \
  --name mysql-suitecrm \
  --rule-name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
```

### Azure Storage Account with File Shares

```bash
# Create storage account
az storage account create \
  --resource-group rg-suitecrm \
  --name stsuitecrm \
  --sku Standard_LRS \
  --kind StorageV2

# Get storage key
STORAGE_KEY=$(az storage account keys list \
  --resource-group rg-suitecrm \
  --account-name stsuitecrm \
  --query '[0].value' -o tsv)

# Create file shares
az storage share create --name suitecrm-upload --account-name stsuitecrm --account-key $STORAGE_KEY
az storage share create --name suitecrm-custom --account-name stsuitecrm --account-key $STORAGE_KEY
az storage share create --name suitecrm-cache --account-name stsuitecrm --account-key $STORAGE_KEY
```

---

## Step 2: Build and Push Docker Image

```bash
# Build the image
docker build -t acrsuitecrm.azurecr.io/suitecrm:8.8.0 .

# Login to ACR
az acr login --name acrsuitecrm

# Push the image
docker push acrsuitecrm.azurecr.io/suitecrm:8.8.0
```

---

## Step 3: Create Container Apps Environment

```bash
az containerapp env create \
  --resource-group rg-suitecrm \
  --name cae-suitecrm \
  --location eastus
```

### Add Storage Mounts

```bash
# Get storage key
STORAGE_KEY=$(az storage account keys list \
  --resource-group rg-suitecrm \
  --account-name stsuitecrm \
  --query '[0].value' -o tsv)

# Add storage to environment
az containerapp env storage set \
  --resource-group rg-suitecrm \
  --name cae-suitecrm \
  --storage-name suitecrmstorage \
  --azure-file-account-name stsuitecrm \
  --azure-file-account-key $STORAGE_KEY \
  --azure-file-share-name suitecrm-upload \
  --access-mode ReadWrite
```

---

## Step 4: Deploy Container App

```bash
# Get ACR credentials
ACR_USERNAME=$(az acr credential show --name acrsuitecrm --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name acrsuitecrm --query passwords[0].value -o tsv)

# Create the container app
az containerapp create \
  --resource-group rg-suitecrm \
  --name suitecrm \
  --environment cae-suitecrm \
  --image acrsuitecrm.azurecr.io/suitecrm:8.8.0 \
  --registry-server acrsuitecrm.azurecr.io \
  --registry-username $ACR_USERNAME \
  --registry-password $ACR_PASSWORD \
  --target-port 80 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 1 \
  --memory 2Gi \
  --env-vars \
    SUITECRM_RUNTIME_MYSQL_HOST=mysql-suitecrm.mysql.database.azure.com \
    SUITECRM_RUNTIME_MYSQL_PORT=3306 \
    SUITECRM_RUNTIME_MYSQL_NAME=suitecrm \
    SUITECRM_RUNTIME_MYSQL_USER=suitecrm \
    SUITECRM_RUNTIME_MYSQL_SSL_ENABLED=true \
    SUITECRM_RUNTIME_MYSQL_SSL_VERIFY=true \
    SUITECRM_LOG_LEVEL=warning \
    TZ=UTC \
  --secrets \
    database-password='<YOUR_DB_PASSWORD>' \
  --secret-env-vars \
    SUITECRM_RUNTIME_MYSQL_PASSWORD=database-password
```

---

## Step 5: Configure Volume Mounts (YAML Method)

For multiple volume mounts, use a YAML configuration file:

### `suitecrm-containerapp.yaml`

```yaml
properties:
  configuration:
    ingress:
      external: true
      targetPort: 80
    registries:
      - server: acrsuitecrm.azurecr.io
        username: <ACR_USERNAME>
        passwordSecretRef: acr-password
    secrets:
      - name: acr-password
        value: <ACR_PASSWORD>
      - name: database-password
        value: <DB_PASSWORD>
  template:
    containers:
      - name: suitecrm
        image: acrsuitecrm.azurecr.io/suitecrm:8.8.0
        resources:
          cpu: 1
          memory: 2Gi
        env:
          - name: SUITECRM_RUNTIME_MYSQL_HOST
            value: mysql-suitecrm.mysql.database.azure.com
          - name: SUITECRM_RUNTIME_MYSQL_PORT
            value: "3306"
          - name: SUITECRM_RUNTIME_MYSQL_NAME
            value: suitecrm
          - name: SUITECRM_RUNTIME_MYSQL_USER
            value: suitecrm
          - name: SUITECRM_RUNTIME_MYSQL_PASSWORD
            secretRef: database-password
          - name: SUITECRM_RUNTIME_MYSQL_SSL_ENABLED
            value: "true"
          - name: SUITECRM_RUNTIME_MYSQL_SSL_VERIFY
            value: "true"
          - name: SUITECRM_SITE_URL
            value: https://suitecrm.azurecontainerapps.io
          - name: SUITECRM_LOG_LEVEL
            value: warning
          - name: SUITECRM_INSTALLER_LOCKED
            value: "true"
          - name: TZ
            value: UTC
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
    scale:
      minReplicas: 1
      maxReplicas: 3
```

Apply with:

```bash
az containerapp update \
  --resource-group rg-suitecrm \
  --name suitecrm \
  --yaml suitecrm-containerapp.yaml
```

---

## Step 6: Get Application URL

```bash
az containerapp show \
  --resource-group rg-suitecrm \
  --name suitecrm \
  --query properties.configuration.ingress.fqdn -o tsv
```

---

## Environment Variables Reference

| Variable | Description | Default | Azure Value |
|----------|-------------|---------|-------------|
| `SUITECRM_RUNTIME_MYSQL_HOST` | MySQL server hostname | `localhost` | `*.mysql.database.azure.com` |
| `SUITECRM_RUNTIME_MYSQL_PORT` | MySQL port | `3306` | `3306` |
| `SUITECRM_RUNTIME_MYSQL_NAME` | Database name | `suitecrm` | Your DB name |
| `SUITECRM_RUNTIME_MYSQL_USER` | Database user | `suitecrm` | Your DB user |
| `SUITECRM_RUNTIME_MYSQL_PASSWORD` | Database password | - | From Key Vault/Secret |
| `SUITECRM_RUNTIME_MYSQL_SSL_ENABLED` | Enable SSL for MySQL | `true` | `true` |
| `SUITECRM_RUNTIME_MYSQL_SSL_VERIFY` | Verify SSL certificate | `true` | `true` |
| `SUITECRM_SITE_URL` | Public URL of the app | `http://localhost` | Your ACA URL |
| `SUITECRM_LOG_LEVEL` | Log verbosity | `warning` | `warning` |
| `SUITECRM_INSTALLER_LOCKED` | Lock installer | `false` | `true` (after setup) |
| `TZ` | Timezone | `UTC` | Your timezone |

---

## Troubleshooting

### View Logs

```bash
az containerapp logs show \
  --resource-group rg-suitecrm \
  --name suitecrm \
  --follow
```

### Check Container Status

```bash
az containerapp show \
  --resource-group rg-suitecrm \
  --name suitecrm \
  --query properties.runningStatus
```

### Restart Container

```bash
az containerapp revision restart \
  --resource-group rg-suitecrm \
  --name suitecrm
```

---

## Security Recommendations

1. **Use Azure Key Vault** for secrets instead of plain text
2. **Enable HTTPS only** via Container Apps ingress settings
3. **Set `SUITECRM_INSTALLER_LOCKED=true`** after initial setup
4. **Use Private Endpoints** for MySQL and Storage in production
5. **Enable Container Apps authentication** if needed

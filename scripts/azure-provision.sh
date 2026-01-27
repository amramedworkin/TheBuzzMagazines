#!/bin/bash
# ============================================================================
# Azure Resource Provisioning Script for SuiteCRM
# ============================================================================
# Creates: Resource Group, MySQL Flexible Server, Storage Account, File Shares
# Reads configuration from .env file
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================================================
# Load environment variables
# ============================================================================
load_env() {
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error ".env file not found at $ENV_FILE"
        log_info "Copy .env.example to .env and configure your values:"
        log_info "  cp .env.example .env"
        exit 1
    fi

    log_info "Loading configuration from $ENV_FILE"
    
    # Source .env file, handling variable substitution
    set -a
    source "$ENV_FILE"
    set +a

    # Expand nested variables
    AZURE_RESOURCE_GROUP="rg-${AZURE_RESOURCE_PREFIX}-suitecrm"
    AZURE_MYSQL_SERVER_NAME="${AZURE_RESOURCE_PREFIX}-mysql"
    AZURE_STORAGE_ACCOUNT_NAME="${AZURE_RESOURCE_PREFIX}storage"
    AZURE_ACR_NAME="${AZURE_RESOURCE_PREFIX}acr"
    AZURE_CONTAINER_APP_ENV="${AZURE_RESOURCE_PREFIX}-cae"
}

# ============================================================================
# Validate prerequisites
# ============================================================================
validate_prerequisites() {
    log_info "Validating prerequisites..."

    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI (az) is not installed"
        log_info "Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi

    # Check if logged in
    if ! az account show &> /dev/null; then
        log_error "Not logged into Azure CLI"
        log_info "Run: az login"
        exit 1
    fi

    # Validate required variables
    local required_vars=(
        "AZURE_SUBSCRIPTION_ID"
        "AZURE_LOCATION"
        "AZURE_RESOURCE_PREFIX"
        "DATABASE_PASSWORD"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" || "${!var}" == "your-"* || "${!var}" == "CHANGE_ME"* ]]; then
            log_error "Required variable $var is not set or has placeholder value"
            exit 1
        fi
    done

    # Validate storage account name (must be lowercase, no hyphens, 3-24 chars)
    if [[ ! "$AZURE_STORAGE_ACCOUNT_NAME" =~ ^[a-z0-9]{3,24}$ ]]; then
        log_error "AZURE_STORAGE_ACCOUNT_NAME must be 3-24 lowercase letters/numbers only"
        log_error "Current value: $AZURE_STORAGE_ACCOUNT_NAME"
        exit 1
    fi

    log_success "Prerequisites validated"
}

# ============================================================================
# Set Azure subscription
# ============================================================================
set_subscription() {
    log_info "Setting Azure subscription to $AZURE_SUBSCRIPTION_ID"
    az account set --subscription "$AZURE_SUBSCRIPTION_ID"
    log_success "Subscription set"
}

# ============================================================================
# Create Resource Group
# ============================================================================
create_resource_group() {
    log_info "Creating resource group: $AZURE_RESOURCE_GROUP in $AZURE_LOCATION"
    
    if az group show --name "$AZURE_RESOURCE_GROUP" &> /dev/null; then
        log_warn "Resource group $AZURE_RESOURCE_GROUP already exists"
    else
        az group create \
            --name "$AZURE_RESOURCE_GROUP" \
            --location "$AZURE_LOCATION" \
            --output none
        log_success "Resource group created"
    fi
}

# ============================================================================
# Create Azure MySQL Flexible Server
# ============================================================================
create_mysql_server() {
    log_info "Creating Azure MySQL Flexible Server: $AZURE_MYSQL_SERVER_NAME"
    
    if az mysql flexible-server show --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_MYSQL_SERVER_NAME" &> /dev/null; then
        log_warn "MySQL server $AZURE_MYSQL_SERVER_NAME already exists"
    else
        az mysql flexible-server create \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --name "$AZURE_MYSQL_SERVER_NAME" \
            --location "$AZURE_LOCATION" \
            --admin-user "$DATABASE_USER" \
            --admin-password "$DATABASE_PASSWORD" \
            --sku-name "${AZURE_MYSQL_SKU:-Standard_B1ms}" \
            --storage-size "${AZURE_MYSQL_STORAGE_GB:-32}" \
            --version "${AZURE_MYSQL_VERSION:-8.0-lts}" \
            --output none
        log_success "MySQL server created"
    fi

    # Create database
    log_info "Creating database: $DATABASE_NAME"
    if az mysql flexible-server db show --resource-group "$AZURE_RESOURCE_GROUP" --server-name "$AZURE_MYSQL_SERVER_NAME" --database-name "$DATABASE_NAME" &> /dev/null; then
        log_warn "Database $DATABASE_NAME already exists"
    else
        az mysql flexible-server db create \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --server-name "$AZURE_MYSQL_SERVER_NAME" \
            --database-name "$DATABASE_NAME" \
            --output none
        log_success "Database created"
    fi

    # Add firewall rule for current IP (for local development)
    log_info "Adding firewall rule for your current IP..."
    local my_ip
    my_ip=$(curl -s ifconfig.me)
    
    az mysql flexible-server firewall-rule create \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$AZURE_MYSQL_SERVER_NAME" \
        --rule-name "DevMachine-$(date +%Y%m%d)" \
        --start-ip-address "$my_ip" \
        --end-ip-address "$my_ip" \
        --output none 2>/dev/null || true
    log_success "Firewall rule added for IP: $my_ip"

    # Allow Azure services
    log_info "Allowing Azure services to connect..."
    az mysql flexible-server firewall-rule create \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$AZURE_MYSQL_SERVER_NAME" \
        --rule-name "AllowAzureServices" \
        --start-ip-address "0.0.0.0" \
        --end-ip-address "0.0.0.0" \
        --output none 2>/dev/null || true
    log_success "Azure services firewall rule added"
}

# ============================================================================
# Create Azure Storage Account and File Shares
# ============================================================================
create_storage_account() {
    log_info "Creating Azure Storage Account: $AZURE_STORAGE_ACCOUNT_NAME"
    
    if az storage account show --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_STORAGE_ACCOUNT_NAME" &> /dev/null; then
        log_warn "Storage account $AZURE_STORAGE_ACCOUNT_NAME already exists"
    else
        az storage account create \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --name "$AZURE_STORAGE_ACCOUNT_NAME" \
            --location "$AZURE_LOCATION" \
            --sku "${AZURE_STORAGE_SKU:-Standard_LRS}" \
            --kind StorageV2 \
            --output none
        log_success "Storage account created"
    fi

    # Get storage key
    log_info "Retrieving storage account key..."
    local storage_key
    storage_key=$(az storage account keys list \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --account-name "$AZURE_STORAGE_ACCOUNT_NAME" \
        --query '[0].value' -o tsv)

    # Create file shares
    local shares=("suitecrm-upload" "suitecrm-custom" "suitecrm-cache")
    for share in "${shares[@]}"; do
        log_info "Creating file share: $share"
        az storage share create \
            --name "$share" \
            --account-name "$AZURE_STORAGE_ACCOUNT_NAME" \
            --account-key "$storage_key" \
            --output none 2>/dev/null || log_warn "File share $share may already exist"
    done
    log_success "File shares created"

    # Save storage key to a secure file
    local secrets_file="${PROJECT_ROOT}/.azure-secrets"
    echo "AZURE_STORAGE_KEY=$storage_key" > "$secrets_file"
    chmod 600 "$secrets_file"
    log_success "Storage key saved to $secrets_file"
}

# ============================================================================
# Create Azure Container Registry (optional, for later deployment)
# ============================================================================
create_container_registry() {
    log_info "Creating Azure Container Registry: $AZURE_ACR_NAME"
    
    if az acr show --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_ACR_NAME" &> /dev/null; then
        log_warn "Container Registry $AZURE_ACR_NAME already exists"
    else
        az acr create \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --name "$AZURE_ACR_NAME" \
            --sku "${AZURE_ACR_SKU:-Basic}" \
            --admin-enabled true \
            --output none
        log_success "Container Registry created"
    fi
}

# ============================================================================
# Output connection information
# ============================================================================
output_connection_info() {
    echo ""
    echo "============================================================================"
    echo -e "${GREEN}Azure Resources Created Successfully${NC}"
    echo "============================================================================"
    echo ""
    echo "MySQL Connection Details:"
    echo "  Host:     ${AZURE_MYSQL_SERVER_NAME}.mysql.database.azure.com"
    echo "  Port:     3306"
    echo "  Database: ${DATABASE_NAME}"
    echo "  User:     ${DATABASE_USER}"
    echo "  SSL:      Required"
    echo ""
    echo "Storage Account:"
    echo "  Name:     ${AZURE_STORAGE_ACCOUNT_NAME}"
    echo "  Shares:   suitecrm-upload, suitecrm-custom, suitecrm-cache"
    echo ""
    echo "Container Registry:"
    echo "  Name:     ${AZURE_ACR_NAME}.azurecr.io"
    echo ""
    echo "============================================================================"
    echo "Next Steps:"
    echo "============================================================================"
    echo ""
    echo "1. Mount Azure Files locally:"
    echo "   ./scripts/azure-mount.sh"
    echo ""
    echo "2. Build and run Docker container:"
    echo "   docker compose up --build -d"
    echo ""
    echo "3. Access SuiteCRM:"
    echo "   http://localhost"
    echo ""
    echo "============================================================================"
}

# ============================================================================
# Main
# ============================================================================
main() {
    echo ""
    echo "============================================================================"
    echo "Azure Resource Provisioning for SuiteCRM"
    echo "============================================================================"
    echo ""

    load_env
    validate_prerequisites
    set_subscription
    create_resource_group
    create_mysql_server
    create_storage_account
    create_container_registry
    output_connection_info
}

# Run main function
main "$@"

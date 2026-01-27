#!/bin/bash
# ============================================================================
# Azure Resource Provisioning Script for SuiteCRM
# ============================================================================
# Creates: Resource Group, MySQL Flexible Server, Storage Account, File Shares
# Reads configuration from .env file
#
# Usage:
#   ./azure-provision.sh          # Interactive mode (default)
#   ./azure-provision.sh -y       # Non-interactive mode
#   ./azure-provision.sh --yes    # Non-interactive mode
# ============================================================================

# ============================================================================
# SCRIPT CONFIGURATION
# ============================================================================

SCRIPT_NAME="azure-provision"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"
SECRETS_FILE="${PROJECT_ROOT}/.azure-secrets"
LOGS_DIR="${PROJECT_ROOT}/logs"

# Interactive mode (default: true, requires user confirmation at each step)
INTERACTIVE_MODE=true

# Track overall success
SCRIPT_SUCCESS=true
FAILED_STEP=""

# ============================================================================
# LOGGING SETUP
# ============================================================================

setup_logging() {
    # Ensure logs directory exists
    mkdir -p "$LOGS_DIR"
    
    # Generate timestamp in Eastern US timezone
    local timestamp
    timestamp=$(TZ="America/New_York" date +"%Y%m%d_%H%M%S")
    
    # New log filename
    LOG_FILE="${LOGS_DIR}/latest_${SCRIPT_NAME}_${timestamp}.log"
    
    # Strip "latest_" prefix from any previous log files for this script
    for old_log in "${LOGS_DIR}"/latest_${SCRIPT_NAME}_*.log; do
        if [[ -f "$old_log" && "$old_log" != "$LOG_FILE" ]]; then
            local new_name="${old_log/latest_/}"
            mv "$old_log" "$new_name" 2>/dev/null || true
        fi
    done
    
    # Create the new log file
    touch "$LOG_FILE"
    
    # Log header
    {
        echo "============================================================================"
        echo "Azure Provision Log - Started at $(TZ='America/New_York' date)"
        echo "Timezone: America/New_York (Eastern US)"
        echo "Interactive Mode: $INTERACTIVE_MODE"
        echo "============================================================================"
        echo ""
    } >> "$LOG_FILE"
}

# Log to both console and file
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(TZ="America/New_York" date +"%Y-%m-%d %H:%M:%S %Z")
    local log_line="[$timestamp] [$level] $message"
    
    echo "$log_line" >> "$LOG_FILE"
    
    # Console output with colors
    case "$level" in
        INFO)    echo -e "\033[0;34m[INFO]\033[0m $message" ;;
        SUCCESS) echo -e "\033[0;32m[SUCCESS]\033[0m $message" ;;
        WARN)    echo -e "\033[1;33m[WARN]\033[0m $message" ;;
        ERROR)   echo -e "\033[0;31m[ERROR]\033[0m $message" ;;
        STEP)    echo -e "\033[1;36m[STEP]\033[0m $message" ;;
        *)       echo "$message" ;;
    esac
}

log_info() { log "INFO" "$1"; }
log_success() { log "SUCCESS" "$1"; }
log_warn() { log "WARN" "$1"; }
log_error() { log "ERROR" "$1"; }
log_step() { log "STEP" "$1"; }

# Log command output (to file only)
log_cmd_output() {
    echo "$1" >> "$LOG_FILE"
}

# ============================================================================
# ERROR HANDLING
# ============================================================================

handle_error() {
    local step="$1"
    local error_msg="$2"
    local exit_code="${3:-1}"
    
    SCRIPT_SUCCESS=false
    FAILED_STEP="$step"
    
    log_error "Step '$step' failed with exit code $exit_code"
    log_error "Error: $error_msg"
    
    # Log diagnostic information
    {
        echo ""
        echo "============================================================================"
        echo "FAILURE DIAGNOSTICS"
        echo "============================================================================"
        echo "Failed Step: $step"
        echo "Exit Code: $exit_code"
        echo "Error Message: $error_msg"
        echo "Timestamp: $(TZ='America/New_York' date)"
        echo ""
        echo "Possible causes:"
    } >> "$LOG_FILE"
    
    # Try to diagnose common issues
    case "$step" in
        "validate_prerequisites")
            echo "  - Azure CLI not installed" >> "$LOG_FILE"
            echo "  - Not logged into Azure (run: az login)" >> "$LOG_FILE"
            ;;
        "set_subscription")
            echo "  - Invalid subscription ID" >> "$LOG_FILE"
            echo "  - Subscription not accessible with current credentials" >> "$LOG_FILE"
            ;;
        "create_resource_group")
            echo "  - Insufficient permissions to create resource groups" >> "$LOG_FILE"
            echo "  - Invalid location specified" >> "$LOG_FILE"
            ;;
        "create_mysql_server")
            echo "  - Server name already taken globally" >> "$LOG_FILE"
            echo "  - Password doesn't meet complexity requirements" >> "$LOG_FILE"
            echo "  - Quota exceeded for MySQL servers" >> "$LOG_FILE"
            ;;
        "create_storage_account")
            echo "  - Storage account name already taken globally" >> "$LOG_FILE"
            echo "  - Invalid storage account name (must be 3-24 lowercase alphanumeric)" >> "$LOG_FILE"
            ;;
        "create_container_registry")
            echo "  - ACR name already taken globally" >> "$LOG_FILE"
            echo "  - Quota exceeded for container registries" >> "$LOG_FILE"
            ;;
        *)
            echo "  - Unknown error - check Azure portal for details" >> "$LOG_FILE"
            ;;
    esac
    
    echo "" >> "$LOG_FILE"
    echo "Log file: $LOG_FILE" >> "$LOG_FILE"
    
    echo ""
    log_error "Provisioning failed at step: $step"
    log_error "See log file for details: $LOG_FILE"
    echo ""
    
    exit "$exit_code"
}

# ============================================================================
# INTERACTIVE MODE HELPERS
# ============================================================================

confirm_step() {
    local step_name="$1"
    local step_description="$2"
    
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        echo ""
        echo -e "\033[1;33m>>> Next Step: $step_name\033[0m"
        echo "    $step_description"
        echo ""
        read -p "    Press Enter to continue, or Ctrl+C to abort... " -r
        echo ""
    fi
    
    log_step "Starting: $step_name"
}

# ============================================================================
# PARSE COMMAND LINE ARGUMENTS
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes)
                INTERACTIVE_MODE=false
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [-y|--yes]"
                echo ""
                echo "Options:"
                echo "  -y, --yes    Run without prompting for confirmation at each step"
                echo "  -h, --help   Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# VALIDATE ENVIRONMENT FILE
# ============================================================================

validate_env_file() {
    confirm_step "Validate Environment" "Check .env file for required values and placeholders"
    
    log_info "Running environment validation..."
    
    local validate_script="${SCRIPT_DIR}/validate-env.sh"
    
    if [[ ! -f "$validate_script" ]]; then
        handle_error "validate_env_file" "validate-env.sh not found at $validate_script"
    fi
    
    # Run full validation for logging purposes (capture all output)
    local full_validation_output
    full_validation_output=$("$validate_script" 2>&1) || true
    
    # Log the full validation output
    {
        echo ""
        echo "--- Environment Validation Results ---"
        echo "$full_validation_output"
        echo "--- End Validation Results ---"
        echo ""
    } >> "$LOG_FILE"
    
    # Run validation in errors-only mode for console output
    local validation_output
    if ! validation_output=$("$validate_script" --errors-only 2>&1); then
        # Show errors on console
        if [[ -n "$validation_output" ]]; then
            echo "$validation_output"
        fi
        handle_error "validate_env_file" "Environment validation failed. Please fix the errors in your .env file before proceeding."
    fi
    
    log_success "Environment validation passed"
}

# ============================================================================
# LOAD ENVIRONMENT VARIABLES
# ============================================================================

load_env() {
    if [[ ! -f "$ENV_FILE" ]]; then
        handle_error "load_env" ".env file not found at $ENV_FILE. Copy .env.example to .env and configure your values."
    fi

    log_info "Loading configuration from $ENV_FILE"
    
    # Source .env file, handling variable substitution
    set -a
    source "$ENV_FILE"
    set +a

    # Expand nested variables
    AZURE_RESOURCE_GROUP="rg-${AZURE_RESOURCE_PREFIX}-suitecrm"
    AZURE_PROVISION_MYSQL_SERVER_NAME="${AZURE_RESOURCE_PREFIX}-mysql"
    AZURE_STORAGE_ACCOUNT_NAME="${AZURE_RESOURCE_PREFIX}storage"
    AZURE_ACR_NAME="${AZURE_RESOURCE_PREFIX}acr"
    AZURE_CONTAINER_APP_ENV="${AZURE_RESOURCE_PREFIX}-cae"
    
    log_info "Resource prefix: $AZURE_RESOURCE_PREFIX"
    log_info "Resource group: $AZURE_RESOURCE_GROUP"
    log_info "Location: $AZURE_LOCATION"
    
    log_success "Environment loaded"
}

# ============================================================================
# VALIDATE PREREQUISITES
# ============================================================================

validate_prerequisites() {
    confirm_step "Validate Prerequisites" "Check Azure CLI installation and login status"
    
    log_info "Checking Azure CLI installation..."
    if ! command -v az &> /dev/null; then
        handle_error "validate_prerequisites" "Azure CLI (az) is not installed. Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    fi
    log_success "Azure CLI is installed"

    log_info "Checking Azure login status..."
    local account_output
    if ! account_output=$(az account show 2>&1); then
        log_cmd_output "$account_output"
        handle_error "validate_prerequisites" "Not logged into Azure CLI. Run: az login"
    fi
    log_cmd_output "$account_output"
    log_success "Logged into Azure"

    log_info "Validating required environment variables..."
    local required_vars=(
        "AZURE_SUBSCRIPTION_ID"
        "AZURE_LOCATION"
        "AZURE_RESOURCE_PREFIX"
        "SUITECRM_RUNTIME_MYSQL_PASSWORD"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" || "${!var}" == "your-"* || "${!var}" == "CHANGE_ME"* ]]; then
            handle_error "validate_prerequisites" "Required variable $var is not set or has placeholder value in .env"
        fi
        log_info "  ✓ $var is set"
    done

    # Validate storage account name
    if [[ ! "$AZURE_STORAGE_ACCOUNT_NAME" =~ ^[a-z0-9]{3,24}$ ]]; then
        handle_error "validate_prerequisites" "AZURE_STORAGE_ACCOUNT_NAME must be 3-24 lowercase letters/numbers only. Current: $AZURE_STORAGE_ACCOUNT_NAME"
    fi
    log_info "  ✓ Storage account name format is valid"

    log_success "All prerequisites validated"
}

# ============================================================================
# SET AZURE SUBSCRIPTION
# ============================================================================

set_subscription() {
    confirm_step "Set Subscription" "Configure Azure CLI to use subscription: $AZURE_SUBSCRIPTION_ID"
    
    log_info "Setting Azure subscription..."
    
    local output
    if ! output=$(az account set --subscription "$AZURE_SUBSCRIPTION_ID" 2>&1); then
        log_cmd_output "$output"
        handle_error "set_subscription" "Failed to set subscription. Verify AZURE_SUBSCRIPTION_ID is correct."
    fi
    log_cmd_output "$output"
    
    log_success "Subscription set to: $AZURE_SUBSCRIPTION_ID"
}

# ============================================================================
# CREATE RESOURCE GROUP
# ============================================================================

create_resource_group() {
    confirm_step "Create Resource Group" "Create resource group '$AZURE_RESOURCE_GROUP' in '$AZURE_LOCATION'"
    
    log_info "Checking if resource group exists..."
    
    local output
    if az group show --name "$AZURE_RESOURCE_GROUP" &> /dev/null; then
        log_warn "Resource group $AZURE_RESOURCE_GROUP already exists - skipping creation"
        return 0
    fi
    
    log_info "Creating resource group..."
    if ! output=$(az group create \
        --name "$AZURE_RESOURCE_GROUP" \
        --location "$AZURE_LOCATION" \
        --output json 2>&1); then
        log_cmd_output "$output"
        handle_error "create_resource_group" "Failed to create resource group"
    fi
    log_cmd_output "$output"
    
    log_success "Resource group '$AZURE_RESOURCE_GROUP' created in '$AZURE_LOCATION'"
}

# ============================================================================
# CREATE AZURE MYSQL FLEXIBLE SERVER
# ============================================================================

create_mysql_server() {
    confirm_step "Create MySQL Server" "Create Azure MySQL Flexible Server '$AZURE_PROVISION_MYSQL_SERVER_NAME'"
    
    log_info "Checking if MySQL server exists..."
    
    local output
    if az mysql flexible-server show --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_PROVISION_MYSQL_SERVER_NAME" &> /dev/null; then
        log_warn "MySQL server $AZURE_PROVISION_MYSQL_SERVER_NAME already exists - skipping creation"
    else
        log_info "Creating MySQL Flexible Server (this may take 5-10 minutes)..."
        log_info "  Server: $AZURE_PROVISION_MYSQL_SERVER_NAME"
        log_info "  SKU: ${AZURE_PROVISION_MYSQL_SKU:-Standard_B1ms}"
        log_info "  Storage: ${AZURE_PROVISION_MYSQL_STORAGE_GB:-32}GB"
        log_info "  Version: ${AZURE_PROVISION_MYSQL_VERSION:-8.0-lts}"
        
        if ! output=$(az mysql flexible-server create \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --name "$AZURE_PROVISION_MYSQL_SERVER_NAME" \
            --location "$AZURE_LOCATION" \
            --admin-user "$SUITECRM_RUNTIME_MYSQL_USER" \
            --admin-password "$SUITECRM_RUNTIME_MYSQL_PASSWORD" \
            --sku-name "${AZURE_PROVISION_MYSQL_SKU:-Standard_B1ms}" \
            --storage-size "${AZURE_PROVISION_MYSQL_STORAGE_GB:-32}" \
            --version "${AZURE_PROVISION_MYSQL_VERSION:-8.0-lts}" \
            --output json 2>&1); then
            log_cmd_output "$output"
            handle_error "create_mysql_server" "Failed to create MySQL server. Check password complexity and server name availability."
        fi
        log_cmd_output "$output"
        log_success "MySQL server created"
    fi

    # Create database
    log_info "Checking if database '$SUITECRM_RUNTIME_MYSQL_NAME' exists..."
    if az mysql flexible-server db show --resource-group "$AZURE_RESOURCE_GROUP" --server-name "$AZURE_PROVISION_MYSQL_SERVER_NAME" --database-name "$SUITECRM_RUNTIME_MYSQL_NAME" &> /dev/null; then
        log_warn "Database $SUITECRM_RUNTIME_MYSQL_NAME already exists - skipping creation"
    else
        log_info "Creating database '$SUITECRM_RUNTIME_MYSQL_NAME'..."
        if ! output=$(az mysql flexible-server db create \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --server-name "$AZURE_PROVISION_MYSQL_SERVER_NAME" \
            --database-name "$SUITECRM_RUNTIME_MYSQL_NAME" \
            --output json 2>&1); then
            log_cmd_output "$output"
            handle_error "create_mysql_server" "Failed to create database"
        fi
        log_cmd_output "$output"
        log_success "Database '$SUITECRM_RUNTIME_MYSQL_NAME' created"
    fi

    # Add firewall rule for current IP
    log_info "Adding firewall rule for your current IP..."
    local my_ip
    my_ip=$(curl -s ifconfig.me)
    log_info "  Your IP: $my_ip"
    
    if ! output=$(az mysql flexible-server firewall-rule create \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$AZURE_PROVISION_MYSQL_SERVER_NAME" \
        --rule-name "DevMachine-$(date +%Y%m%d)" \
        --start-ip-address "$my_ip" \
        --end-ip-address "$my_ip" \
        --output json 2>&1); then
        log_warn "Firewall rule may already exist or failed to create"
        log_cmd_output "$output"
    else
        log_cmd_output "$output"
        log_success "Firewall rule added for IP: $my_ip"
    fi

    # Allow Azure services
    log_info "Allowing Azure services to connect..."
    if ! output=$(az mysql flexible-server firewall-rule create \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$AZURE_PROVISION_MYSQL_SERVER_NAME" \
        --rule-name "AllowAzureServices" \
        --start-ip-address "0.0.0.0" \
        --end-ip-address "0.0.0.0" \
        --output json 2>&1); then
        log_warn "Azure services firewall rule may already exist"
        log_cmd_output "$output"
    else
        log_cmd_output "$output"
        log_success "Azure services firewall rule added"
    fi

    log_success "MySQL server setup complete"
}

# ============================================================================
# CREATE AZURE STORAGE ACCOUNT AND FILE SHARES
# ============================================================================

create_storage_account() {
    confirm_step "Create Storage Account" "Create Azure Storage Account '$AZURE_STORAGE_ACCOUNT_NAME' with file shares"
    
    log_info "Checking if storage account exists..."
    
    local output
    if az storage account show --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_STORAGE_ACCOUNT_NAME" &> /dev/null; then
        log_warn "Storage account $AZURE_STORAGE_ACCOUNT_NAME already exists - skipping creation"
    else
        log_info "Creating storage account..."
        if ! output=$(az storage account create \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --name "$AZURE_STORAGE_ACCOUNT_NAME" \
            --location "$AZURE_LOCATION" \
            --sku "${AZURE_STORAGE_SKU:-Standard_LRS}" \
            --kind StorageV2 \
            --output json 2>&1); then
            log_cmd_output "$output"
            handle_error "create_storage_account" "Failed to create storage account. Name may be taken globally."
        fi
        log_cmd_output "$output"
        log_success "Storage account created"
    fi

    # Get storage key
    log_info "Retrieving storage account key..."
    local storage_key
    if ! storage_key=$(az storage account keys list \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --account-name "$AZURE_STORAGE_ACCOUNT_NAME" \
        --query '[0].value' -o tsv 2>&1); then
        log_cmd_output "$storage_key"
        handle_error "create_storage_account" "Failed to retrieve storage account key"
    fi
    log_success "Storage key retrieved"

    # Create file shares
    local shares=("suitecrm-upload" "suitecrm-custom" "suitecrm-cache")
    for share in "${shares[@]}"; do
        log_info "Creating file share: $share"
        if ! output=$(az storage share create \
            --name "$share" \
            --account-name "$AZURE_STORAGE_ACCOUNT_NAME" \
            --account-key "$storage_key" \
            --output json 2>&1); then
            log_warn "File share $share may already exist"
            log_cmd_output "$output"
        else
            log_cmd_output "$output"
            log_success "File share '$share' created"
        fi
    done

    # Save storage key to secrets file
    log_info "Saving storage key to $SECRETS_FILE..."
    echo "AZURE_STORAGE_KEY=$storage_key" > "$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
    log_success "Storage key saved securely"

    log_success "Storage account setup complete"
}

# ============================================================================
# CREATE AZURE CONTAINER REGISTRY
# ============================================================================

create_container_registry() {
    confirm_step "Create Container Registry" "Create Azure Container Registry '$AZURE_ACR_NAME'"
    
    log_info "Checking if container registry exists..."
    
    local output
    if az acr show --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_ACR_NAME" &> /dev/null; then
        log_warn "Container Registry $AZURE_ACR_NAME already exists - skipping creation"
    else
        log_info "Creating container registry..."
        if ! output=$(az acr create \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --name "$AZURE_ACR_NAME" \
            --sku "${AZURE_ACR_SKU:-Basic}" \
            --admin-enabled true \
            --output json 2>&1); then
            log_cmd_output "$output"
            handle_error "create_container_registry" "Failed to create container registry. Name may be taken globally."
        fi
        log_cmd_output "$output"
        log_success "Container registry created"
    fi

    log_success "Container registry setup complete"
}

# ============================================================================
# OUTPUT CONNECTION INFORMATION
# ============================================================================

output_connection_info() {
    local summary
    summary=$(cat << EOF

============================================================================
Azure Resources Provisioned Successfully
============================================================================

MySQL Connection Details:
  Host:     ${AZURE_PROVISION_MYSQL_SERVER_NAME}.mysql.database.azure.com
  Port:     3306
  Database: ${SUITECRM_RUNTIME_MYSQL_NAME}
  User:     ${SUITECRM_RUNTIME_MYSQL_USER}
  SSL:      Required

Storage Account:
  Name:     ${AZURE_STORAGE_ACCOUNT_NAME}
  Shares:   suitecrm-upload, suitecrm-custom, suitecrm-cache

Container Registry:
  Name:     ${AZURE_ACR_NAME}.azurecr.io

============================================================================
Next Steps:
============================================================================

1. Mount Azure Files locally:
   sudo ./scripts/azure-mount.sh

2. Build and run Docker container:
   docker compose up --build -d

3. Access SuiteCRM:
   http://localhost

Log file: $LOG_FILE

============================================================================
EOF
)
    
    echo "$summary"
    echo "$summary" >> "$LOG_FILE"
}

# ============================================================================
# FINALIZE LOGGING
# ============================================================================

finalize_log() {
    {
        echo ""
        echo "============================================================================"
        echo "SCRIPT COMPLETED"
        echo "============================================================================"
        echo "End Time: $(TZ='America/New_York' date)"
        echo "Success: $SCRIPT_SUCCESS"
        if [[ "$SCRIPT_SUCCESS" == "false" ]]; then
            echo "Failed Step: $FAILED_STEP"
        fi
        echo "============================================================================"
    } >> "$LOG_FILE"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Setup logging first
    setup_logging
    
    echo ""
    echo "============================================================================"
    echo "Azure Resource Provisioning for SuiteCRM"
    echo "============================================================================"
    echo "Log file: $LOG_FILE"
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        echo "Mode: Interactive (press Enter at each step, Ctrl+C to abort)"
    else
        echo "Mode: Non-interactive (running all steps automatically)"
    fi
    echo ""

    # Trap to ensure we finalize the log even on error
    trap finalize_log EXIT

    # Run provisioning steps
    load_env
    validate_env_file
    validate_prerequisites
    set_subscription
    create_resource_group
    create_mysql_server
    create_storage_account
    create_container_registry
    output_connection_info
    
    log_success "All provisioning steps completed successfully!"
}

# Run main function
main "$@"

#!/bin/bash
# ============================================================================
# Azure Infrastructure Teardown Script
# ============================================================================
# Deletes Azure resources created by azure-provision-infra.sh
# Reads ALL resource names from .env file - single source of truth
#
# Usage:
#   ./azure-teardown-infra.sh          # Interactive mode (default)
#   ./azure-teardown-infra.sh -y       # Non-interactive mode
# ============================================================================

# ============================================================================
# SCRIPT CONFIGURATION
# ============================================================================

SCRIPT_NAME="azure-teardown-infra"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"
LOGS_DIR="${PROJECT_ROOT}/logs"

# Interactive mode (default: true)
INTERACTIVE_MODE=true

# Track results for summary
RESULTS=()

# ============================================================================
# LOGGING SETUP
# ============================================================================

setup_logging() {
    mkdir -p "$LOGS_DIR"
    local timestamp
    timestamp=$(TZ="America/New_York" date +"%Y%m%d_%H%M%S")
    LOG_FILE="${LOGS_DIR}/latest_${SCRIPT_NAME}_${timestamp}.log"
    
    # Strip "latest_" prefix from previous logs
    for old_log in "${LOGS_DIR}"/latest_${SCRIPT_NAME}_*.log; do
        if [[ -f "$old_log" && "$old_log" != "$LOG_FILE" ]]; then
            local new_name="${old_log/latest_/}"
            mv "$old_log" "$new_name" 2>/dev/null || true
        fi
    done
    
    touch "$LOG_FILE"
    {
        echo "============================================================================"
        echo "Azure Teardown Log - Started at $(TZ='America/New_York' date)"
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
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        INFO)    echo -e "\033[0;34m[INFO]\033[0m $message" ;;
        SUCCESS) echo -e "\033[0;32m[SUCCESS]\033[0m $message"; RESULTS+=("\033[0;32m✔\033[0m $message") ;;
        WARN)    echo -e "\033[1;33m[WARN]\033[0m $message" ;;
        ERROR)   echo -e "\033[0;31m[ERROR]\033[0m $message"; RESULTS+=("\033[0;31m✘\033[0m $message") ;;
        STEP)    echo -e "\033[1;36m[STEP]\033[0m $message" ;;
        SKIP)    echo -e "\033[1;33m[SKIP]\033[0m $message"; RESULTS+=("\033[1;33m○\033[0m $message (Not Found)") ;;
        *)       echo "$message" ;;
    esac
}

log_info() { log "INFO" "$1"; }
log_success() { log "SUCCESS" "$1"; }
log_warn() { log "WARN" "$1"; }
log_error() { log "ERROR" "$1"; }
log_step() { log "STEP" "$1"; }
log_skip() { log "SKIP" "$1"; }

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
                echo "  -y, --yes    Run without prompting for confirmation"
                echo "  -h, --help   Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# LOAD ENVIRONMENT VARIABLES
# ============================================================================

load_env() {
    log_step "Loading environment configuration..."
    
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "Missing .env file at $ENV_FILE"
        exit 1
    fi

    # Source .env file
    set -a
    source "$ENV_FILE"
    set +a

    # Expand nested variables from .env (they use ${AZURE_RESOURCE_PREFIX})
    eval "AZURE_RESOURCE_GROUP=$AZURE_RESOURCE_GROUP"
    eval "AZURE_PROVISION_MYSQL_SERVER_NAME=$AZURE_PROVISION_MYSQL_SERVER_NAME"
    eval "AZURE_STORAGE_ACCOUNT_NAME=$AZURE_STORAGE_ACCOUNT_NAME"
    eval "AZURE_ACR_NAME=$AZURE_ACR_NAME"
    eval "AZURE_CONTAINER_APP_ENV=$AZURE_CONTAINER_APP_ENV"
    
    log_info "Resource Group: $AZURE_RESOURCE_GROUP"
    log_info "MySQL Server: $AZURE_PROVISION_MYSQL_SERVER_NAME"
    log_info "Storage Account: $AZURE_STORAGE_ACCOUNT_NAME"
    log_info "Container Registry: $AZURE_ACR_NAME"
    log_success "Environment loaded from .env"
}

# ============================================================================
# VALIDATE PREREQUISITES
# ============================================================================

validate_prerequisites() {
    log_step "Checking Azure Authentication..."
    
    if ! az account show &>/dev/null; then
        log_error "Not logged in. Run 'az login' first."
        exit 1
    fi
    log_success "Authenticated to Azure"
}

# ============================================================================
# INTERACTIVE CONFIRMATION
# ============================================================================

confirm_teardown() {
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        echo ""
        echo -e "\033[1;31m========================================\033[0m"
        echo -e "\033[1;31m           !!! WARNING !!!              \033[0m"
        echo -e "\033[1;31m========================================\033[0m"
        echo ""
        echo "This will PERMANENTLY DELETE the following Azure resources:"
        echo ""
        echo "  Resource Group:     $AZURE_RESOURCE_GROUP"
        echo "  MySQL Server:       $AZURE_PROVISION_MYSQL_SERVER_NAME"
        echo "  Storage Account:    $AZURE_STORAGE_ACCOUNT_NAME"
        echo "  Container Registry: $AZURE_ACR_NAME"
        echo ""
        echo "ALL DATA WILL BE LOST and cannot be recovered!"
        echo ""
        read -p "Type 'DELETE' to confirm: " -r confirmation
        echo ""
        
        if [[ "$confirmation" != "DELETE" ]]; then
            log_info "Teardown cancelled by user"
            exit 0
        fi
    fi
}

# ============================================================================
# DELETE MYSQL SERVER
# ============================================================================

delete_mysql_server() {
    log_step "Deleting MySQL Flexible Server '$AZURE_PROVISION_MYSQL_SERVER_NAME'..."
    
    if az mysql flexible-server show \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$AZURE_PROVISION_MYSQL_SERVER_NAME" &>/dev/null; then
        
        if az mysql flexible-server delete \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --name "$AZURE_PROVISION_MYSQL_SERVER_NAME" \
            --yes 2>&1 | tee -a "$LOG_FILE"; then
            log_success "MySQL Server '$AZURE_PROVISION_MYSQL_SERVER_NAME' deleted"
        else
            log_error "Failed to delete MySQL Server '$AZURE_PROVISION_MYSQL_SERVER_NAME'"
        fi
    else
        log_skip "MySQL Server '$AZURE_PROVISION_MYSQL_SERVER_NAME' does not exist"
    fi
}

# ============================================================================
# DELETE STORAGE ACCOUNT
# ============================================================================

delete_storage_account() {
    log_step "Deleting Storage Account '$AZURE_STORAGE_ACCOUNT_NAME'..."
    
    if az storage account show \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$AZURE_STORAGE_ACCOUNT_NAME" &>/dev/null; then
        
        if az storage account delete \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --name "$AZURE_STORAGE_ACCOUNT_NAME" \
            --yes 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Storage Account '$AZURE_STORAGE_ACCOUNT_NAME' deleted"
        else
            log_error "Failed to delete Storage Account '$AZURE_STORAGE_ACCOUNT_NAME'"
        fi
    else
        log_skip "Storage Account '$AZURE_STORAGE_ACCOUNT_NAME' does not exist"
    fi
}

# ============================================================================
# DELETE CONTAINER REGISTRY
# ============================================================================

delete_container_registry() {
    log_step "Deleting Container Registry '$AZURE_ACR_NAME'..."
    
    if az acr show \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$AZURE_ACR_NAME" &>/dev/null; then
        
        if az acr delete \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --name "$AZURE_ACR_NAME" \
            --yes 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Container Registry '$AZURE_ACR_NAME' deleted"
        else
            log_error "Failed to delete Container Registry '$AZURE_ACR_NAME'"
        fi
    else
        log_skip "Container Registry '$AZURE_ACR_NAME' does not exist"
    fi
}

# ============================================================================
# DELETE RESOURCE GROUP (CASCADING)
# ============================================================================

delete_resource_group() {
    log_step "Deleting Resource Group '$AZURE_RESOURCE_GROUP' (cascading deletion)..."
    
    if az group show --name "$AZURE_RESOURCE_GROUP" &>/dev/null; then
        log_info "This will delete any remaining resources in the group..."
        
        if az group delete \
            --name "$AZURE_RESOURCE_GROUP" \
            --yes 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Resource Group '$AZURE_RESOURCE_GROUP' and all contents deleted"
        else
            log_error "Failed to delete Resource Group '$AZURE_RESOURCE_GROUP'"
        fi
    else
        log_skip "Resource Group '$AZURE_RESOURCE_GROUP' does not exist"
    fi
}

# ============================================================================
# OUTPUT SUMMARY
# ============================================================================

output_summary() {
    echo ""
    echo "============================================================================"
    echo "                       TEARDOWN RESULTS SUMMARY"
    echo "============================================================================"
    for res in "${RESULTS[@]}"; do
        echo -e "  $res"
    done
    echo "============================================================================"
    echo ""
    echo "Log file: $LOG_FILE"
    echo ""
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
        echo "============================================================================"
    } >> "$LOG_FILE"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    parse_args "$@"
    setup_logging
    
    echo ""
    echo "============================================================================"
    echo "Azure Infrastructure Teardown"
    echo "============================================================================"
    echo "Log file: $LOG_FILE"
    echo ""
    
    trap finalize_log EXIT
    
    load_env
    validate_prerequisites
    confirm_teardown
    
    # Delete individual resources first (handles dependency locks)
    delete_mysql_server
    delete_storage_account
    delete_container_registry
    
    # Final resource group deletion (cascading - catches anything missed)
    delete_resource_group
    
    output_summary
}

main "$@"

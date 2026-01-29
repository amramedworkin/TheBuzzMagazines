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

# Source common utilities (colors, logging, etc.)
source "$SCRIPT_DIR/lib/common.sh"

# Interactive mode (default: true)
INTERACTIVE_MODE=true

# Track results for summary
declare -a RESULTS

# ============================================================================
# CUSTOM LOGGING (extends common.sh to track RESULTS)
# ============================================================================
# Override log function to also track results for summary display

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(TZ="${LOGGING_TZ:-America/New_York}" date +"%Y-%m-%d %H:%M:%S %Z")
    
    # Always write to log file
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
    
    # Track results for summary (always)
    case "$level" in
        SUCCESS) RESULTS+=("${GREEN}✔${NC} $message") ;;
        ERROR)   RESULTS+=("${RED}✘${NC} $message") ;;
        SKIP)    RESULTS+=("${YELLOW}○${NC} $message (Not Found)") ;;
    esac
    
    # Console output controlled by VERBOSE_MODE
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        case "$level" in
            INFO)    echo -e "${BLUE}[INFO]${NC} $message" ;;
            SUCCESS) echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
            WARN)    echo -e "${YELLOW}[WARN]${NC} $message" ;;
            ERROR)   echo -e "${RED}[ERROR]${NC} $message" ;;
            STEP)    echo -e "${CYAN}[STEP]${NC} $message" ;;
            SKIP)    echo -e "${YELLOW}[SKIP]${NC} $message" ;;
            ACTION)  echo -e "$message" ;;
            *)       echo "$message" ;;
        esac
    else
        # Simple mode: only show errors, warnings, and ACTION results
        case "$level" in
            ERROR)   echo -e "${RED}[ERROR]${NC} $message" ;;
            WARN)    echo -e "${YELLOW}[WARN]${NC} $message" ;;
            ACTION)  echo -e "$message" ;;
        esac
    fi
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
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [-y|--yes] [-v|--verbose]"
                echo ""
                echo "Options:"
                echo "  -y, --yes      Run without prompting for confirmation"
                echo "  -v, --verbose  Show detailed logging output"
                echo "  -h, --help     Show this help message"
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

    # Use common environment loading (handles all variable expansion)
    load_env_common
    
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
        echo -e "${RED}${BOLD}========================================${NC}"
        echo -e "${RED}${BOLD}           !!! WARNING !!!              ${NC}"
        echo -e "${RED}${BOLD}========================================${NC}"
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
            log_action "MySQL Server '$AZURE_PROVISION_MYSQL_SERVER_NAME'" "succeeded" "deleted"
        else
            log_error "Failed to delete MySQL Server '$AZURE_PROVISION_MYSQL_SERVER_NAME'"
            log_action "MySQL Server '$AZURE_PROVISION_MYSQL_SERVER_NAME'" "failed"
        fi
    else
        log_skip "MySQL Server '$AZURE_PROVISION_MYSQL_SERVER_NAME' does not exist"
        log_action "MySQL Server '$AZURE_PROVISION_MYSQL_SERVER_NAME'" "skipped" "not found"
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
            log_action "Storage Account '$AZURE_STORAGE_ACCOUNT_NAME'" "succeeded" "deleted"
        else
            log_error "Failed to delete Storage Account '$AZURE_STORAGE_ACCOUNT_NAME'"
            log_action "Storage Account '$AZURE_STORAGE_ACCOUNT_NAME'" "failed"
        fi
    else
        log_skip "Storage Account '$AZURE_STORAGE_ACCOUNT_NAME' does not exist"
        log_action "Storage Account '$AZURE_STORAGE_ACCOUNT_NAME'" "skipped" "not found"
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
            log_action "Container Registry '$AZURE_ACR_NAME'" "succeeded" "deleted"
        else
            log_error "Failed to delete Container Registry '$AZURE_ACR_NAME'"
            log_action "Container Registry '$AZURE_ACR_NAME'" "failed"
        fi
    else
        log_skip "Container Registry '$AZURE_ACR_NAME' does not exist"
        log_action "Container Registry '$AZURE_ACR_NAME'" "skipped" "not found"
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
            log_action "Resource Group '$AZURE_RESOURCE_GROUP'" "succeeded" "deleted"
        else
            log_error "Failed to delete Resource Group '$AZURE_RESOURCE_GROUP'"
            log_action "Resource Group '$AZURE_RESOURCE_GROUP'" "failed"
        fi
    else
        log_skip "Resource Group '$AZURE_RESOURCE_GROUP' does not exist"
        log_action "Resource Group '$AZURE_RESOURCE_GROUP'" "skipped" "not found"
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

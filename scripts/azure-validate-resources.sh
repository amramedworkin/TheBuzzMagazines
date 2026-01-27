#!/bin/bash
# ============================================================================
# Azure Resource Validation Script
# ============================================================================
# Validates that all Azure resources defined in .env exist (or don't exist).
# Reads ALL resource names from .env file - single source of truth.
#
# Usage:
#   ./azure-validate-resources.sh          # Check all resources
#   ./azure-validate-resources.sh -h       # Show help
# ============================================================================

# ============================================================================
# SCRIPT CONFIGURATION
# ============================================================================

SCRIPT_NAME="azure-validate-resources"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"
LOGS_DIR="${PROJECT_ROOT}/logs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BOLD='\033[1m'
NC='\033[0m'

# Track results for summary
declare -a RESOURCE_NAMES
declare -a RESOURCE_SERVICES
declare -a RESOURCE_DESCRIPTIONS
declare -a RESOURCE_EXISTS

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
        echo "Azure Resource Validation Log - $(TZ='America/New_York' date)"
        echo "Timezone: America/New_York (Eastern US)"
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
        INFO)    echo -e "${BLUE}[INFO]${NC} $message" ;;
        SUCCESS) echo -e "${GREEN}[EXISTS]${NC} $message" ;;
        MISSING) echo -e "${YELLOW}[MISSING]${NC} $message" ;;
        ERROR)   echo -e "${RED}[ERROR]${NC} $message" ;;
        STEP)    echo -e "${CYAN}[CHECK]${NC} $message" ;;
        *)       echo "$message" ;;
    esac
}

log_info() { log "INFO" "$1"; }
log_exists() { log "SUCCESS" "$1"; }
log_missing() { log "MISSING" "$1"; }
log_error() { log "ERROR" "$1"; }
log_check() { log "STEP" "$1"; }

# ============================================================================
# PARSE COMMAND LINE ARGUMENTS
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                echo "Usage: $0"
                echo ""
                echo "Validates that Azure resources defined in .env exist."
                echo ""
                echo "Options:"
                echo "  -h, --help   Show this help message"
                echo ""
                echo "Checks the following resources:"
                echo "  - Resource Group"
                echo "  - MySQL Flexible Server"
                echo "  - MySQL Database"
                echo "  - Storage Account"
                echo "  - File Shares (upload, custom, cache)"
                echo "  - Container Registry"
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
    log_info "Loading configuration from .env..."
    
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
    
    echo "" >> "$LOG_FILE"
    echo "Configuration loaded:" >> "$LOG_FILE"
    echo "  AZURE_SUBSCRIPTION_ID: $AZURE_SUBSCRIPTION_ID" >> "$LOG_FILE"
    echo "  AZURE_LOCATION: $AZURE_LOCATION" >> "$LOG_FILE"
    echo "  AZURE_RESOURCE_GROUP: $AZURE_RESOURCE_GROUP" >> "$LOG_FILE"
    echo "  AZURE_PROVISION_MYSQL_SERVER_NAME: $AZURE_PROVISION_MYSQL_SERVER_NAME" >> "$LOG_FILE"
    echo "  AZURE_STORAGE_ACCOUNT_NAME: $AZURE_STORAGE_ACCOUNT_NAME" >> "$LOG_FILE"
    echo "  AZURE_ACR_NAME: $AZURE_ACR_NAME" >> "$LOG_FILE"
    echo "  SUITECRM_RUNTIME_MYSQL_NAME: $SUITECRM_RUNTIME_MYSQL_NAME" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    log_info "Environment loaded successfully"
}

# ============================================================================
# VALIDATE PREREQUISITES
# ============================================================================

validate_prerequisites() {
    log_info "Checking Azure CLI authentication..."
    
    if ! az account show &>/dev/null; then
        log_error "Not logged in to Azure CLI. Run 'az login' first."
        exit 1
    fi
    log_info "Azure CLI authenticated"
    
    # Set subscription
    log_info "Setting subscription to $AZURE_SUBSCRIPTION_ID..."
    if ! az account set --subscription "$AZURE_SUBSCRIPTION_ID" &>/dev/null; then
        log_error "Failed to set subscription. Check AZURE_SUBSCRIPTION_ID in .env"
        exit 1
    fi
    log_info "Subscription set successfully"
}

# ============================================================================
# RECORD RESULT
# ============================================================================

record_result() {
    local name="$1"
    local service="$2"
    local description="$3"
    local exists="$4"
    
    RESOURCE_NAMES+=("$name")
    RESOURCE_SERVICES+=("$service")
    RESOURCE_DESCRIPTIONS+=("$description")
    RESOURCE_EXISTS+=("$exists")
}

# ============================================================================
# CHECK RESOURCE GROUP
# ============================================================================

check_resource_group() {
    log_check "Resource Group: $AZURE_RESOURCE_GROUP"
    
    if az group show --name "$AZURE_RESOURCE_GROUP" &>/dev/null; then
        log_exists "Resource Group '$AZURE_RESOURCE_GROUP' exists"
        record_result "$AZURE_RESOURCE_GROUP" "Resource Group" "Container for all Azure resources" "YES"
    else
        log_missing "Resource Group '$AZURE_RESOURCE_GROUP' does not exist"
        record_result "$AZURE_RESOURCE_GROUP" "Resource Group" "Container for all Azure resources" "NO"
    fi
}

# ============================================================================
# CHECK MYSQL SERVER
# ============================================================================

check_mysql_server() {
    log_check "MySQL Server: $AZURE_PROVISION_MYSQL_SERVER_NAME"
    
    if az mysql flexible-server show \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$AZURE_PROVISION_MYSQL_SERVER_NAME" &>/dev/null; then
        log_exists "MySQL Server '$AZURE_PROVISION_MYSQL_SERVER_NAME' exists"
        record_result "$AZURE_PROVISION_MYSQL_SERVER_NAME" "MySQL Flexible Server" "Database server for SuiteCRM" "YES"
        return 0
    else
        log_missing "MySQL Server '$AZURE_PROVISION_MYSQL_SERVER_NAME' does not exist"
        record_result "$AZURE_PROVISION_MYSQL_SERVER_NAME" "MySQL Flexible Server" "Database server for SuiteCRM" "NO"
        return 1
    fi
}

# ============================================================================
# CHECK MYSQL DATABASE
# ============================================================================

check_mysql_database() {
    local server_exists="$1"
    local db_name="${SUITECRM_RUNTIME_MYSQL_NAME}"
    
    log_check "MySQL Database: $db_name"
    
    # If server doesn't exist, database can't exist - skip the check
    if [[ "$server_exists" != "0" ]]; then
        log_info "  Skipping check - MySQL server does not exist (database assumed missing)"
        record_result "$db_name" "MySQL Database" "SuiteCRM application database" "NO"
        return
    fi
    
    if az mysql flexible-server db show \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --server-name "$AZURE_PROVISION_MYSQL_SERVER_NAME" \
        --database-name "$db_name" &>/dev/null; then
        log_exists "MySQL Database '$db_name' exists"
        record_result "$db_name" "MySQL Database" "SuiteCRM application database" "YES"
    else
        log_missing "MySQL Database '$db_name' does not exist"
        record_result "$db_name" "MySQL Database" "SuiteCRM application database" "NO"
    fi
}

# ============================================================================
# CHECK STORAGE ACCOUNT
# ============================================================================

check_storage_account() {
    log_check "Storage Account: $AZURE_STORAGE_ACCOUNT_NAME"
    
    if az storage account show \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$AZURE_STORAGE_ACCOUNT_NAME" &>/dev/null; then
        log_exists "Storage Account '$AZURE_STORAGE_ACCOUNT_NAME' exists"
        record_result "$AZURE_STORAGE_ACCOUNT_NAME" "Storage Account" "Azure Files for persistent storage" "YES"
        return 0
    else
        log_missing "Storage Account '$AZURE_STORAGE_ACCOUNT_NAME' does not exist"
        record_result "$AZURE_STORAGE_ACCOUNT_NAME" "Storage Account" "Azure Files for persistent storage" "NO"
        return 1
    fi
}

# ============================================================================
# CHECK FILE SHARES
# ============================================================================

check_file_shares() {
    local storage_exists="$1"
    local shares=("suitecrm-upload" "suitecrm-custom" "suitecrm-cache")
    local descriptions=(
        "User uploaded files (documents, images)"
        "Custom modules and extensions"
        "Application cache files"
    )
    
    if [[ "$storage_exists" != "0" ]]; then
        # Storage account doesn't exist, so shares can't exist
        for i in "${!shares[@]}"; do
            log_check "File Share: ${shares[$i]}"
            log_missing "File Share '${shares[$i]}' cannot exist (storage account missing)"
            record_result "${shares[$i]}" "File Share" "${descriptions[$i]}" "NO"
        done
        return
    fi
    
    # Get storage key
    local storage_key
    storage_key=$(az storage account keys list \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --account-name "$AZURE_STORAGE_ACCOUNT_NAME" \
        --query '[0].value' -o tsv 2>/dev/null)
    
    if [[ -z "$storage_key" ]]; then
        log_error "Could not retrieve storage key - cannot check file shares"
        for i in "${!shares[@]}"; do
            record_result "${shares[$i]}" "File Share" "${descriptions[$i]}" "UNKNOWN"
        done
        return
    fi
    
    for i in "${!shares[@]}"; do
        local share="${shares[$i]}"
        local desc="${descriptions[$i]}"
        
        log_check "File Share: $share"
        
        if az storage share show \
            --name "$share" \
            --account-name "$AZURE_STORAGE_ACCOUNT_NAME" \
            --account-key "$storage_key" &>/dev/null; then
            log_exists "File Share '$share' exists"
            record_result "$share" "File Share" "$desc" "YES"
        else
            log_missing "File Share '$share' does not exist"
            record_result "$share" "File Share" "$desc" "NO"
        fi
    done
}

# ============================================================================
# CHECK CONTAINER REGISTRY
# ============================================================================

check_container_registry() {
    log_check "Container Registry: $AZURE_ACR_NAME"
    
    if az acr show \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$AZURE_ACR_NAME" &>/dev/null; then
        log_exists "Container Registry '$AZURE_ACR_NAME' exists"
        record_result "$AZURE_ACR_NAME" "Container Registry" "Docker image repository" "YES"
    else
        log_missing "Container Registry '$AZURE_ACR_NAME' does not exist"
        record_result "$AZURE_ACR_NAME" "Container Registry" "Docker image repository" "NO"
    fi
}

# ============================================================================
# OUTPUT SUMMARY TABLE
# ============================================================================

output_summary() {
    local total=${#RESOURCE_NAMES[@]}
    local exists_count=0
    local missing_count=0
    
    # Count results
    for status in "${RESOURCE_EXISTS[@]}"; do
        if [[ "$status" == "YES" ]]; then
            ((exists_count++))
        elif [[ "$status" == "NO" ]]; then
            ((missing_count++))
        fi
    done
    
    # Calculate column widths
    local name_width=25
    local service_width=22
    local desc_width=40
    local status_width=8
    
    for name in "${RESOURCE_NAMES[@]}"; do
        if [[ ${#name} -gt $name_width ]]; then
            name_width=${#name}
        fi
    done
    
    # Print summary header
    echo ""
    echo "============================================================================"
    echo "                    AZURE RESOURCE VALIDATION SUMMARY"
    echo "============================================================================"
    echo ""
    echo -e "${BOLD}Configuration from .env:${NC}"
    echo "  Subscription:    $AZURE_SUBSCRIPTION_ID"
    echo "  Location:        $AZURE_LOCATION"
    echo "  Resource Prefix: $AZURE_RESOURCE_PREFIX"
    echo ""
    
    # Print table header
    printf "${BOLD}%-${name_width}s  %-${service_width}s  %-${desc_width}s  %-${status_width}s${NC}\n" \
        "RESOURCE NAME" "SERVICE TYPE" "DESCRIPTION" "EXISTS"
    printf "%s\n" "$(printf '=%.0s' $(seq 1 $((name_width + service_width + desc_width + status_width + 6))))"
    
    # Print each row
    for i in "${!RESOURCE_NAMES[@]}"; do
        local name="${RESOURCE_NAMES[$i]}"
        local service="${RESOURCE_SERVICES[$i]}"
        local desc="${RESOURCE_DESCRIPTIONS[$i]}"
        local status="${RESOURCE_EXISTS[$i]}"
        
        # Truncate description if too long
        if [[ ${#desc} -gt $desc_width ]]; then
            desc="${desc:0:$((desc_width-3))}..."
        fi
        
        # Color the status
        local status_colored
        if [[ "$status" == "YES" ]]; then
            status_colored="${GREEN}YES${NC}"
        elif [[ "$status" == "NO" ]]; then
            status_colored="${RED}NO${NC}"
        else
            status_colored="${YELLOW}${status}${NC}"
        fi
        
        printf "%-${name_width}s  %-${service_width}s  %-${desc_width}s  %b\n" \
            "$name" "$service" "$desc" "$status_colored"
    done
    
    # Print summary footer
    printf "%s\n" "$(printf '=%.0s' $(seq 1 $((name_width + service_width + desc_width + status_width + 6))))"
    echo ""
    echo -e "${BOLD}Summary:${NC} ${GREEN}$exists_count exist${NC}, ${RED}$missing_count missing${NC} (of $total resources)"
    echo ""
    
    if [[ $missing_count -eq 0 ]]; then
        echo -e "${GREEN}✔ All resources are provisioned and ready${NC}"
    elif [[ $exists_count -eq 0 ]]; then
        echo -e "${YELLOW}○ No resources provisioned yet. Run: ./scripts/azure-provision-infra.sh${NC}"
    else
        echo -e "${YELLOW}○ Some resources are missing. Run: ./scripts/azure-provision-infra.sh${NC}"
    fi
    
    echo ""
    echo "Log file: $LOG_FILE"
    echo "============================================================================"
    echo ""
    
    # Also write to log file
    {
        echo ""
        echo "============================================================================"
        echo "VALIDATION SUMMARY"
        echo "============================================================================"
        echo ""
        printf "%-${name_width}s  %-${service_width}s  %-${desc_width}s  %-${status_width}s\n" \
            "RESOURCE NAME" "SERVICE TYPE" "DESCRIPTION" "EXISTS"
        printf "%s\n" "$(printf '=%.0s' $(seq 1 $((name_width + service_width + desc_width + status_width + 6))))"
        
        for i in "${!RESOURCE_NAMES[@]}"; do
            printf "%-${name_width}s  %-${service_width}s  %-${desc_width}s  %-${status_width}s\n" \
                "${RESOURCE_NAMES[$i]}" "${RESOURCE_SERVICES[$i]}" "${RESOURCE_DESCRIPTIONS[$i]}" "${RESOURCE_EXISTS[$i]}"
        done
        
        echo ""
        echo "Summary: $exists_count exist, $missing_count missing (of $total resources)"
        echo ""
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
    echo "Azure Resource Validation"
    echo "============================================================================"
    echo ""
    
    load_env
    validate_prerequisites
    
    echo ""
    echo "Checking Azure resources..."
    echo ""
    
    # Check all resources
    check_resource_group
    
    # Check MySQL server and capture result for database check
    check_mysql_server
    mysql_server_exists=$?
    
    check_mysql_database "$mysql_server_exists"
    
    # Check storage and capture result for file share checks
    check_storage_account
    storage_exists=$?
    
    check_file_shares "$storage_exists"
    check_container_registry
    
    # Output summary table
    output_summary
}

main "$@"

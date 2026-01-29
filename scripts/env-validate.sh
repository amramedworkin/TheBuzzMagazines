#!/bin/bash
# ============================================================================
# Environment Variable Validation Script
# ============================================================================
# Validates that .env file is fully populated with no placeholders
# Returns exit code 0 if valid, 1 if invalid
#
# Usage:
#   ./env-validate.sh               # Full validation with detailed output
#   ./env-validate.sh --quiet       # Minimal output, just pass/fail
#   ./env-validate.sh --errors-only # Only show errors (for use by other scripts)
#   ./env-validate.sh --help        # Show help
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"

# Source common utilities (colors only - this script has specialized validation logging)
source "$SCRIPT_DIR/lib/common.sh"

# Output modes
QUIET_MODE=false
ERRORS_ONLY_MODE=false

# Track validation state
VALIDATION_PASSED=true
ERRORS_FOUND=0
WARNINGS_FOUND=0

# Arrays to collect failures for consolidated output
declare -a FAILURE_VARS=()
declare -a FAILURE_VALUES=()
declare -a FAILURE_REQUIRED=()
declare -a FAILURE_INSTRUCTIONS=()

# ============================================================================
# OUTPUT HELPERS
# ============================================================================

# Truncate value if > 15 chars
truncate_value() {
    local value="$1"
    if [[ ${#value} -gt 15 ]]; then
        echo "${value:0:12}..."
    else
        echo "$value"
    fi
}

print_header() {
    if [[ "$QUIET_MODE" == "false" && "$ERRORS_ONLY_MODE" == "false" ]]; then
        echo ""
        echo -e "${BOLD}============================================================================${NC}"
        echo -e "${BOLD}$1${NC}"
        echo -e "${BOLD}============================================================================${NC}"
    fi
}

print_section() {
    if [[ "$QUIET_MODE" == "false" && "$ERRORS_ONLY_MODE" == "false" ]]; then
        echo ""
        echo -e "${CYAN}--- $1 ---${NC}"
    fi
}

print_ok() {
    local var_name="$1"
    local value="$2"
    local description="$3"
    
    if [[ "$QUIET_MODE" == "false" && "$ERRORS_ONLY_MODE" == "false" ]]; then
        local display_value=$(truncate_value "$value")
        echo -e "  ${GREEN}✓${NC} ${var_name} ${YELLOW}[${display_value}]${NC} - ${ITALIC}${DIM}${description}${NC}"
    fi
}

# Record an error for consolidated output later
record_error() {
    local var_name="$1"
    local current_value="$2"
    local required="$3"
    local instructions="$4"
    local description="$5"
    
    VALIDATION_PASSED=false
    ((ERRORS_FOUND++))
    
    FAILURE_VARS+=("$var_name")
    FAILURE_VALUES+=("$current_value")
    FAILURE_REQUIRED+=("$required")
    FAILURE_INSTRUCTIONS+=("$instructions")
    
    # Show inline indicator (brief)
    if [[ "$QUIET_MODE" == "false" && "$ERRORS_ONLY_MODE" == "false" ]]; then
        local display_value=$(truncate_value "$current_value")
        [[ -z "$display_value" ]] && display_value="(empty)"
        echo -e "  ${RED}✗${NC} ${var_name} ${YELLOW}[${display_value}]${NC} - ${ITALIC}${DIM}${description}${NC}"
    fi
}

print_warning() {
    local var_name="$1"
    local value="$2"
    local warning_msg="$3"
    local description="$4"
    
    ((WARNINGS_FOUND++))
    # Don't show warnings in errors-only mode or quiet mode
    if [[ "$QUIET_MODE" == "false" && "$ERRORS_ONLY_MODE" == "false" ]]; then
        local display_value=$(truncate_value "$value")
        [[ -z "$display_value" ]] && display_value="(empty)"
        echo -e "  ${YELLOW}⚠${NC} ${var_name} ${YELLOW}[${display_value}]${NC} - ${ITALIC}${DIM}${description}${NC} ${DIM}(${warning_msg})${NC}"
    fi
}

print_info() {
    local var_name="$1"
    local default_value="$2"
    local description="$3"
    
    if [[ "$QUIET_MODE" == "false" && "$ERRORS_ONLY_MODE" == "false" ]]; then
        echo -e "  ${DIM}ℹ ${var_name} ${YELLOW}[${default_value}]${NC} - ${ITALIC}${DIM}${description}${NC}"
    fi
}

# Print consolidated failure list (always prints if there are failures)
print_failure_summary() {
    if [[ ${#FAILURE_VARS[@]} -eq 0 ]]; then
        return
    fi
    
    echo ""
    echo -e "${RED}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}  ${BOLD}${RED}✗ VALIDATION FAILED: ${ERRORS_FOUND} variable(s) need attention${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    for i in "${!FAILURE_VARS[@]}"; do
        local var="${FAILURE_VARS[$i]}"
        local value="${FAILURE_VALUES[$i]}"
        local required="${FAILURE_REQUIRED[$i]}"
        local instructions="${FAILURE_INSTRUCTIONS[$i]}"
        
        local display_value=$(truncate_value "$value")
        [[ -z "$display_value" ]] && display_value="(empty)"
        
        echo -e "  ${RED}┌─${NC} ${BOLD}${var}${NC} ${YELLOW}[${display_value}]${NC}"
        echo -e "  ${RED}│${NC}  ${DIM}Required:${NC} ${required}"
        echo -e "  ${RED}│${NC}  ${DIM}How to fix:${NC}"
        echo -e "  ${RED}│${NC}    ${instructions}"
        echo -e "  ${RED}└─${NC}"
        echo ""
    done
    
    echo -e "  ${YELLOW}Edit your .env file to fix these issues:${NC}"
    echo -e "    nano $ENV_FILE"
    echo ""
}

# ============================================================================
# PARSE ARGUMENTS
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -q|--quiet)
                QUIET_MODE=true
                shift
                ;;
            -e|--errors-only)
                ERRORS_ONLY_MODE=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Validates that .env file is fully populated with no placeholders."
                echo ""
                echo "Options:"
                echo "  -q, --quiet        Minimal output, just pass/fail status"
                echo "  -e, --errors-only  Only show errors (suppress warnings and success)"
                echo "  -h, --help         Show this help message"
                echo ""
                echo "Exit codes:"
                echo "  0 - All validations passed (may have warnings)"
                echo "  1 - One or more validations failed (errors)"
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
# VALIDATION HELPERS
# ============================================================================

# Check if a value is a placeholder
is_placeholder() {
    local value="$1"
    
    # Check for common placeholder patterns
    if [[ -z "$value" ]]; then
        return 0  # Empty is a placeholder
    fi
    
    if [[ "$value" =~ ^your[_-] ]] || \
       [[ "$value" =~ ^YOUR[_-] ]] || \
       [[ "$value" =~ ^CHANGE[_-]?ME ]] || \
       [[ "$value" =~ ^change[_-]?me ]] || \
       [[ "$value" =~ ^REPLACE ]] || \
       [[ "$value" =~ ^replace ]] || \
       [[ "$value" =~ ^xxx+ ]] || \
       [[ "$value" =~ ^XXX+ ]] || \
       [[ "$value" =~ ^\<.*\>$ ]] || \
       [[ "$value" =~ ^\[YOUR_ ]] || \
       [[ "$value" =~ ^\[your_ ]] || \
       [[ "$value" =~ _HERE\]$ ]] || \
       [[ "$value" =~ ^TODO ]] || \
       [[ "$value" =~ ^FIXME ]] || \
       [[ "$value" =~ ^placeholder ]] || \
       [[ "$value" =~ ^PLACEHOLDER ]] || \
       [[ "$value" =~ ^/path/to/ ]]; then
        return 0  # Is a placeholder
    fi
    
    return 1  # Not a placeholder
}

# Check if a value looks like a valid UUID/GUID
is_valid_uuid() {
    local value="$1"
    if [[ "$value" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
        return 0
    fi
    return 1
}

# Check if password meets minimum requirements
is_valid_password() {
    local value="$1"
    local min_length="${2:-8}"
    
    if [[ ${#value} -lt $min_length ]]; then
        return 1
    fi
    return 0
}

# Get variable value from .env (handles variable expansion)
get_env_value() {
    local var_name="$1"
    
    # Source the .env file and echo the variable
    (
        set -a
        source "$ENV_FILE" 2>/dev/null
        
        # Expand GLOBAL_* derived variables first
        AZURE_RESOURCE_PREFIX="${AZURE_RESOURCE_PREFIX:-${GLOBAL_PREFIX}}"
        DOCKER_PREFIX="${DOCKER_PREFIX:-${GLOBAL_PREFIX}}"
        SUITECRM_PASSWORD="${SUITECRM_PASSWORD:-${GLOBAL_PASSWORD}}"
        AZURE_PASSWORD="${AZURE_PASSWORD:-${GLOBAL_PASSWORD}}"
        DOCKER_PASSWORD="${DOCKER_PASSWORD:-${GLOBAL_PASSWORD}}"
        
        # Expand Azure nested variables
        AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_PREFIX}-rg"
        AZURE_PROVISION_MYSQL_SERVER_NAME="${AZURE_RESOURCE_PREFIX}-mysql"
        AZURE_STORAGE_ACCOUNT_NAME="${AZURE_RESOURCE_PREFIX}storage"
        AZURE_ACR_NAME="${AZURE_RESOURCE_PREFIX}acr"
        AZURE_CONTAINER_APP_ENV="${AZURE_RESOURCE_PREFIX}-cae"
        SUITECRM_RUNTIME_MYSQL_HOST="${AZURE_PROVISION_MYSQL_SERVER_NAME}.mysql.database.azure.com"
        
        # Expand Docker nested variables
        DOCKER_IMAGE_NAME="${DOCKER_PREFIX}-suitecrm"
        DOCKER_CONTAINER_NAME="${DOCKER_PREFIX}-suitecrm-web"
        DOCKER_NETWORK_NAME="${DOCKER_PREFIX}-suitecrm-network"
        
        # Expand password-derived variables
        SUITECRM_RUNTIME_MYSQL_PASSWORD="${SUITECRM_RUNTIME_MYSQL_PASSWORD:-${SUITECRM_PASSWORD}}"
        SUITECRM_ADMIN_PASSWORD="${SUITECRM_ADMIN_PASSWORD:-${SUITECRM_PASSWORD}}"
        MIGRATION_DEST_MYSQL_PASSWORD="${MIGRATION_DEST_MYSQL_PASSWORD:-${SUITECRM_PASSWORD}}"
        
        echo "${!var_name}"
    )
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

validate_global_config() {
    print_section "Global Configuration (Single Source of Truth)"
    
    local value
    
    # GLOBAL_PREFIX
    value=$(get_env_value "GLOBAL_PREFIX")
    if is_placeholder "$value" || [[ -z "$value" ]]; then
        record_error "GLOBAL_PREFIX" "$value" \
            "A short, unique prefix for naming resources (e.g., buzzmag, mycrm)" \
            "This prefix is used for all Azure and Docker resource names. Keep it 3-8 chars, lowercase, alphanumeric." \
            "Global naming prefix for all resources"
    elif [[ ! "$value" =~ ^[a-z0-9]{3,8}$ ]]; then
        print_warning "GLOBAL_PREFIX" "$value" "use 3-8 lowercase alphanumeric" \
            "Global naming prefix for all resources"
    else
        print_ok "GLOBAL_PREFIX" "$value" "Global naming prefix for all resources"
    fi
    
    # GLOBAL_PASSWORD
    value=$(get_env_value "GLOBAL_PASSWORD")
    if is_placeholder "$value"; then
        record_error "GLOBAL_PASSWORD" "$value" \
            "A strong password (min 8 chars, mixed case, numbers, special)" \
            "This is the default password for development. Azure MySQL requires: 8+ chars, uppercase, lowercase, numbers. Example: MyP@ssw0rd123" \
            "Global default password for development"
    elif ! is_valid_password "$value" 8; then
        record_error "GLOBAL_PASSWORD" "$value" \
            "Minimum 8 characters" \
            "Azure MySQL requires passwords with at least 8 characters, mixed case, and numbers." \
            "Global default password for development"
    else
        print_ok "GLOBAL_PASSWORD" "$value" "Global default password for development"
    fi
}

validate_derived_prefixes() {
    print_section "Derived Prefixes (from GLOBAL_PREFIX)"
    
    local value
    local global_prefix
    global_prefix=$(get_env_value "GLOBAL_PREFIX")
    
    # AZURE_RESOURCE_PREFIX
    value=$(get_env_value "AZURE_RESOURCE_PREFIX")
    if [[ -z "$value" ]]; then
        print_info "AZURE_RESOURCE_PREFIX" "\${GLOBAL_PREFIX}" "Azure resource naming prefix"
    else
        print_ok "AZURE_RESOURCE_PREFIX" "$value" "Azure resource naming prefix"
    fi
    
    # DOCKER_PREFIX
    value=$(get_env_value "DOCKER_PREFIX")
    if [[ -z "$value" ]]; then
        print_info "DOCKER_PREFIX" "\${GLOBAL_PREFIX}" "Docker container/image naming prefix"
    else
        print_ok "DOCKER_PREFIX" "$value" "Docker container/image naming prefix"
    fi
}

validate_derived_passwords() {
    print_section "Derived Passwords (from GLOBAL_PASSWORD)"
    
    local value
    
    # SUITECRM_PASSWORD
    value=$(get_env_value "SUITECRM_PASSWORD")
    if is_placeholder "$value"; then
        record_error "SUITECRM_PASSWORD" "$value" \
            "A strong password (min 8 chars)" \
            "Set SUITECRM_PASSWORD or ensure GLOBAL_PASSWORD is configured" \
            "SuiteCRM DB, admin, and migration password"
    elif ! is_valid_password "$value" 8; then
        print_warning "SUITECRM_PASSWORD" "$value" "password too short" \
            "SuiteCRM DB, admin, and migration password"
    else
        print_ok "SUITECRM_PASSWORD" "$value" "SuiteCRM DB, admin, and migration password"
    fi
    
    # AZURE_PASSWORD
    value=$(get_env_value "AZURE_PASSWORD")
    if [[ -z "$value" ]]; then
        print_info "AZURE_PASSWORD" "\${GLOBAL_PASSWORD}" "Azure MySQL admin password"
    elif ! is_valid_password "$value" 8; then
        print_warning "AZURE_PASSWORD" "$value" "password too short" \
            "Azure MySQL admin password"
    else
        print_ok "AZURE_PASSWORD" "$value" "Azure MySQL admin password"
    fi
    
    # DOCKER_PASSWORD
    value=$(get_env_value "DOCKER_PASSWORD")
    if [[ -z "$value" ]]; then
        print_info "DOCKER_PASSWORD" "\${GLOBAL_PASSWORD}" "Docker container auth password"
    else
        print_ok "DOCKER_PASSWORD" "$value" "Docker container auth password"
    fi
}

validate_docker_config() {
    print_section "Docker Build Configuration"
    
    local value
    
    # DOCKER_PHP_BASE_IMAGE
    value=$(get_env_value "DOCKER_PHP_BASE_IMAGE")
    if [[ -z "$value" ]]; then
        print_info "DOCKER_PHP_BASE_IMAGE" "php:8.3-apache" "Base PHP Docker image"
    else
        print_ok "DOCKER_PHP_BASE_IMAGE" "$value" "Base PHP Docker image"
    fi
    
    # DOCKER_SUITECRM_VERSION
    value=$(get_env_value "DOCKER_SUITECRM_VERSION")
    if [[ -z "$value" ]]; then
        print_info "DOCKER_SUITECRM_VERSION" "8.8.0" "SuiteCRM version to install"
    else
        print_ok "DOCKER_SUITECRM_VERSION" "$value" "SuiteCRM version to install"
    fi
    
    # DOCKER_PLATFORM
    value=$(get_env_value "DOCKER_PLATFORM")
    if [[ -z "$value" ]]; then
        print_info "DOCKER_PLATFORM" "linux/amd64" "Target platform architecture"
    else
        print_ok "DOCKER_PLATFORM" "$value" "Target platform architecture"
    fi
    
    # DOCKER_IMAGE_NAME
    value=$(get_env_value "DOCKER_IMAGE_NAME")
    if [[ -z "$value" ]]; then
        print_info "DOCKER_IMAGE_NAME" "\${DOCKER_PREFIX}-suitecrm" "Docker image name"
    else
        print_ok "DOCKER_IMAGE_NAME" "$value" "Docker image name"
    fi
    
    # DOCKER_CONTAINER_NAME
    value=$(get_env_value "DOCKER_CONTAINER_NAME")
    if [[ -z "$value" ]]; then
        print_info "DOCKER_CONTAINER_NAME" "\${DOCKER_PREFIX}-suitecrm-web" "Docker container name"
    else
        print_ok "DOCKER_CONTAINER_NAME" "$value" "Docker container name"
    fi
    
    # DOCKER_HOST_PORT
    value=$(get_env_value "DOCKER_HOST_PORT")
    if [[ -z "$value" ]]; then
        print_info "DOCKER_HOST_PORT" "80" "Host port to expose"
    elif [[ ! "$value" =~ ^[0-9]+$ ]]; then
        print_warning "DOCKER_HOST_PORT" "$value" "should be a number" \
            "Host port to expose"
    else
        print_ok "DOCKER_HOST_PORT" "$value" "Host port to expose"
    fi
    
    # DOCKER_PHP_MEMORY_LIMIT
    value=$(get_env_value "DOCKER_PHP_MEMORY_LIMIT")
    if [[ -z "$value" ]]; then
        print_info "DOCKER_PHP_MEMORY_LIMIT" "512M" "PHP memory limit"
    else
        print_ok "DOCKER_PHP_MEMORY_LIMIT" "$value" "PHP memory limit"
    fi
}

validate_azure_config() {
    print_section "Azure Resource Configuration"
    
    # AZURE_SUBSCRIPTION_ID
    local value
    value=$(get_env_value "AZURE_SUBSCRIPTION_ID")
    if is_placeholder "$value"; then
        record_error "AZURE_SUBSCRIPTION_ID" "$value" \
            "A valid Azure subscription GUID" \
            "Get from Azure Portal > Subscriptions, or run: az account show --query id -o tsv" \
            "Azure billing account for resources"
    elif ! is_valid_uuid "$value"; then
        record_error "AZURE_SUBSCRIPTION_ID" "$value" \
            "A valid UUID format (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)" \
            "The subscription ID should be a GUID. Find it in Azure Portal > Subscriptions" \
            "Azure billing account for resources"
    else
        print_ok "AZURE_SUBSCRIPTION_ID" "$value" "Azure billing account for resources"
    fi
    
    # AZURE_LOCATION
    value=$(get_env_value "AZURE_LOCATION")
    if is_placeholder "$value"; then
        record_error "AZURE_LOCATION" "$value" \
            "An Azure region name (e.g., eastus, westus2, southcentralus)" \
            "Choose a region close to your users. Run: az account list-locations -o table" \
            "Datacenter region for deployment"
    else
        print_ok "AZURE_LOCATION" "$value" "Datacenter region for deployment"
    fi
    
    # AZURE_RESOURCE_PREFIX
    value=$(get_env_value "AZURE_RESOURCE_PREFIX")
    if is_placeholder "$value"; then
        record_error "AZURE_RESOURCE_PREFIX" "$value" \
            "A short, unique prefix for naming resources (e.g., buzzmag, mycrm)" \
            "This prefix is used for all Azure resource names. Keep it 3-10 chars, lowercase, alphanumeric." \
            "Prefix for Azure resource names"
    elif [[ ! "$value" =~ ^[a-z0-9]{3,15}$ ]]; then
        print_warning "AZURE_RESOURCE_PREFIX" "$value" "use 3-15 lowercase alphanumeric" \
            "Prefix for Azure resource names"
    else
        print_ok "AZURE_RESOURCE_PREFIX" "$value" "Prefix for Azure resource names"
    fi
}

validate_azure_provisioning_config() {
    print_section "Azure Provisioning: MySQL Server"
    
    local value
    
    # AZURE_PROVISION_MYSQL_SKU
    value=$(get_env_value "AZURE_PROVISION_MYSQL_SKU")
    if [[ -z "$value" ]]; then
        print_info "AZURE_PROVISION_MYSQL_SKU" "Standard_B1ms" "MySQL compute tier"
    else
        print_ok "AZURE_PROVISION_MYSQL_SKU" "$value" "MySQL compute tier"
    fi
    
    # AZURE_PROVISION_MYSQL_STORAGE_GB
    value=$(get_env_value "AZURE_PROVISION_MYSQL_STORAGE_GB")
    if [[ -z "$value" ]]; then
        print_info "AZURE_PROVISION_MYSQL_STORAGE_GB" "32" "MySQL storage in GB"
    else
        print_ok "AZURE_PROVISION_MYSQL_STORAGE_GB" "$value" "MySQL storage in GB"
    fi
    
    # AZURE_PROVISION_MYSQL_VERSION
    value=$(get_env_value "AZURE_PROVISION_MYSQL_VERSION")
    if [[ -z "$value" ]]; then
        print_info "AZURE_PROVISION_MYSQL_VERSION" "8.4" "MySQL server version"
    else
        print_ok "AZURE_PROVISION_MYSQL_VERSION" "$value" "MySQL server version"
    fi
}

validate_azure_storage_config() {
    print_section "Azure Storage Account"
    
    local value
    
    # AZURE_STORAGE_SKU
    value=$(get_env_value "AZURE_STORAGE_SKU")
    if [[ -z "$value" ]]; then
        print_info "AZURE_STORAGE_SKU" "Standard_LRS" "Storage redundancy tier"
    else
        print_ok "AZURE_STORAGE_SKU" "$value" "Storage redundancy tier"
    fi
    
    # AZURE_FILES_SHARE_PREFIX
    value=$(get_env_value "AZURE_FILES_SHARE_PREFIX")
    if [[ -z "$value" ]]; then
        print_info "AZURE_FILES_SHARE_PREFIX" "\${DOCKER_PREFIX}-suitecrm" "Prefix for Azure File share names"
    else
        print_ok "AZURE_FILES_SHARE_PREFIX" "$value" "Prefix for Azure File share names"
    fi
    
    # AZURE_FILES_SHARE_UPLOAD
    value=$(get_env_value "AZURE_FILES_SHARE_UPLOAD")
    if [[ -z "$value" ]]; then
        print_info "AZURE_FILES_SHARE_UPLOAD" "upload" "Upload share name component"
    else
        print_ok "AZURE_FILES_SHARE_UPLOAD" "$value" "Upload share name component"
    fi
    
    # AZURE_FILES_SHARE_CUSTOM
    value=$(get_env_value "AZURE_FILES_SHARE_CUSTOM")
    if [[ -z "$value" ]]; then
        print_info "AZURE_FILES_SHARE_CUSTOM" "custom" "Custom share name component"
    else
        print_ok "AZURE_FILES_SHARE_CUSTOM" "$value" "Custom share name component"
    fi
    
    # AZURE_FILES_SHARE_CACHE
    value=$(get_env_value "AZURE_FILES_SHARE_CACHE")
    if [[ -z "$value" ]]; then
        print_info "AZURE_FILES_SHARE_CACHE" "cache" "Cache share name component"
    else
        print_ok "AZURE_FILES_SHARE_CACHE" "$value" "Cache share name component"
    fi
    
    # AZURE_FILES_CREDENTIALS_FILE
    value=$(get_env_value "AZURE_FILES_CREDENTIALS_FILE")
    if [[ -z "$value" ]]; then
        print_info "AZURE_FILES_CREDENTIALS_FILE" "/etc/azure-\${GLOBAL_PREFIX}-credentials" "SMB credentials file path"
    else
        print_ok "AZURE_FILES_CREDENTIALS_FILE" "$value" "SMB credentials file path"
    fi
}

validate_azure_acr_config() {
    print_section "Azure Container Registry"
    
    local value
    
    # AZURE_ACR_SKU
    value=$(get_env_value "AZURE_ACR_SKU")
    if [[ -z "$value" ]]; then
        print_info "AZURE_ACR_SKU" "Basic" "Container Registry tier"
    else
        print_ok "AZURE_ACR_SKU" "$value" "Container Registry tier"
    fi
}

validate_azure_container_apps_config() {
    print_section "Azure Container Apps"
    
    local value
    
    # AZURE_CONTAINER_APP_ENV
    value=$(get_env_value "AZURE_CONTAINER_APP_ENV")
    if [[ -z "$value" ]]; then
        print_info "AZURE_CONTAINER_APP_ENV" "\${AZURE_RESOURCE_PREFIX}-cae" "Container Apps Environment name"
    else
        print_ok "AZURE_CONTAINER_APP_ENV" "$value" "Container Apps Environment name"
    fi
    
    # AZURE_CONTAINER_APP_NAME
    value=$(get_env_value "AZURE_CONTAINER_APP_NAME")
    if [[ -z "$value" ]]; then
        print_info "AZURE_CONTAINER_APP_NAME" "suitecrm" "Container App name"
    else
        print_ok "AZURE_CONTAINER_APP_NAME" "$value" "Container App name"
    fi
}

validate_suitecrm_runtime_mysql_config() {
    print_section "SuiteCRM Runtime: MySQL Connection"
    
    local value
    
    # SUITECRM_RUNTIME_MYSQL_NAME
    value=$(get_env_value "SUITECRM_RUNTIME_MYSQL_NAME")
    if is_placeholder "$value" || [[ -z "$value" ]]; then
        record_error "SUITECRM_RUNTIME_MYSQL_NAME" "$value" \
            "A database name (e.g., suitecrm)" \
            "This is the database that SuiteCRM will use. Typically 'suitecrm'." \
            "SuiteCRM database name"
    else
        print_ok "SUITECRM_RUNTIME_MYSQL_NAME" "$value" "SuiteCRM database name"
    fi
    
    # SUITECRM_RUNTIME_MYSQL_USER
    value=$(get_env_value "SUITECRM_RUNTIME_MYSQL_USER")
    if is_placeholder "$value"; then
        record_error "SUITECRM_RUNTIME_MYSQL_USER" "$value" \
            "A database username (e.g., suitecrm, dbadmin)" \
            "This user will be created on Azure MySQL. Choose a username (not 'root' or 'admin')." \
            "MySQL connection username"
    else
        print_ok "SUITECRM_RUNTIME_MYSQL_USER" "$value" "MySQL connection username"
    fi
    
    # SUITECRM_RUNTIME_MYSQL_PASSWORD
    value=$(get_env_value "SUITECRM_RUNTIME_MYSQL_PASSWORD")
    if is_placeholder "$value"; then
        record_error "SUITECRM_RUNTIME_MYSQL_PASSWORD" "$value" \
            "A strong password (min 8 chars, mixed case, numbers)" \
            "Azure MySQL requires: 8+ chars, uppercase, lowercase, and numbers. Example: MyP@ssw0rd123" \
            "MySQL connection password"
    elif ! is_valid_password "$value" 8; then
        record_error "SUITECRM_RUNTIME_MYSQL_PASSWORD" "$value" \
            "Minimum 8 characters" \
            "Azure MySQL requires passwords with at least 8 characters, mixed case, and numbers." \
            "MySQL connection password"
    else
        print_ok "SUITECRM_RUNTIME_MYSQL_PASSWORD" "$value" "MySQL connection password"
    fi
    
    # SUITECRM_RUNTIME_MYSQL_PORT
    value=$(get_env_value "SUITECRM_RUNTIME_MYSQL_PORT")
    if [[ -z "$value" ]]; then
        print_info "SUITECRM_RUNTIME_MYSQL_PORT" "3306" "MySQL connection port"
    else
        print_ok "SUITECRM_RUNTIME_MYSQL_PORT" "$value" "MySQL connection port"
    fi
    
    # SUITECRM_RUNTIME_MYSQL_SSL_ENABLED
    value=$(get_env_value "SUITECRM_RUNTIME_MYSQL_SSL_ENABLED")
    if [[ -z "$value" ]]; then
        print_info "SUITECRM_RUNTIME_MYSQL_SSL_ENABLED" "true" "Enable SSL for MySQL"
    elif [[ "$value" != "true" && "$value" != "false" ]]; then
        print_warning "SUITECRM_RUNTIME_MYSQL_SSL_ENABLED" "$value" "should be true or false" \
            "Enable SSL for MySQL"
    else
        print_ok "SUITECRM_RUNTIME_MYSQL_SSL_ENABLED" "$value" "Enable SSL for MySQL"
    fi
    
    # SUITECRM_RUNTIME_MYSQL_SSL_VERIFY
    value=$(get_env_value "SUITECRM_RUNTIME_MYSQL_SSL_VERIFY")
    if [[ -z "$value" ]]; then
        print_info "SUITECRM_RUNTIME_MYSQL_SSL_VERIFY" "true" "Verify SSL certificate"
    elif [[ "$value" != "true" && "$value" != "false" ]]; then
        print_warning "SUITECRM_RUNTIME_MYSQL_SSL_VERIFY" "$value" "should be true or false" \
            "Verify SSL certificate"
    else
        print_ok "SUITECRM_RUNTIME_MYSQL_SSL_VERIFY" "$value" "Verify SSL certificate"
    fi
    
    # SUITECRM_RUNTIME_MYSQL_SSL_CA
    value=$(get_env_value "SUITECRM_RUNTIME_MYSQL_SSL_CA")
    if [[ -z "$value" ]]; then
        print_info "SUITECRM_RUNTIME_MYSQL_SSL_CA" "/etc/ssl/certs/ca-certificates.crt" "SSL CA certificate path"
    else
        print_ok "SUITECRM_RUNTIME_MYSQL_SSL_CA" "$value" "SSL CA certificate path"
    fi
}

validate_suitecrm_config() {
    print_section "SuiteCRM Application Settings"
    
    local value
    
    # SUITECRM_SITE_URL
    value=$(get_env_value "SUITECRM_SITE_URL")
    if is_placeholder "$value" || [[ -z "$value" ]]; then
        record_error "SUITECRM_SITE_URL" "$value" \
            "The URL where SuiteCRM will be accessed" \
            "For local dev, use http://localhost. For production, use your actual domain." \
            "Public URL for SuiteCRM access"
    else
        print_ok "SUITECRM_SITE_URL" "$value" "Public URL for SuiteCRM access"
    fi
    
    # SUITECRM_ADMIN_USER
    value=$(get_env_value "SUITECRM_ADMIN_USER")
    if is_placeholder "$value" || [[ -z "$value" ]]; then
        record_error "SUITECRM_ADMIN_USER" "$value" \
            "An admin username for SuiteCRM (e.g., admin)" \
            "This is the username you'll use to log into SuiteCRM." \
            "Admin login username"
    else
        print_ok "SUITECRM_ADMIN_USER" "$value" "Admin login username"
    fi
    
    # SUITECRM_ADMIN_PASSWORD
    value=$(get_env_value "SUITECRM_ADMIN_PASSWORD")
    if is_placeholder "$value"; then
        record_error "SUITECRM_ADMIN_PASSWORD" "$value" \
            "A strong admin password" \
            "Choose a secure password for the SuiteCRM admin account." \
            "Admin login password"
    elif ! is_valid_password "$value" 6; then
        print_warning "SUITECRM_ADMIN_PASSWORD" "$value" "consider longer password" \
            "Admin login password"
    else
        print_ok "SUITECRM_ADMIN_PASSWORD" "$value" "Admin login password"
    fi
    
    # SUITECRM_LOG_LEVEL
    value=$(get_env_value "SUITECRM_LOG_LEVEL")
    local valid_log_levels="off|fatal|error|warn|info|debug"
    if [[ -z "$value" ]]; then
        print_info "SUITECRM_LOG_LEVEL" "debug" "Application log verbosity"
    elif [[ ! "$value" =~ ^($valid_log_levels)$ ]]; then
        print_warning "SUITECRM_LOG_LEVEL" "$value" "valid: off, fatal, error, warn, info, debug" \
            "Application log verbosity"
    else
        print_ok "SUITECRM_LOG_LEVEL" "$value" "Application log verbosity"
    fi
    
    # SUITECRM_INSTALLER_LOCKED
    value=$(get_env_value "SUITECRM_INSTALLER_LOCKED")
    if [[ -z "$value" ]]; then
        print_info "SUITECRM_INSTALLER_LOCKED" "false" "Lock installer after setup"
    elif [[ "$value" != "true" && "$value" != "false" ]]; then
        print_warning "SUITECRM_INSTALLER_LOCKED" "$value" "should be true or false" \
            "Lock installer after setup"
    else
        print_ok "SUITECRM_INSTALLER_LOCKED" "$value" "Lock installer after setup"
    fi
}

validate_migration_source_config() {
    print_section "Migration Source: MySQL (Legacy Advertisers)"
    
    # These are for data migration, warn but don't fail if placeholders
    local value
    
    # MIGRATION_SOURCE_MYSQL_HOST
    value=$(get_env_value "MIGRATION_SOURCE_MYSQL_HOST")
    if [[ -z "$value" ]]; then
        print_info "MIGRATION_SOURCE_MYSQL_HOST" "localhost" "Legacy DB host"
    else
        print_ok "MIGRATION_SOURCE_MYSQL_HOST" "$value" "Legacy DB host"
    fi
    
    # MIGRATION_SOURCE_MYSQL_PORT
    value=$(get_env_value "MIGRATION_SOURCE_MYSQL_PORT")
    if [[ -z "$value" ]]; then
        print_info "MIGRATION_SOURCE_MYSQL_PORT" "3306" "Legacy DB port"
    else
        print_ok "MIGRATION_SOURCE_MYSQL_PORT" "$value" "Legacy DB port"
    fi
    
    # MIGRATION_SOURCE_MYSQL_NAME
    value=$(get_env_value "MIGRATION_SOURCE_MYSQL_NAME")
    if is_placeholder "$value"; then
        print_warning "MIGRATION_SOURCE_MYSQL_NAME" "$value" "set before migration" \
            "Legacy DB name for import"
    else
        print_ok "MIGRATION_SOURCE_MYSQL_NAME" "$value" "Legacy DB name for import"
    fi
    
    # MIGRATION_SOURCE_MYSQL_USER
    value=$(get_env_value "MIGRATION_SOURCE_MYSQL_USER")
    if is_placeholder "$value"; then
        print_warning "MIGRATION_SOURCE_MYSQL_USER" "$value" "set before migration" \
            "Legacy DB username for import"
    else
        print_ok "MIGRATION_SOURCE_MYSQL_USER" "$value" "Legacy DB username for import"
    fi
    
    # MIGRATION_SOURCE_MYSQL_PASSWORD
    value=$(get_env_value "MIGRATION_SOURCE_MYSQL_PASSWORD")
    if is_placeholder "$value"; then
        print_warning "MIGRATION_SOURCE_MYSQL_PASSWORD" "$value" "set before migration" \
            "Legacy DB password for import"
    else
        print_ok "MIGRATION_SOURCE_MYSQL_PASSWORD" "$value" "Legacy DB password for import"
    fi
}

validate_migration_dest_config() {
    print_section "Migration Destination: MySQL (SuiteCRM)"
    
    # These are for data migration, warn but don't fail if placeholders
    local value
    
    # MIGRATION_DEST_MYSQL_HOST
    value=$(get_env_value "MIGRATION_DEST_MYSQL_HOST")
    if [[ -z "$value" ]]; then
        print_info "MIGRATION_DEST_MYSQL_HOST" "localhost" "SuiteCRM DB host for migration"
    else
        print_ok "MIGRATION_DEST_MYSQL_HOST" "$value" "SuiteCRM DB host for migration"
    fi
    
    # MIGRATION_DEST_MYSQL_PORT
    value=$(get_env_value "MIGRATION_DEST_MYSQL_PORT")
    if [[ -z "$value" ]]; then
        print_info "MIGRATION_DEST_MYSQL_PORT" "3306" "SuiteCRM DB port for migration"
    else
        print_ok "MIGRATION_DEST_MYSQL_PORT" "$value" "SuiteCRM DB port for migration"
    fi
    
    # MIGRATION_DEST_MYSQL_NAME
    value=$(get_env_value "MIGRATION_DEST_MYSQL_NAME")
    if is_placeholder "$value"; then
        print_warning "MIGRATION_DEST_MYSQL_NAME" "$value" "set before migration" \
            "SuiteCRM DB name for migration"
    else
        print_ok "MIGRATION_DEST_MYSQL_NAME" "$value" "SuiteCRM DB name for migration"
    fi
    
    # MIGRATION_DEST_MYSQL_USER
    value=$(get_env_value "MIGRATION_DEST_MYSQL_USER")
    if is_placeholder "$value"; then
        print_warning "MIGRATION_DEST_MYSQL_USER" "$value" "set before migration" \
            "SuiteCRM DB username for migration"
    else
        print_ok "MIGRATION_DEST_MYSQL_USER" "$value" "SuiteCRM DB username for migration"
    fi
    
    # MIGRATION_DEST_MYSQL_PASSWORD
    value=$(get_env_value "MIGRATION_DEST_MYSQL_PASSWORD")
    if is_placeholder "$value"; then
        print_warning "MIGRATION_DEST_MYSQL_PASSWORD" "$value" "set before migration" \
            "SuiteCRM DB password for migration"
    else
        print_ok "MIGRATION_DEST_MYSQL_PASSWORD" "$value" "SuiteCRM DB password for migration"
    fi
}

validate_msaccess_config() {
    print_section "Legacy MS Access Database (Optional)"
    
    local value
    
    # BUZZ_ADVERT_MSACCESS_PATH
    value=$(get_env_value "BUZZ_ADVERT_MSACCESS_PATH")
    if is_placeholder "$value"; then
        print_info "BUZZ_ADVERT_MSACCESS_PATH" "(not configured)" "Path to Access .mdb file"
    else
        print_ok "BUZZ_ADVERT_MSACCESS_PATH" "$value" "Path to Access .mdb file"
    fi
    
    # BUZZ_ADVERT_MSACCESS_DRIVER
    value=$(get_env_value "BUZZ_ADVERT_MSACCESS_DRIVER")
    if [[ -z "$value" ]]; then
        print_info "BUZZ_ADVERT_MSACCESS_DRIVER" "MDBTools" "ODBC driver for Access"
    else
        print_ok "BUZZ_ADVERT_MSACCESS_DRIVER" "$value" "ODBC driver for Access"
    fi
    
    # BUZZ_ADVERT_MSACCESS_USER
    value=$(get_env_value "BUZZ_ADVERT_MSACCESS_USER")
    if is_placeholder "$value"; then
        print_info "BUZZ_ADVERT_MSACCESS_USER" "(not configured)" "Access database username"
    else
        print_ok "BUZZ_ADVERT_MSACCESS_USER" "$value" "Access database username"
    fi
    
    # BUZZ_ADVERT_MSACCESS_PASSWORD
    value=$(get_env_value "BUZZ_ADVERT_MSACCESS_PASSWORD")
    if is_placeholder "$value"; then
        print_info "BUZZ_ADVERT_MSACCESS_PASSWORD" "(not configured)" "Access database password"
    else
        print_ok "BUZZ_ADVERT_MSACCESS_PASSWORD" "$value" "Access database password"
    fi
}

validate_general_config() {
    print_section "General Configuration"
    
    local value
    
    # TZ
    value=$(get_env_value "TZ")
    if [[ -z "$value" ]]; then
        print_info "TZ" "America/Chicago" "Application timezone (Docker/Azure)"
    else
        print_ok "TZ" "$value" "Application timezone (Docker/Azure)"
    fi
    
    # LOGGING_TZ
    value=$(get_env_value "LOGGING_TZ")
    if [[ -z "$value" ]]; then
        print_info "LOGGING_TZ" "America/New_York" "Timezone for script logging"
    else
        print_ok "LOGGING_TZ" "$value" "Timezone for script logging"
    fi
    
    # SKIP_DB_WAIT
    value=$(get_env_value "SKIP_DB_WAIT")
    if [[ -z "$value" ]]; then
        print_info "SKIP_DB_WAIT" "false" "Skip DB wait on container startup"
    elif [[ "$value" != "true" && "$value" != "false" ]]; then
        print_warning "SKIP_DB_WAIT" "$value" "should be true or false" \
            "Skip DB wait on container startup"
    else
        print_ok "SKIP_DB_WAIT" "$value" "Skip DB wait on container startup"
    fi
    
    # AZURE_FILES_MOUNT_BASE
    value=$(get_env_value "AZURE_FILES_MOUNT_BASE")
    if [[ -z "$value" ]]; then
        print_info "AZURE_FILES_MOUNT_BASE" "/mnt/azure/suitecrm" "Local mount path for Azure Files"
    else
        print_ok "AZURE_FILES_MOUNT_BASE" "$value" "Local mount path for Azure Files"
    fi
    
    # BACKUP_DIR
    value=$(get_env_value "BACKUP_DIR")
    if [[ -z "$value" ]]; then
        print_info "BACKUP_DIR" "database/backups" "Directory for database backups"
    else
        print_ok "BACKUP_DIR" "$value" "Directory for database backups"
    fi
    
    # SCHEMA_BACKUP_DIR
    value=$(get_env_value "SCHEMA_BACKUP_DIR")
    if [[ -z "$value" ]]; then
        print_info "SCHEMA_BACKUP_DIR" "database/backups" "Directory for schema backups"
    else
        print_ok "SCHEMA_BACKUP_DIR" "$value" "Directory for schema backups"
    fi
}

# ============================================================================
# MAIN VALIDATION
# ============================================================================

validate_env_file() {
    # Check if .env file exists
    if [[ ! -f "$ENV_FILE" ]]; then
        echo -e "${RED}ERROR: .env file not found at $ENV_FILE${NC}"
        echo ""
        echo "To create it, run:"
        echo "  cp .env.example .env"
        echo ""
        echo "Then edit .env and fill in your values."
        exit 1
    fi
    
    print_header "Environment Variable Validation"
    
    if [[ "$QUIET_MODE" == "false" && "$ERRORS_ONLY_MODE" == "false" ]]; then
        echo ""
        echo "Checking: $ENV_FILE"
    fi
    
    # Run all validations
    validate_global_config
    validate_derived_prefixes
    validate_derived_passwords
    validate_azure_config
    validate_azure_provisioning_config
    validate_azure_storage_config
    validate_azure_acr_config
    validate_azure_container_apps_config
    validate_docker_config
    validate_suitecrm_runtime_mysql_config
    validate_suitecrm_config
    validate_migration_source_config
    validate_migration_dest_config
    validate_msaccess_config
    validate_general_config
    
    # Always print failure summary if there are failures (even in quiet mode)
    if [[ ${#FAILURE_VARS[@]} -gt 0 ]]; then
        print_failure_summary
        return 1
    fi
    
    # Print success summary
    if [[ "$QUIET_MODE" == "false" ]]; then
        if [[ "$ERRORS_ONLY_MODE" == "false" ]]; then
            echo ""
            if [[ "$WARNINGS_FOUND" -eq 0 ]]; then
                echo -e "${GREEN}✓ All validations passed!${NC}"
            else
                echo -e "${YELLOW}✓ Validations passed with $WARNINGS_FOUND warning(s)${NC}"
            fi
            echo ""
        fi
    fi
    
    return 0
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    parse_args "$@"
    
    if ! validate_env_file; then
        exit 1
    fi
    
    exit 0
}

main "$@"

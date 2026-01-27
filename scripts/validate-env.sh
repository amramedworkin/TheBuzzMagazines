#!/bin/bash
# ============================================================================
# Environment Variable Validation Script
# ============================================================================
# Validates that .env file is fully populated with no placeholders
# Returns exit code 0 if valid, 1 if invalid
#
# Usage:
#   ./validate-env.sh               # Full validation with detailed output
#   ./validate-env.sh --quiet       # Minimal output, just pass/fail
#   ./validate-env.sh --errors-only # Only show errors (for use by other scripts)
#   ./validate-env.sh --help        # Show help
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"

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

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
NC='\033[0m' # No Color

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
        # Expand nested variables
        AZURE_RESOURCE_GROUP="rg-${AZURE_RESOURCE_PREFIX}-suitecrm"
        AZURE_PROVISION_MYSQL_SERVER_NAME="${AZURE_RESOURCE_PREFIX}-mysql"
        AZURE_STORAGE_ACCOUNT_NAME="${AZURE_RESOURCE_PREFIX}storage"
        AZURE_ACR_NAME="${AZURE_RESOURCE_PREFIX}acr"
        SUITECRM_RUNTIME_MYSQL_HOST="${AZURE_PROVISION_MYSQL_SERVER_NAME}.mysql.database.azure.com"
        echo "${!var_name}"
    )
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

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
    
    # AZURE_PROVISION_MYSQL_SKU
    local value
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
}

validate_suitecrm_runtime_mysql_config() {
    print_section "SuiteCRM Runtime: MySQL Connection"
    
    # SUITECRM_RUNTIME_MYSQL_NAME
    local value
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
}

validate_suitecrm_config() {
    print_section "SuiteCRM Application Settings"
    
    # SUITECRM_SITE_URL
    local value
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
}

validate_migration_source_config() {
    print_section "Migration Source: MySQL (Legacy Advertisers)"
    
    # These are for data migration, warn but don't fail if placeholders
    local value
    
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
}

validate_general_config() {
    print_section "General Configuration"
    
    # TZ
    local value
    value=$(get_env_value "TZ")
    if [[ -z "$value" ]]; then
        print_info "TZ" "system default" "Timezone for logs and tasks"
    else
        print_ok "TZ" "$value" "Timezone for logs and tasks"
    fi
    
    # AZURE_FILES_MOUNT_BASE
    value=$(get_env_value "AZURE_FILES_MOUNT_BASE")
    if [[ -z "$value" ]]; then
        print_info "AZURE_FILES_MOUNT_BASE" "/mnt/azure/suitecrm" "Local mount path for Azure Files"
    else
        print_ok "AZURE_FILES_MOUNT_BASE" "$value" "Local mount path for Azure Files"
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
    validate_azure_config
    validate_azure_provisioning_config
    validate_suitecrm_runtime_mysql_config
    validate_suitecrm_config
    validate_migration_source_config
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

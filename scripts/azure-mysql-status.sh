#!/bin/bash
# ============================================================================
# Azure MySQL Database Status Script
# ============================================================================
# Tests the creation status and connectivity of the Azure MySQL database.
# Checks server existence, properties, firewall rules, and connection.
#
# Usage:
#   ./azure-mysql-status.sh              # Full status check
#   ./azure-mysql-status.sh --quick      # Quick server check only
#   ./azure-mysql-status.sh --connect    # Test MySQL connection
#   ./azure-mysql-status.sh -h           # Show help
# ============================================================================

# ============================================================================
# SCRIPT CONFIGURATION
# ============================================================================

SCRIPT_NAME="azure-mysql-status"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"
LOGS_DIR="${PROJECT_ROOT}/logs"

# Source common utilities (colors, logging, etc.)
source "$SCRIPT_DIR/lib/common.sh"

# Command-line options
QUICK_MODE=false
CONNECT_MODE=false

# Track results for summary
declare -a CHECK_NAMES
declare -a CHECK_RESULTS
declare -a CHECK_DETAILS

# ============================================================================
# LOGGING SETUP
# ============================================================================

setup_logging() {
    mkdir -p "$LOGS_DIR"
    local timestamp
    timestamp=$(TZ="${LOGGING_TZ:-America/New_York}" date +"%Y%m%d_%H%M%S")
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
        echo "Azure MySQL Status Log - $(TZ="${LOGGING_TZ:-America/New_York}" date)"
        echo "Timezone: ${LOGGING_TZ:-America/New_York}"
        echo "============================================================================"
        echo ""
    } >> "$LOG_FILE"
}

# Log to both console and file
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(TZ="${LOGGING_TZ:-America/New_York}" date +"%Y-%m-%d %H:%M:%S %Z")
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        INFO)    echo -e "${BLUE}[INFO]${NC} $message" ;;
        SUCCESS) echo -e "${GREEN}[PASS]${NC} $message" ;;
        FAIL)    echo -e "${RED}[FAIL]${NC} $message" ;;
        WARN)    echo -e "${YELLOW}[WARN]${NC} $message" ;;
        STEP)    echo -e "${CYAN}[CHECK]${NC} $message" ;;
        *)       echo "$message" ;;
    esac
}

log_info() { log "INFO" "$1"; }
log_pass() { log "SUCCESS" "$1"; }
log_fail() { log "FAIL" "$1"; }
log_warn() { log "WARN" "$1"; }
log_check() { log "STEP" "$1"; }

# ============================================================================
# RECORD RESULTS
# ============================================================================

record_result() {
    local check_name="$1"
    local result="$2"
    local details="$3"
    
    CHECK_NAMES+=("$check_name")
    CHECK_RESULTS+=("$result")
    CHECK_DETAILS+=("$details")
}

# ============================================================================
# HELP
# ============================================================================

show_help() {
    cat << 'EOF'
Azure MySQL Database Status Script

Tests the creation status and connectivity of the Azure MySQL database.

USAGE:
    ./azure-mysql-status.sh [OPTIONS]

OPTIONS:
    --quick, -q     Quick check - server existence only
    --connect, -c   Test MySQL connection with credentials
    --help, -h      Show this help message

EXAMPLES:
    ./azure-mysql-status.sh              # Full status check
    ./azure-mysql-status.sh --quick      # Quick server existence check
    ./azure-mysql-status.sh --connect    # Test actual MySQL connection

CHECKS PERFORMED:
    1. Azure CLI authentication status
    2. MySQL Flexible Server existence
    3. Server state (Ready, Stopped, etc.)
    4. Server properties (SKU, storage, version)
    5. Database existence
    6. Firewall rules
    7. MySQL connection test (--connect mode)

ENVIRONMENT VARIABLES USED:
    AZURE_SUBSCRIPTION_ID          - Azure subscription
    AZURE_RESOURCE_GROUP           - Resource group name
    AZURE_PROVISION_MYSQL_SERVER_NAME - MySQL server name
    SUITECRM_RUNTIME_MYSQL_*       - Connection credentials

EOF
    exit 0
}

# ============================================================================
# PARSE ARGUMENTS
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                ;;
            -q|--quick)
                QUICK_MODE=true
                shift
                ;;
            -c|--connect)
                CONNECT_MODE=true
                shift
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# ENVIRONMENT LOADING
# ============================================================================

load_env() {
    if [[ ! -f "$ENV_FILE" ]]; then
        log_fail ".env file not found at: $ENV_FILE"
        exit 1
    fi
    
    # Source the .env file
    set -a
    source "$ENV_FILE"
    set +a
    
    # Use common.sh expansion for derived variables
    load_env_common
    
    log_info "Loaded environment from: $ENV_FILE"
}

# ============================================================================
# CHECK: AZURE CLI AUTHENTICATION
# ============================================================================

check_azure_auth() {
    log_check "Azure CLI authentication"
    
    if ! command -v az &>/dev/null; then
        log_fail "Azure CLI (az) not installed"
        record_result "Azure CLI" "FAIL" "Not installed"
        return 1
    fi
    
    local account_info
    if ! account_info=$(az account show --query "{subscription:name,id:id}" -o tsv 2>/dev/null); then
        log_fail "Not logged into Azure CLI"
        record_result "Azure CLI Auth" "FAIL" "Not authenticated"
        echo ""
        echo -e "${YELLOW}Remediation:${NC}"
        echo "  Run: az login"
        echo ""
        return 1
    fi
    
    local sub_name sub_id
    sub_name=$(echo "$account_info" | cut -f1)
    sub_id=$(echo "$account_info" | cut -f2)
    
    log_pass "Logged into Azure: $sub_name"
    record_result "Azure CLI Auth" "PASS" "Subscription: $sub_name"
    
    # Check if correct subscription
    if [[ -n "$AZURE_SUBSCRIPTION_ID" && "$sub_id" != "$AZURE_SUBSCRIPTION_ID" ]]; then
        log_warn "Active subscription differs from .env AZURE_SUBSCRIPTION_ID"
        echo "  Expected: $AZURE_SUBSCRIPTION_ID"
        echo "  Active:   $sub_id"
    fi
    
    return 0
}

# ============================================================================
# CHECK: MYSQL SERVER EXISTS
# ============================================================================

check_mysql_server_exists() {
    log_check "MySQL Server existence: $AZURE_PROVISION_MYSQL_SERVER_NAME"
    
    if [[ -z "$AZURE_PROVISION_MYSQL_SERVER_NAME" ]]; then
        log_fail "AZURE_PROVISION_MYSQL_SERVER_NAME not set in .env"
        record_result "MySQL Server" "FAIL" "Variable not configured"
        return 1
    fi
    
    if [[ -z "$AZURE_RESOURCE_GROUP" ]]; then
        log_fail "AZURE_RESOURCE_GROUP not set in .env"
        record_result "MySQL Server" "FAIL" "Resource group not configured"
        return 1
    fi
    
    local server_info
    if ! server_info=$(az mysql flexible-server show \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$AZURE_PROVISION_MYSQL_SERVER_NAME" \
        -o json 2>/dev/null); then
        log_fail "MySQL Server '$AZURE_PROVISION_MYSQL_SERVER_NAME' does not exist"
        record_result "MySQL Server" "FAIL" "Not provisioned"
        echo ""
        echo -e "${YELLOW}Remediation:${NC}"
        echo "  Run: ./scripts/cli.sh provision"
        echo "  Or:  ./scripts/azure-provision-infra.sh"
        echo ""
        return 1
    fi
    
    log_pass "MySQL Server exists: $AZURE_PROVISION_MYSQL_SERVER_NAME"
    record_result "MySQL Server" "PASS" "Exists in $AZURE_RESOURCE_GROUP"
    
    # Store for later use
    SERVER_INFO="$server_info"
    return 0
}

# ============================================================================
# CHECK: MYSQL SERVER STATE
# ============================================================================

check_mysql_server_state() {
    log_check "MySQL Server state"
    
    if [[ -z "$SERVER_INFO" ]]; then
        log_warn "Server info not available - skipping state check"
        record_result "Server State" "SKIP" "Server not found"
        return 1
    fi
    
    local state
    state=$(echo "$SERVER_INFO" | jq -r '.state // "Unknown"')
    
    case "$state" in
        Ready)
            log_pass "Server state: $state"
            record_result "Server State" "PASS" "$state"
            return 0
            ;;
        Starting|Updating)
            log_warn "Server state: $state (may become ready soon)"
            record_result "Server State" "WARN" "$state"
            return 0
            ;;
        Stopped|Stopping)
            log_fail "Server state: $state"
            record_result "Server State" "FAIL" "$state - server is stopped"
            echo ""
            echo -e "${YELLOW}Remediation:${NC}"
            echo "  Start the server: az mysql flexible-server start \\"
            echo "    --resource-group $AZURE_RESOURCE_GROUP \\"
            echo "    --name $AZURE_PROVISION_MYSQL_SERVER_NAME"
            echo ""
            return 1
            ;;
        *)
            log_warn "Server state: $state"
            record_result "Server State" "WARN" "$state"
            return 0
            ;;
    esac
}

# ============================================================================
# CHECK: MYSQL SERVER PROPERTIES
# ============================================================================

check_mysql_server_properties() {
    log_check "MySQL Server properties"
    
    if [[ -z "$SERVER_INFO" ]]; then
        record_result "Server Properties" "SKIP" "Server not found"
        return 1
    fi
    
    local sku version storage_gb fqdn
    sku=$(echo "$SERVER_INFO" | jq -r '.sku.name // "Unknown"')
    version=$(echo "$SERVER_INFO" | jq -r '.version // "Unknown"')
    storage_gb=$(echo "$SERVER_INFO" | jq -r '.storage.storageSizeGb // "Unknown"')
    fqdn=$(echo "$SERVER_INFO" | jq -r '.fullyQualifiedDomainName // "Unknown"')
    
    echo -e "  ${DIM}SKU:${NC}      $sku"
    echo -e "  ${DIM}Version:${NC}  MySQL $version"
    echo -e "  ${DIM}Storage:${NC}  ${storage_gb} GB"
    echo -e "  ${DIM}FQDN:${NC}     $fqdn"
    
    record_result "Server Properties" "PASS" "SKU: $sku, MySQL $version, ${storage_gb}GB"
    
    # Log to file
    echo "Server Properties:" >> "$LOG_FILE"
    echo "  SKU: $sku" >> "$LOG_FILE"
    echo "  Version: $version" >> "$LOG_FILE"
    echo "  Storage: ${storage_gb}GB" >> "$LOG_FILE"
    echo "  FQDN: $fqdn" >> "$LOG_FILE"
    
    # Store FQDN for connection test
    SERVER_FQDN="$fqdn"
    
    return 0
}

# ============================================================================
# CHECK: DATABASE EXISTS
# ============================================================================

check_database_exists() {
    local db_name="${SUITECRM_RUNTIME_MYSQL_NAME:-suitecrm}"
    
    log_check "Database existence: $db_name"
    
    if ! az mysql flexible-server db show \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --server-name "$AZURE_PROVISION_MYSQL_SERVER_NAME" \
        --database-name "$db_name" &>/dev/null; then
        log_fail "Database '$db_name' does not exist"
        record_result "Database" "FAIL" "Database not created"
        echo ""
        echo -e "${YELLOW}Remediation:${NC}"
        echo "  The database should be created during provisioning."
        echo "  Re-run: ./scripts/cli.sh provision"
        echo ""
        return 1
    fi
    
    log_pass "Database '$db_name' exists"
    record_result "Database" "PASS" "Exists on server"
    return 0
}

# ============================================================================
# CHECK: FIREWALL RULES
# ============================================================================

check_firewall_rules() {
    log_check "Firewall rules"
    
    local rules_json
    if ! rules_json=$(az mysql flexible-server firewall-rule list \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$AZURE_PROVISION_MYSQL_SERVER_NAME" \
        -o json 2>/dev/null); then
        log_warn "Could not retrieve firewall rules"
        record_result "Firewall Rules" "WARN" "Unable to check"
        return 1
    fi
    
    local rule_count
    rule_count=$(echo "$rules_json" | jq 'length')
    
    if [[ "$rule_count" -eq 0 ]]; then
        log_warn "No firewall rules configured - connections may be blocked"
        record_result "Firewall Rules" "WARN" "No rules configured"
        echo ""
        echo -e "${YELLOW}Note:${NC}"
        echo "  If using Azure services, enable 'Allow Azure services' in firewall settings."
        echo "  For local development, add your IP address."
        echo ""
        return 0
    fi
    
    log_pass "Firewall rules configured: $rule_count rule(s)"
    record_result "Firewall Rules" "PASS" "$rule_count rule(s)"
    
    # List rules
    echo "$rules_json" | jq -r '.[] | "  - \(.name): \(.startIpAddress) - \(.endIpAddress)"'
    
    return 0
}

# ============================================================================
# CHECK: SSL CONFIGURATION
# ============================================================================

check_ssl_config() {
    log_check "SSL configuration"
    
    if [[ -z "$SERVER_INFO" ]]; then
        record_result "SSL Config" "SKIP" "Server not found"
        return 1
    fi
    
    local ssl_enforcement
    ssl_enforcement=$(echo "$SERVER_INFO" | jq -r '.storage.sslEnforcement // .sslEnforcement // "Unknown"')
    
    # Check server parameters for ssl requirement
    local require_ssl
    require_ssl=$(az mysql flexible-server parameter show \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --server-name "$AZURE_PROVISION_MYSQL_SERVER_NAME" \
        --name require_secure_transport \
        --query value -o tsv 2>/dev/null || echo "Unknown")
    
    if [[ "$require_ssl" == "ON" ]]; then
        log_pass "SSL enforcement: Enabled (require_secure_transport=ON)"
        record_result "SSL Config" "PASS" "SSL required"
    elif [[ "$require_ssl" == "OFF" ]]; then
        log_warn "SSL enforcement: Disabled (require_secure_transport=OFF)"
        record_result "SSL Config" "WARN" "SSL not required"
    else
        log_info "SSL enforcement: $require_ssl"
        record_result "SSL Config" "INFO" "$require_ssl"
    fi
    
    return 0
}

# ============================================================================
# CHECK: MYSQL CONNECTION TEST
# ============================================================================

check_mysql_connection() {
    log_check "MySQL connection test"
    
    # Check if mysql client is available
    if ! command -v mysql &>/dev/null; then
        log_warn "MySQL client not installed - cannot test connection"
        record_result "Connection Test" "SKIP" "mysql client not installed"
        echo ""
        echo -e "${YELLOW}To install:${NC}"
        echo "  Ubuntu/Debian: sudo apt install mysql-client"
        echo "  macOS:         brew install mysql-client"
        echo ""
        return 1
    fi
    
    local host="${SERVER_FQDN:-${SUITECRM_RUNTIME_MYSQL_HOST}}"
    local port="${SUITECRM_RUNTIME_MYSQL_PORT:-3306}"
    local user="${SUITECRM_RUNTIME_MYSQL_USER}"
    local pass="${SUITECRM_RUNTIME_MYSQL_PASSWORD}"
    local db="${SUITECRM_RUNTIME_MYSQL_NAME:-suitecrm}"
    local ssl_enabled="${SUITECRM_RUNTIME_MYSQL_SSL_ENABLED:-true}"
    
    if [[ -z "$user" || -z "$pass" ]]; then
        log_fail "MySQL credentials not configured in .env"
        record_result "Connection Test" "FAIL" "Credentials missing"
        return 1
    fi
    
    echo -e "  ${DIM}Host:${NC} $host"
    echo -e "  ${DIM}Port:${NC} $port"
    echo -e "  ${DIM}User:${NC} $user"
    echo -e "  ${DIM}DB:${NC}   $db"
    echo -e "  ${DIM}SSL:${NC}  $ssl_enabled"
    
    # Build connection command
    local mysql_cmd="mysql -h \"$host\" -P \"$port\" -u \"$user\" -p\"$pass\" \"$db\" -e \"SELECT 1 AS connected;\""
    
    if [[ "$ssl_enabled" == "true" ]]; then
        local ssl_ca="${SUITECRM_RUNTIME_MYSQL_SSL_CA:-/etc/ssl/certs/ca-certificates.crt}"
        mysql_cmd="mysql -h \"$host\" -P \"$port\" -u \"$user\" -p\"$pass\" \"$db\" --ssl-mode=REQUIRED --ssl-ca=\"$ssl_ca\" -e \"SELECT 1 AS connected;\""
    fi
    
    echo ""
    echo -e "  ${DIM}Testing connection...${NC}"
    
    local result
    if result=$(eval "$mysql_cmd" 2>&1); then
        log_pass "MySQL connection successful"
        record_result "Connection Test" "PASS" "Connected to $db@$host"
        return 0
    else
        log_fail "MySQL connection failed"
        record_result "Connection Test" "FAIL" "Connection refused"
        echo ""
        echo -e "${RED}Connection error:${NC}"
        echo "$result" | head -5
        echo ""
        echo -e "${YELLOW}Possible causes:${NC}"
        echo "  - Firewall blocking your IP"
        echo "  - Wrong credentials in .env"
        echo "  - Server not running (check state)"
        echo "  - SSL configuration mismatch"
        echo ""
        return 1
    fi
}

# ============================================================================
# PRINT SUMMARY TABLE
# ============================================================================

print_summary() {
    echo ""
    echo "============================================================================"
    echo "                        AZURE MYSQL STATUS SUMMARY"
    echo "============================================================================"
    echo ""
    
    # Calculate column widths
    local check_width=25
    local result_width=8
    local details_width=45
    
    # Print header
    printf "  %-${check_width}s %-${result_width}s %s\n" "Check" "Result" "Details"
    printf "  %-${check_width}s %-${result_width}s %s\n" "$(printf '%0.s-' {1..25})" "$(printf '%0.s-' {1..8})" "$(printf '%0.s-' {1..45})"
    
    local pass_count=0
    local fail_count=0
    local warn_count=0
    
    for i in "${!CHECK_NAMES[@]}"; do
        local name="${CHECK_NAMES[$i]}"
        local result="${CHECK_RESULTS[$i]}"
        local details="${CHECK_DETAILS[$i]}"
        
        # Color the result
        local colored_result
        case "$result" in
            PASS)
                colored_result="${GREEN}PASS${NC}"
                ((pass_count++))
                ;;
            FAIL)
                colored_result="${RED}FAIL${NC}"
                ((fail_count++))
                ;;
            WARN)
                colored_result="${YELLOW}WARN${NC}"
                ((warn_count++))
                ;;
            SKIP)
                colored_result="${DIM}SKIP${NC}"
                ;;
            *)
                colored_result="$result"
                ;;
        esac
        
        printf "  %-${check_width}s %-${result_width}b %s\n" "$name" "$colored_result" "$details"
    done
    
    echo ""
    printf "  %-${check_width}s %-${result_width}s %s\n" "$(printf '%0.s-' {1..25})" "$(printf '%0.s-' {1..8})" "$(printf '%0.s-' {1..45})"
    
    # Overall status
    echo ""
    if [[ $fail_count -eq 0 && $warn_count -eq 0 ]]; then
        echo -e "  ${GREEN}✓ All checks passed${NC}"
    elif [[ $fail_count -eq 0 ]]; then
        echo -e "  ${YELLOW}⚠ Passed with $warn_count warning(s)${NC}"
    else
        echo -e "  ${RED}✗ $fail_count check(s) failed${NC}"
    fi
    
    echo ""
    echo "  Log file: $LOG_FILE"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    parse_args "$@"
    setup_logging
    load_env
    
    echo ""
    echo "============================================================================"
    echo "                    AZURE MYSQL DATABASE STATUS CHECK"
    echo "============================================================================"
    echo ""
    echo -e "  ${DIM}Server:${NC} ${AZURE_PROVISION_MYSQL_SERVER_NAME}"
    echo -e "  ${DIM}Resource Group:${NC} ${AZURE_RESOURCE_GROUP}"
    echo ""
    echo "----------------------------------------------------------------------------"
    echo ""
    
    # Check Azure authentication
    if ! check_azure_auth; then
        print_summary
        exit 1
    fi
    
    # Check server exists
    if ! check_mysql_server_exists; then
        print_summary
        exit 1
    fi
    
    # Quick mode stops here
    if [[ "$QUICK_MODE" == "true" ]]; then
        print_summary
        exit 0
    fi
    
    # Full checks
    check_mysql_server_state
    check_mysql_server_properties
    check_database_exists
    check_firewall_rules
    check_ssl_config
    
    # Connection test (if requested or in connect mode)
    if [[ "$CONNECT_MODE" == "true" ]]; then
        check_mysql_connection
    fi
    
    print_summary
    
    # Return exit code based on failures
    local fail_count=0
    for result in "${CHECK_RESULTS[@]}"; do
        if [[ "$result" == "FAIL" ]]; then
            ((fail_count++))
        fi
    done
    
    if [[ $fail_count -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main "$@"

#!/bin/bash
# ============================================================================
# Common Utilities for TheBuzzMagazines Scripts
# ============================================================================
# Shared colors, logging functions, and utilities used across all scripts.
# Source this file at the top of each script:
#   source "$SCRIPT_DIR/lib/common.sh"
# ============================================================================

# Prevent multiple sourcing
[[ -n "$_COMMON_SH_LOADED" ]] && return
_COMMON_SH_LOADED=1

# ============================================================================
# VERBOSE MODE CONTROL
# ============================================================================
# Controls console output verbosity. Default is simple mode (false).
# In simple mode, only action results and errors are shown on console.
# In verbose mode (true), all logging is shown (current behavior).
# File logging is always full regardless of this setting.
# ============================================================================

VERBOSE_MODE=${VERBOSE_MODE:-false}

# ============================================================================
# COLOR DEFINITIONS
# ============================================================================
# Standard terminal colors for consistent output across all scripts.
# Usage: echo -e "${GREEN}Success!${NC}"
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
NC='\033[0m'  # No Color / Reset

# Extended colors for menus and special UI
SUBMENU_COLOR='\033[1;36m'  # Bold Cyan for submenu titles
SUBMENU_DESC='\033[0;90m'   # Dark gray for submenu descriptions
ACTION_COLOR='\033[0;37m'   # Standard white for action items

# ============================================================================
# LOGGING SETUP
# ============================================================================
# Call setup_logging at the start of your script to initialize logging.
# Requires: SCRIPT_NAME, LOGS_DIR to be set before calling.
# Sets: LOG_FILE variable with the path to the log file.
# ============================================================================

setup_logging() {
    # Ensure logs directory exists
    mkdir -p "$LOGS_DIR"
    
    # Generate timestamp using configured logging timezone
    local timestamp
    timestamp=$(TZ="${LOGGING_TZ:-America/New_York}" date +"%Y%m%d_%H%M%S")
    
    # New log filename with "latest_" prefix
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
    
    # Write log header
    {
        echo "============================================================================"
        echo "${SCRIPT_NAME} Log - Started at $(TZ="${LOGGING_TZ:-America/New_York}" date)"
        echo "Timezone: ${LOGGING_TZ:-America/New_York} (Eastern US)"
        echo "============================================================================"
        echo ""
    } >> "$LOG_FILE"
}

# ============================================================================
# CORE LOGGING FUNCTION
# ============================================================================
# Usage: log "LEVEL" "message"
# Levels: INFO, SUCCESS, WARN, ERROR, STEP, CHECK, OK, FAIL, PHASE
# ============================================================================

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(TZ="${LOGGING_TZ:-America/New_York}" date +"%Y-%m-%d %H:%M:%S %Z")
    
    # Write to log file if LOG_FILE is set (always, regardless of VERBOSE_MODE)
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
    
    # Console output controlled by VERBOSE_MODE
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        # Verbose mode: show all levels (current behavior)
        case "$level" in
            INFO)    echo -e "${BLUE}[INFO]${NC} $message" ;;
            SUCCESS) echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
            WARN)    echo -e "${YELLOW}[WARN]${NC} $message" ;;
            ERROR)   echo -e "${RED}[ERROR]${NC} $message" ;;
            STEP)    echo -e "${CYAN}[STEP]${NC} $message" ;;
            # Validation-specific levels
            CHECK)   echo -e "${CYAN}[CHECK]${NC} $message" ;;
            OK)      echo -e "${GREEN}[OK]${NC} $message" ;;
            FAIL)    echo -e "${RED}[FAIL]${NC} $message" ;;
            SKIP)    echo -e "${YELLOW}[SKIP]${NC} $message" ;;
            # Lifecycle validation with Unicode symbols
            PASS)    echo -e "${GREEN}[✓]${NC} $message" ;;
            FAILED)  echo -e "${RED}[✗]${NC} $message" ;;
            WARNING) echo -e "${YELLOW}[⚠]${NC} $message" ;;
            ARROW)   echo -e "${CYAN}[→]${NC} $message" ;;
            PHASE)   echo -e "${MAGENTA}${BOLD}[$message]${NC}" ;;
            # ACTION level for simple mode output (always shown)
            ACTION)  echo -e "$message" ;;
            *)       echo "$message" ;;
        esac
    else
        # Simple mode: only show errors, warnings, and ACTION results
        case "$level" in
            ERROR)   echo -e "${RED}[ERROR]${NC} $message" ;;
            WARN)    echo -e "${YELLOW}[WARN]${NC} $message" ;;
            FAIL)    echo -e "${RED}[FAIL]${NC} $message" ;;
            FAILED)  echo -e "${RED}[✗]${NC} $message" ;;
            # ACTION level for simple mode output
            ACTION)  echo -e "$message" ;;
            # Skip all other levels in simple mode
            *)       ;;
        esac
    fi
}

# ============================================================================
# STANDARD LOGGING HELPERS
# ============================================================================
# Convenience wrappers for common log levels.
# ============================================================================

log_info()    { log "INFO" "$1"; }
log_success() { log "SUCCESS" "$1"; }
log_warn()    { log "WARN" "$1"; }
log_error()   { log "ERROR" "$1"; }
log_step()    { log "STEP" "$1"; }

# Validation script helpers
log_check()   { log "CHECK" "$1"; }
log_ok()      { log "OK" "$1"; }
log_fail()    { log "FAIL" "$1"; }
log_skip()    { log "SKIP" "$1"; }

# Log command output to file only
log_cmd_output() {
    if [[ -n "$LOG_FILE" ]]; then
        echo "$1" >> "$LOG_FILE"
    fi
}

# ============================================================================
# SIMPLE MODE ACTION LOGGING
# ============================================================================
# For simple mode output: "Action...result (detail)"
# Usage: log_action "Resource name" "succeeded|skipped|failed" "optional detail"
# ============================================================================

log_action() {
    local action="$1"
    local result="$2"   # succeeded, skipped, failed
    local detail="$3"   # Optional detail
    
    local result_text
    case "$result" in
        succeeded) result_text="${GREEN}succeeded${NC}" ;;
        skipped)   result_text="${YELLOW}skipped${NC}" ;;
        failed)    result_text="${RED}failed${NC}" ;;
        *)         result_text="$result" ;;
    esac
    
    local full_message
    if [[ -n "$detail" ]]; then
        full_message="${action}...${result_text} (${detail})"
    else
        full_message="${action}...${result_text}"
    fi
    
    log "ACTION" "$full_message"
}

# ============================================================================
# FINALIZE LOGGING
# ============================================================================
# Call this at script end (typically in a trap) to write completion footer.
# ============================================================================

finalize_log() {
    if [[ -n "$LOG_FILE" ]]; then
        {
            echo ""
            echo "============================================================================"
            echo "SCRIPT COMPLETED"
            echo "============================================================================"
            echo "End Time: $(TZ="${LOGGING_TZ:-America/New_York}" date)"
            echo "============================================================================"
        } >> "$LOG_FILE"
    fi
}

# ============================================================================
# ENVIRONMENT LOADING
# ============================================================================
# Common environment loading with variable expansion for derived values.
# Requires: ENV_FILE to be set.
# ============================================================================

load_env_common() {
    if [[ ! -f "$ENV_FILE" ]]; then
        return 1
    fi
    
    set -a
    source "$ENV_FILE"
    set +a
    
    # Expand GLOBAL_* derived variables
    eval "AZURE_RESOURCE_PREFIX=${AZURE_RESOURCE_PREFIX:-${GLOBAL_PREFIX}}"
    eval "DOCKER_PREFIX=${DOCKER_PREFIX:-${GLOBAL_PREFIX}}"
    eval "SUITECRM_PASSWORD=${SUITECRM_PASSWORD:-${GLOBAL_PASSWORD}}"
    eval "AZURE_PASSWORD=${AZURE_PASSWORD:-${GLOBAL_PASSWORD}}"
    eval "DOCKER_PASSWORD=${DOCKER_PASSWORD:-${GLOBAL_PASSWORD}}"
    
    # Expand Azure nested variables
    eval "AZURE_RESOURCE_GROUP=${AZURE_RESOURCE_GROUP:-${AZURE_RESOURCE_PREFIX}-rg}"
    eval "AZURE_PROVISION_MYSQL_SERVER_NAME=${AZURE_PROVISION_MYSQL_SERVER_NAME:-${AZURE_RESOURCE_PREFIX}-mysql}"
    eval "AZURE_STORAGE_ACCOUNT_NAME=${AZURE_STORAGE_ACCOUNT_NAME:-${AZURE_RESOURCE_PREFIX}storage}"
    eval "AZURE_ACR_NAME=${AZURE_ACR_NAME:-${AZURE_RESOURCE_PREFIX}acr}"
    eval "AZURE_CONTAINER_APP_ENV=${AZURE_CONTAINER_APP_ENV:-${AZURE_RESOURCE_PREFIX}-cae}"
    
    # Expand Docker nested variables
    eval "DOCKER_IMAGE_NAME=${DOCKER_IMAGE_NAME:-${DOCKER_PREFIX}-suitecrm}"
    eval "DOCKER_CONTAINER_NAME=${DOCKER_CONTAINER_NAME:-${DOCKER_PREFIX}-suitecrm-web}"
    eval "DOCKER_NETWORK_NAME=${DOCKER_NETWORK_NAME:-${DOCKER_PREFIX}-suitecrm-network}"
    
    # Expand Azure Files share variables
    eval "AZURE_FILES_SHARE_PREFIX=${AZURE_FILES_SHARE_PREFIX:-${DOCKER_PREFIX}-suitecrm}"
    eval "AZURE_FILES_CREDENTIALS_FILE=${AZURE_FILES_CREDENTIALS_FILE:-/etc/azure-${GLOBAL_PREFIX}-credentials}"
    
    # Expand MySQL host
    eval "SUITECRM_RUNTIME_MYSQL_HOST=${SUITECRM_RUNTIME_MYSQL_HOST:-${AZURE_PROVISION_MYSQL_SERVER_NAME}.mysql.database.azure.com}"
    
    # Expand password-derived variables
    eval "SUITECRM_RUNTIME_MYSQL_PASSWORD=${SUITECRM_RUNTIME_MYSQL_PASSWORD:-${SUITECRM_PASSWORD}}"
    eval "SUITECRM_ADMIN_PASSWORD=${SUITECRM_ADMIN_PASSWORD:-${SUITECRM_PASSWORD}}"
    
    return 0
}

# ============================================================================
# INTERACTIVE MODE HELPERS
# ============================================================================
# Common patterns for interactive script execution.
# ============================================================================

confirm_step() {
    local step_name="$1"
    local step_description="$2"
    
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        echo ""
        echo -e "${YELLOW}>>> Next Step: $step_name${NC}"
        echo "    $step_description"
        echo ""
        read -p "    Press Enter to continue, or Ctrl+C to abort... " -r
        echo ""
    fi
    
    log_step "Starting: $step_name"
}

# ============================================================================
# ERROR HANDLING
# ============================================================================
# Common error handling with diagnostics.
# Requires: SCRIPT_SUCCESS, FAILED_STEP, LOG_FILE to be set.
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
    if [[ -n "$LOG_FILE" ]]; then
        {
            echo ""
            echo "============================================================================"
            echo "FAILURE DIAGNOSTICS"
            echo "============================================================================"
            echo "Failed Step: $step"
            echo "Exit Code: $exit_code"
            echo "Error Message: $error_msg"
            echo "Timestamp: $(TZ="${LOGGING_TZ:-America/New_York}" date)"
            echo "============================================================================"
        } >> "$LOG_FILE"
    fi
    
    echo ""
    log_error "Script failed at step: $step"
    if [[ -n "$LOG_FILE" ]]; then
        log_error "See log file for details: $LOG_FILE"
    fi
    echo ""
    
    exit "$exit_code"
}

# ============================================================================
# PRINT HELPERS FOR MENUS
# ============================================================================
# Consistent menu formatting across scripts.
# ============================================================================

print_header() {
    if [[ -n "$1" ]]; then
        echo ""
        echo -e "${BOLD}============================================================================${NC}"
        echo -e "${BOLD}$1${NC}"
        echo -e "${BOLD}============================================================================${NC}"
    fi
}

print_section() {
    if [[ -n "$1" ]]; then
        echo ""
        echo -e "${CYAN}--- $1 ---${NC}"
    fi
}

print_submenu_option() {
    local key="$1"
    local title="$2"
    local description="$3"
    
    echo -e "    ${BOLD}${key})${NC}  ${SUBMENU_COLOR}${title}${NC}"
    if [[ -n "$description" ]]; then
        echo -e "        ${SUBMENU_DESC}${description}${NC}"
    fi
}

print_action_option() {
    local key="$1"
    local title="$2"
    
    echo -e "    ${BOLD}${key})${NC}  ${ACTION_COLOR}${title}${NC}"
}

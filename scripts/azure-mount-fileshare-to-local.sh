#!/bin/bash
# ============================================================================
# Azure Files Mount Script for Local Development
# ============================================================================
# Mounts Azure File shares to local directories for Docker bind mounts
# Reads configuration from .env file
#
# Usage:
#   sudo ./azure-mount-fileshare-to-local.sh              # Interactive mode, mount shares
#   sudo ./azure-mount-fileshare-to-local.sh -y           # Non-interactive mode
#   sudo ./azure-mount-fileshare-to-local.sh unmount      # Unmount shares
#   sudo ./azure-mount-fileshare-to-local.sh unmount -y   # Unmount without prompts
# ============================================================================

# ============================================================================
# SCRIPT CONFIGURATION
# ============================================================================

SCRIPT_NAME="azure-mount-fileshare-to-local"
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

# Action to perform
ACTION="mount"

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
        echo "Azure Mount Log - Started at $(TZ='America/New_York' date)"
        echo "Timezone: America/New_York (Eastern US)"
        echo "Action: $ACTION"
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
        "check_prerequisites")
            echo "  - cifs-utils not installed (run: sudo apt-get install cifs-utils)" >> "$LOG_FILE"
            echo "  - Script not run with sudo" >> "$LOG_FILE"
            ;;
        "load_env")
            echo "  - .env file not found" >> "$LOG_FILE"
            echo "  - Required variables not set" >> "$LOG_FILE"
            ;;
        "get_storage_key")
            echo "  - Azure CLI not logged in" >> "$LOG_FILE"
            echo "  - Storage account does not exist (run azure-provision-infra.sh first)" >> "$LOG_FILE"
            echo "  - Insufficient permissions" >> "$LOG_FILE"
            ;;
        "mount_share")
            echo "  - Network connectivity issues to Azure" >> "$LOG_FILE"
            echo "  - Firewall blocking SMB port 445" >> "$LOG_FILE"
            echo "  - Invalid storage account credentials" >> "$LOG_FILE"
            echo "  - Mount point already in use" >> "$LOG_FILE"
            ;;
        "create_fstab")
            echo "  - Insufficient permissions to write /etc/fstab" >> "$LOG_FILE"
            echo "  - Invalid credentials file path" >> "$LOG_FILE"
            ;;
        *)
            echo "  - Unknown error - check system logs for details" >> "$LOG_FILE"
            ;;
    esac
    
    echo "" >> "$LOG_FILE"
    echo "Log file: $LOG_FILE" >> "$LOG_FILE"
    
    echo ""
    log_error "Mount operation failed at step: $step"
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
                echo "Usage: sudo $0 [mount|unmount] [-y|--yes]"
                echo ""
                echo "Commands:"
                echo "  mount      Mount Azure File shares (default)"
                echo "  unmount    Unmount Azure File shares"
                echo ""
                echo "Options:"
                echo "  -y, --yes    Run without prompting for confirmation at each step"
                echo "  -h, --help   Show this help message"
                exit 0
                ;;
            mount)
                ACTION="mount"
                shift
                ;;
            unmount)
                ACTION="unmount"
                shift
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
        handle_error "load_env" ".env file not found at $ENV_FILE"
    fi

    log_info "Loading configuration from $ENV_FILE"
    
    set -a
    source "$ENV_FILE"
    set +a

    # Expand nested variables from .env (they use ${AZURE_RESOURCE_PREFIX})
    # These are evaluated here because bash doesn't expand nested vars on source
    eval "AZURE_STORAGE_ACCOUNT_NAME=$AZURE_STORAGE_ACCOUNT_NAME"
    eval "AZURE_RESOURCE_GROUP=$AZURE_RESOURCE_GROUP"
    MOUNT_BASE="${AZURE_FILES_MOUNT_BASE}"

    log_info "Storage account: $AZURE_STORAGE_ACCOUNT_NAME"
    log_info "Mount base: $MOUNT_BASE"
    
    log_success "Environment loaded"
}

# ============================================================================
# GET STORAGE KEY
# ============================================================================

get_storage_key() {
    confirm_step "Get Storage Key" "Retrieve or load Azure Storage account key"
    
    # Try to load from secrets file first
    if [[ -f "$SECRETS_FILE" ]]; then
        log_info "Loading storage key from $SECRETS_FILE"
        source "$SECRETS_FILE"
    fi

    # If no storage key, try to fetch it from Azure
    if [[ -z "$AZURE_STORAGE_KEY" ]]; then
        log_info "Fetching storage key from Azure..."
        
        local output
        if ! AZURE_STORAGE_KEY=$(az storage account keys list \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --account-name "$AZURE_STORAGE_ACCOUNT_NAME" \
            --query '[0].value' -o tsv 2>&1); then
            log_cmd_output "$AZURE_STORAGE_KEY"
            handle_error "get_storage_key" "Failed to retrieve storage key from Azure. Run azure-provision-infra.sh first or ensure you're logged into Azure CLI."
        fi
        
        # Save for future use
        log_info "Saving storage key to $SECRETS_FILE"
        echo "AZURE_STORAGE_KEY=$AZURE_STORAGE_KEY" > "$SECRETS_FILE"
        chmod 600 "$SECRETS_FILE"
    fi
    
    log_success "Storage key available"
}

# ============================================================================
# CHECK PREREQUISITES
# ============================================================================

check_prerequisites() {
    confirm_step "Check Prerequisites" "Verify cifs-utils installation and root privileges"
    
    log_info "Checking for cifs-utils..."
    if ! command -v mount.cifs &> /dev/null; then
        handle_error "check_prerequisites" "cifs-utils is not installed. Install with: sudo apt-get install cifs-utils"
    fi
    log_success "cifs-utils is installed"

    log_info "Checking root privileges..."
    if [[ $EUID -ne 0 ]]; then
        handle_error "check_prerequisites" "This script must be run with sudo. Run: sudo $0"
    fi
    log_success "Running with root privileges"

    log_success "Prerequisites OK"
}

# ============================================================================
# MOUNT SHARES
# ============================================================================

mount_shares() {
    confirm_step "Mount Shares" "Create mount points and mount Azure File shares"
    
    local shares=("upload" "custom" "cache")
    local failed_mounts=0
    
    for share in "${shares[@]}"; do
        local mount_point="${MOUNT_BASE}/${share}"
        local share_name="suitecrm-${share}"
        local unc_path="//${AZURE_STORAGE_ACCOUNT_NAME}.file.core.windows.net/${share_name}"

        log_info "Processing share: $share_name -> $mount_point"

        # Create mount point
        if [[ ! -d "$mount_point" ]]; then
            log_info "  Creating mount point directory..."
            if ! mkdir -p "$mount_point" 2>&1; then
                log_error "  Failed to create mount point: $mount_point"
                ((failed_mounts++))
                continue
            fi
        fi

        # Check if already mounted
        if mountpoint -q "$mount_point" 2>/dev/null; then
            log_warn "  $mount_point is already mounted - skipping"
            continue
        fi

        # Mount the share
        log_info "  Mounting $share_name..."
        local mount_output
        if ! mount_output=$(mount -t cifs "$unc_path" "$mount_point" \
            -o "vers=3.0,username=${AZURE_STORAGE_ACCOUNT_NAME},password=${AZURE_STORAGE_KEY},dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30" 2>&1); then
            log_error "  Failed to mount $share_name"
            log_cmd_output "Mount error: $mount_output"
            ((failed_mounts++))
            continue
        fi
        log_cmd_output "Mount output: $mount_output"
        log_success "  Mounted $share_name"
    done

    if [[ $failed_mounts -gt 0 ]]; then
        handle_error "mount_shares" "$failed_mounts share(s) failed to mount"
    fi
    
    log_success "All shares mounted successfully"
}

# ============================================================================
# CREATE FSTAB ENTRIES
# ============================================================================

create_fstab_entries() {
    confirm_step "Create fstab Entries" "Add persistent mount entries to /etc/fstab"
    
    local credentials_file="/etc/azure-suitecrm-credentials"
    local fstab_marker="# Azure Files - SuiteCRM"
    
    # Check if entries already exist
    if grep -q "$fstab_marker" /etc/fstab 2>/dev/null; then
        log_warn "fstab entries already exist - skipping"
        return 0
    fi
    
    # Create credentials file
    log_info "Creating credentials file at $credentials_file..."
    if ! cat > "$credentials_file" << EOF
username=${AZURE_STORAGE_ACCOUNT_NAME}
password=${AZURE_STORAGE_KEY}
EOF
    then
        handle_error "create_fstab" "Failed to create credentials file"
    fi
    chmod 600 "$credentials_file"
    log_success "Credentials file created"

    # Add entries to fstab
    log_info "Adding entries to /etc/fstab..."
    local shares=("upload" "custom" "cache")
    
    {
        echo ""
        echo "$fstab_marker"
    } >> /etc/fstab
    
    for share in "${shares[@]}"; do
        local mount_point="${MOUNT_BASE}/${share}"
        local share_name="suitecrm-${share}"
        local unc_path="//${AZURE_STORAGE_ACCOUNT_NAME}.file.core.windows.net/${share_name}"
        
        echo "${unc_path} ${mount_point} cifs vers=3.0,credentials=${credentials_file},dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30,nofail 0 0" >> /etc/fstab
        log_info "  Added: $share_name -> $mount_point"
    done

    log_success "fstab entries created - mounts will persist across reboots"
}

# ============================================================================
# UNMOUNT SHARES
# ============================================================================

unmount_shares() {
    confirm_step "Unmount Shares" "Unmount Azure File shares from local system"
    
    local shares=("upload" "custom" "cache")
    local failed_unmounts=0
    
    for share in "${shares[@]}"; do
        local mount_point="${MOUNT_BASE}/${share}"
        
        if mountpoint -q "$mount_point" 2>/dev/null; then
            log_info "Unmounting $mount_point..."
            if ! umount "$mount_point" 2>&1; then
                log_error "Failed to unmount $mount_point"
                ((failed_unmounts++))
            else
                log_success "Unmounted $mount_point"
            fi
        else
            log_warn "$mount_point is not mounted - skipping"
        fi
    done
    
    if [[ $failed_unmounts -gt 0 ]]; then
        log_warn "$failed_unmounts share(s) failed to unmount"
    else
        log_success "All shares unmounted successfully"
    fi
}

# ============================================================================
# OUTPUT STATUS
# ============================================================================

output_status() {
    local summary
    local shares=("upload" "custom" "cache")
    
    if [[ "$ACTION" == "mount" ]]; then
        summary=$(cat << EOF

============================================================================
Azure Files Mounted Successfully
============================================================================

Mount points:
EOF
)
        for share in "${shares[@]}"; do
            summary+=$'\n'"  ${MOUNT_BASE}/${share} -> suitecrm-${share}"
        done
        
        summary+=$(cat << EOF


These paths are now configured for docker-compose.yml

To unmount:
  sudo ./scripts/azure-mount-fileshare-to-local.sh unmount

Log file: $LOG_FILE

============================================================================
EOF
)
    else
        summary=$(cat << EOF

============================================================================
Azure Files Unmounted
============================================================================

Shares have been unmounted from:
EOF
)
        for share in "${shares[@]}"; do
            summary+=$'\n'"  ${MOUNT_BASE}/${share}"
        done
        
        summary+=$(cat << EOF


Note: fstab entries remain for future mounting.

Log file: $LOG_FILE

============================================================================
EOF
)
    fi
    
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
        echo "Action: $ACTION"
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
    echo "Azure Files Mount Script"
    echo "============================================================================"
    echo "Log file: $LOG_FILE"
    echo "Action: $ACTION"
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        echo "Mode: Interactive (press Enter at each step, Ctrl+C to abort)"
    else
        echo "Mode: Non-interactive (running all steps automatically)"
    fi
    echo ""

    # Trap to ensure we finalize the log even on error
    trap finalize_log EXIT

    # Load environment first
    load_env
    validate_env_file
    
    case "$ACTION" in
        mount)
            check_prerequisites
            get_storage_key
            mount_shares
            create_fstab_entries
            output_status
            log_success "Mount operation completed successfully!"
            ;;
        unmount)
            check_prerequisites
            unmount_shares
            output_status
            log_success "Unmount operation completed successfully!"
            ;;
        *)
            handle_error "main" "Unknown action: $ACTION"
            ;;
    esac
}

main "$@"

#!/bin/bash
# ============================================================================
# Azure Files Mount Script for Local Development
# ============================================================================
# Mounts Azure File shares to local directories for Docker bind mounts
# Reads configuration from .env file
#
# NOTE: This script uses sudo internally for privileged operations.
#       You will be prompted for your password when needed.
#
# Usage:
#   ./azure-mount-fileshare-to-local.sh              # Interactive mode, mount shares
#   ./azure-mount-fileshare-to-local.sh -y           # Non-interactive mode
#   ./azure-mount-fileshare-to-local.sh unmount      # Unmount shares
#   ./azure-mount-fileshare-to-local.sh unmount -y   # Unmount without prompts
#   ./azure-mount-fileshare-to-local.sh status       # Check mount status (no sudo)
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

# Source common utilities (colors, logging, etc.)
source "$SCRIPT_DIR/lib/common.sh"

# Interactive mode (default: true, requires user confirmation at each step)
INTERACTIVE_MODE=true

# Track overall success
SCRIPT_SUCCESS=true
FAILED_STEP=""

# Action to perform
ACTION="mount"

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
        echo "Timestamp: $(TZ="${LOGGING_TZ:-America/New_York}" date)"
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
        echo -e "${YELLOW}>>> Next Step: $step_name${NC}"
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
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [mount|unmount|status] [-y|--yes] [-v|--verbose]"
                echo ""
                echo "Commands:"
                echo "  mount      Mount Azure File shares (default, prompts for sudo)"
                echo "  unmount    Unmount Azure File shares (prompts for sudo)"
                echo "  status     Check current mount status (no sudo needed)"
                echo ""
                echo "Options:"
                echo "  -y, --yes      Run without prompting for confirmation at each step"
                echo "  -v, --verbose  Show detailed logging output"
                echo "  -h, --help     Show this help message"
                echo ""
                echo "Note: This script uses sudo internally for privileged operations."
                echo "      You will be prompted for your password when needed."
                echo ""
                echo "Examples:"
                echo "  $0 -y              # Mount all shares non-interactively"
                echo "  $0 status          # Check what's mounted"
                echo "  $0 unmount -y      # Unmount all shares"
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
            status)
                ACTION="status"
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
    
    local validate_script="${SCRIPT_DIR}/env-validate.sh"
    
    if [[ ! -f "$validate_script" ]]; then
        handle_error "validate_env_file" "env-validate.sh not found at $validate_script"
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
    
    # Use common environment loading (handles all variable expansion)
    load_env_common
    
    MOUNT_BASE="${AZURE_FILES_MOUNT_BASE}"

    log_info "Global prefix: $GLOBAL_PREFIX"
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
    confirm_step "Check Prerequisites" "Verify cifs-utils installation and sudo access"
    
    log_info "Checking for cifs-utils..."
    if ! command -v mount.cifs &> /dev/null; then
        handle_error "check_prerequisites" "cifs-utils is not installed. Install with: sudo apt-get install cifs-utils"
    fi
    log_success "cifs-utils is installed"

    log_info "Validating sudo access..."
    # This will prompt for password if needed and cache credentials
    if ! sudo -v 2>/dev/null; then
        handle_error "check_prerequisites" "Unable to obtain sudo privileges. Please ensure you have sudo access."
    fi
    log_success "Sudo access confirmed"

    log_success "Prerequisites OK"
}

# ============================================================================
# MOUNT SHARES
# ============================================================================

mount_shares() {
    confirm_step "Mount Shares" "Create mount points and mount Azure File shares"
    
    local shares=("${AZURE_FILES_SHARE_UPLOAD}" "${AZURE_FILES_SHARE_CUSTOM}" "${AZURE_FILES_SHARE_CACHE}")
    local failed_mounts=0
    local skipped_mounts=0
    local stale_cleared=0
    
    for share in "${shares[@]}"; do
        local mount_point="${MOUNT_BASE}/${share}"
        local share_name="${AZURE_FILES_SHARE_PREFIX}-${share}"
        local unc_path="//${AZURE_STORAGE_ACCOUNT_NAME}.file.core.windows.net/${share_name}"

        log_info "Processing share: $share_name -> $mount_point"

        # Check for stale mount first (in /proc/mounts but not accessible)
        if grep -q " ${mount_point} " /proc/mounts 2>/dev/null; then
            if ! stat "$mount_point" &>/dev/null; then
                log_warn "  Stale mount detected at $mount_point - clearing..."
                if sudo umount -l "$mount_point" 2>&1; then
                    log_success "  Cleared stale mount"
                    ((stale_cleared++))
                    # Small delay to let kernel clean up
                    sleep 1
                else
                    log_error "  Failed to clear stale mount - cannot proceed"
                    ((failed_mounts++))
                    continue
                fi
            else
                # Mount exists and is accessible - check if it's the right share
                log_info "  $mount_point is already mounted - skipping"
                log_action "Mount $mount_point" "skipped" "already mounted"
                ((skipped_mounts++))
                continue
            fi
        fi

        # Create mount point (needs sudo for /mnt)
        if [[ ! -d "$mount_point" ]]; then
            log_info "  Creating mount point directory..."
            local mkdir_output
            if ! mkdir_output=$(sudo mkdir -p "$mount_point" 2>&1); then
                log_error "  Failed to create mount point: $mount_point"
                log_cmd_output "  mkdir error: $mkdir_output"
                ((failed_mounts++))
                continue
            fi
        fi

        # Check if already mounted (shouldn't happen after stale check, but just in case)
        if mountpoint -q "$mount_point" 2>/dev/null; then
            log_info "  $mount_point is already mounted - skipping"
            log_action "Mount $mount_point" "skipped" "already mounted"
            ((skipped_mounts++))
            continue
        fi

        # Mount the share (needs sudo)
        log_info "  Mounting $share_name..."
        local mount_output
        if ! mount_output=$(sudo mount -t cifs "$unc_path" "$mount_point" \
            -o "vers=3.0,username=${AZURE_STORAGE_ACCOUNT_NAME},password=${AZURE_STORAGE_KEY},dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30" 2>&1); then
            log_error "  Failed to mount $share_name"
            log_cmd_output "Mount error: $mount_output"
            ((failed_mounts++))
            continue
        fi
        log_cmd_output "Mount output: $mount_output"
        log_success "  Mounted $share_name"
        log_action "Mount $mount_point" "succeeded"
    done

    if [[ $stale_cleared -gt 0 ]]; then
        log_info "$stale_cleared stale mount(s) were cleared"
    fi

    if [[ $failed_mounts -gt 0 ]]; then
        handle_error "mount_shares" "$failed_mounts share(s) failed to mount"
    fi
    
    if [[ $skipped_mounts -gt 0 ]]; then
        log_info "$skipped_mounts share(s) were already mounted"
    fi
    
    log_success "All shares mounted successfully"
}

# ============================================================================
# CREATE FSTAB ENTRIES
# ============================================================================

create_fstab_entries() {
    confirm_step "Create fstab Entries" "Add persistent mount entries to /etc/fstab"
    
    local credentials_file="${AZURE_FILES_CREDENTIALS_FILE}"
    local fstab_marker="# Azure Files - SuiteCRM"
    
    # Check if entries already exist
    if grep -q "$fstab_marker" /etc/fstab 2>/dev/null; then
        log_info "fstab entries already exist - skipping"
        return 0
    fi
    
    # Create credentials file (needs sudo for /etc)
    log_info "Creating credentials file at $credentials_file..."
    if ! sudo tee "$credentials_file" > /dev/null << EOF
username=${AZURE_STORAGE_ACCOUNT_NAME}
password=${AZURE_STORAGE_KEY}
EOF
    then
        handle_error "create_fstab" "Failed to create credentials file"
    fi
    sudo chmod 600 "$credentials_file"
    log_success "Credentials file created"

    # Add entries to fstab (needs sudo)
    log_info "Adding entries to /etc/fstab..."
    local shares=("${AZURE_FILES_SHARE_UPLOAD}" "${AZURE_FILES_SHARE_CUSTOM}" "${AZURE_FILES_SHARE_CACHE}")
    
    # Add marker
    echo "" | sudo tee -a /etc/fstab > /dev/null
    echo "$fstab_marker" | sudo tee -a /etc/fstab > /dev/null
    
    for share in "${shares[@]}"; do
        local mount_point="${MOUNT_BASE}/${share}"
        local share_name="${AZURE_FILES_SHARE_PREFIX}-${share}"
        local unc_path="//${AZURE_STORAGE_ACCOUNT_NAME}.file.core.windows.net/${share_name}"
        
        echo "${unc_path} ${mount_point} cifs vers=3.0,credentials=${credentials_file},dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30,nofail 0 0" | sudo tee -a /etc/fstab > /dev/null
        log_info "  Added: $share_name -> $mount_point"
    done

    log_success "fstab entries created - mounts will persist across reboots"
}

# ============================================================================
# UNMOUNT SHARES
# ============================================================================

# Check if a mount point is stale (exists in /proc/mounts but inaccessible)
is_stale_mount() {
    local mount_point="$1"
    
    # Check if it's in /proc/mounts
    if grep -q " ${mount_point} " /proc/mounts 2>/dev/null; then
        # It's mounted, check if accessible
        if ! stat "$mount_point" &>/dev/null; then
            # Can't access it - stale mount
            return 0
        fi
    fi
    return 1
}

# Check if mount point is in /proc/mounts (regardless of accessibility)
is_in_proc_mounts() {
    local mount_point="$1"
    grep -q " ${mount_point} " /proc/mounts 2>/dev/null
}

unmount_shares() {
    confirm_step "Unmount Shares" "Unmount Azure File shares from local system"
    
    local shares=("${AZURE_FILES_SHARE_UPLOAD}" "${AZURE_FILES_SHARE_CUSTOM}" "${AZURE_FILES_SHARE_CACHE}")
    local failed_unmounts=0
    local success_unmounts=0
    
    for share in "${shares[@]}"; do
        local mount_point="${MOUNT_BASE}/${share}"
        
        # Check for stale mount first (shows in /proc/mounts but not accessible)
        if is_stale_mount "$mount_point"; then
            log_warn "Stale mount detected at $mount_point - using lazy unmount"
            if sudo umount -l "$mount_point" 2>&1; then
                log_success "Lazy unmounted stale mount: $mount_point"
                ((success_unmounts++))
            else
                log_error "Failed to lazy unmount stale mount: $mount_point"
                # Try force unmount as last resort
                log_info "Attempting force unmount..."
                if sudo umount -f "$mount_point" 2>&1; then
                    log_success "Force unmounted: $mount_point"
                    ((success_unmounts++))
                else
                    log_error "Force unmount also failed: $mount_point"
                    ((failed_unmounts++))
                fi
            fi
        # Check for normal mount (accessible)
        elif mountpoint -q "$mount_point" 2>/dev/null; then
            log_info "Unmounting $mount_point..."
            if sudo umount "$mount_point" 2>&1; then
                log_success "Unmounted $mount_point"
                ((success_unmounts++))
            else
                # Try lazy unmount if regular fails
                log_warn "Regular unmount failed, trying lazy unmount..."
                if sudo umount -l "$mount_point" 2>&1; then
                    log_success "Lazy unmounted: $mount_point"
                    ((success_unmounts++))
                else
                    log_error "Failed to unmount $mount_point"
                    ((failed_unmounts++))
                fi
            fi
        # Check if it's in /proc/mounts but mountpoint check failed (another stale case)
        elif is_in_proc_mounts "$mount_point"; then
            log_warn "Mount in /proc/mounts but not accessible: $mount_point - using lazy unmount"
            if sudo umount -l "$mount_point" 2>&1; then
                log_success "Lazy unmounted: $mount_point"
                ((success_unmounts++))
            else
                log_error "Failed to lazy unmount: $mount_point"
                ((failed_unmounts++))
            fi
        else
            log_info "$mount_point is not mounted - skipping"
            log_action "Unmount $mount_point" "skipped" "not mounted"
        fi
    done
    
    echo ""
    log_info "Unmount summary: $success_unmounts succeeded, $failed_unmounts failed"
    
    if [[ $failed_unmounts -gt 0 ]]; then
        log_warn "$failed_unmounts share(s) failed to unmount"
        log_info "You may need to reboot to clear stale mounts"
    else
        log_success "All mounted shares unmounted successfully"
    fi
}

# ============================================================================
# CHECK MOUNT STATUS (no sudo required)
# ============================================================================

check_mount_status() {
    echo ""
    echo "============================================================================"
    echo "Azure Files Mount Status"
    echo "============================================================================"
    echo ""
    
    local shares=("${AZURE_FILES_SHARE_UPLOAD}" "${AZURE_FILES_SHARE_CUSTOM}" "${AZURE_FILES_SHARE_CACHE}")
    local mounted_count=0
    local not_mounted_count=0
    local missing_dir_count=0
    local stale_count=0
    
    echo "Mount Base: ${MOUNT_BASE}"
    echo ""
    echo "  Share                      Mount Point                        Status"
    echo "  -------------------------- ---------------------------------- --------"
    
    for share in "${shares[@]}"; do
        local mount_point="${MOUNT_BASE}/${share}"
        local share_name="${AZURE_FILES_SHARE_PREFIX}-${share}"
        local status
        local status_color
        
        # Check if in /proc/mounts first
        if grep -q " ${mount_point} " /proc/mounts 2>/dev/null; then
            # It's mounted - check if accessible
            if stat "$mount_point" &>/dev/null; then
                status="MOUNTED"
                status_color="${GREEN}"
                ((mounted_count++))
            else
                status="STALE"
                status_color="${RED}"
                ((stale_count++))
            fi
        elif [[ ! -d "$mount_point" ]]; then
            status="NO DIR"
            status_color="${YELLOW}"
            ((missing_dir_count++))
        else
            status="NOT MOUNTED"
            status_color="${YELLOW}"
            ((not_mounted_count++))
        fi
        
        printf "  %-26s %-34s ${status_color}%s${NC}\n" "$share_name" "$mount_point" "$status"
    done
    
    echo "  -------------------------- ---------------------------------- --------"
    echo ""
    
    # Summary
    local total=$((mounted_count + not_mounted_count + missing_dir_count + stale_count))
    echo -e "Summary: ${GREEN}$mounted_count mounted${NC}, ${YELLOW}$not_mounted_count not mounted${NC}, ${YELLOW}$missing_dir_count no dir${NC}, ${RED}$stale_count stale${NC}"
    echo ""
    
    # Recommendations
    if [[ $stale_count -gt 0 ]]; then
        echo -e "${RED}STALE MOUNTS DETECTED!${NC}"
        echo "Stale mounts block new mounts. Run unmount first:"
        echo "  ./scripts/azure-mount-fileshare-to-local.sh unmount"
        echo ""
    fi
    
    if [[ $not_mounted_count -gt 0 || $missing_dir_count -gt 0 ]]; then
        echo "To mount shares:"
        echo "  ./scripts/azure-mount-fileshare-to-local.sh -y"
        echo ""
    fi
    
    if [[ $mounted_count -eq $total && $stale_count -eq 0 ]]; then
        echo -e "${GREEN}✓ All shares are mounted and ready${NC}"
        echo ""
        return 0
    else
        return 1
    fi
}

# ============================================================================
# OUTPUT STATUS
# ============================================================================

output_status() {
    local summary
    local shares=("${AZURE_FILES_SHARE_UPLOAD}" "${AZURE_FILES_SHARE_CUSTOM}" "${AZURE_FILES_SHARE_CACHE}")
    
    if [[ "$ACTION" == "mount" ]]; then
        summary=$(cat << EOF

============================================================================
Azure Files Mounted Successfully
============================================================================

Mount points:
EOF
)
        for share in "${shares[@]}"; do
            summary+=$'\n'"  ${MOUNT_BASE}/${share} -> ${AZURE_FILES_SHARE_PREFIX}-${share}"
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
    
    # Status check doesn't need validation or sudo
    if [[ "$ACTION" == "status" ]]; then
        check_mount_status
        exit $?
    fi
    
    # Other actions need full validation
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

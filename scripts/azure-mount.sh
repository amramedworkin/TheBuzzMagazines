#!/bin/bash
# ============================================================================
# Azure Files Mount Script for Local Development
# ============================================================================
# Mounts Azure File shares to local directories for Docker bind mounts
# Reads configuration from .env file
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"
SECRETS_FILE="${PROJECT_ROOT}/.azure-secrets"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================================================
# Load environment variables
# ============================================================================
load_env() {
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error ".env file not found at $ENV_FILE"
        exit 1
    fi

    log_info "Loading configuration from $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a

    # Expand nested variables
    AZURE_STORAGE_ACCOUNT_NAME="${AZURE_RESOURCE_PREFIX}storage"

    # Load storage key from secrets file
    if [[ -f "$SECRETS_FILE" ]]; then
        source "$SECRETS_FILE"
    fi

    # If no storage key, try to fetch it
    if [[ -z "$AZURE_STORAGE_KEY" ]]; then
        log_info "Fetching storage key from Azure..."
        AZURE_RESOURCE_GROUP="rg-${AZURE_RESOURCE_PREFIX}-suitecrm"
        AZURE_STORAGE_KEY=$(az storage account keys list \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --account-name "$AZURE_STORAGE_ACCOUNT_NAME" \
            --query '[0].value' -o tsv)
        
        # Save for future use
        echo "AZURE_STORAGE_KEY=$AZURE_STORAGE_KEY" > "$SECRETS_FILE"
        chmod 600 "$SECRETS_FILE"
    fi

    MOUNT_BASE="${AZURE_FILES_MOUNT_BASE:-/mnt/azure/suitecrm}"
}

# ============================================================================
# Check prerequisites
# ============================================================================
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if cifs-utils is installed
    if ! command -v mount.cifs &> /dev/null; then
        log_error "cifs-utils is not installed"
        log_info "Install with: sudo apt-get install cifs-utils"
        exit 1
    fi

    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run with sudo"
        log_info "Run: sudo ./scripts/azure-mount.sh"
        exit 1
    fi

    log_success "Prerequisites OK"
}

# ============================================================================
# Create mount points and mount shares
# ============================================================================
mount_shares() {
    local shares=("upload" "custom" "cache")
    
    for share in "${shares[@]}"; do
        local mount_point="${MOUNT_BASE}/${share}"
        local share_name="suitecrm-${share}"
        local unc_path="//${AZURE_STORAGE_ACCOUNT_NAME}.file.core.windows.net/${share_name}"

        log_info "Mounting ${share_name} to ${mount_point}..."

        # Create mount point
        mkdir -p "$mount_point"

        # Check if already mounted
        if mountpoint -q "$mount_point"; then
            log_warn "${mount_point} is already mounted"
            continue
        fi

        # Mount the share
        mount -t cifs "$unc_path" "$mount_point" \
            -o "vers=3.0,username=${AZURE_STORAGE_ACCOUNT_NAME},password=${AZURE_STORAGE_KEY},dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30"

        log_success "Mounted ${share_name}"
    done
}

# ============================================================================
# Create fstab entries for persistence
# ============================================================================
create_fstab_entries() {
    log_info "Creating /etc/fstab entries for persistence..."

    local credentials_file="/etc/azure-suitecrm-credentials"
    
    # Create credentials file
    cat > "$credentials_file" << EOF
username=${AZURE_STORAGE_ACCOUNT_NAME}
password=${AZURE_STORAGE_KEY}
EOF
    chmod 600 "$credentials_file"

    local shares=("upload" "custom" "cache")
    local fstab_marker="# Azure Files - SuiteCRM"

    # Check if entries already exist
    if grep -q "$fstab_marker" /etc/fstab; then
        log_warn "fstab entries already exist, skipping"
        return
    fi

    # Add entries to fstab
    echo "" >> /etc/fstab
    echo "$fstab_marker" >> /etc/fstab
    
    for share in "${shares[@]}"; do
        local mount_point="${MOUNT_BASE}/${share}"
        local share_name="suitecrm-${share}"
        local unc_path="//${AZURE_STORAGE_ACCOUNT_NAME}.file.core.windows.net/${share_name}"
        
        echo "${unc_path} ${mount_point} cifs vers=3.0,credentials=${credentials_file},dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30,nofail 0 0" >> /etc/fstab
    done

    log_success "fstab entries created - mounts will persist across reboots"
}

# ============================================================================
# Output status
# ============================================================================
output_status() {
    echo ""
    echo "============================================================================"
    echo -e "${GREEN}Azure Files Mounted Successfully${NC}"
    echo "============================================================================"
    echo ""
    echo "Mount points:"
    local shares=("upload" "custom" "cache")
    for share in "${shares[@]}"; do
        echo "  ${MOUNT_BASE}/${share} -> suitecrm-${share}"
    done
    echo ""
    echo "These paths are now configured for docker-compose.yml"
    echo ""
    echo "To unmount:"
    echo "  sudo umount ${MOUNT_BASE}/upload"
    echo "  sudo umount ${MOUNT_BASE}/custom"
    echo "  sudo umount ${MOUNT_BASE}/cache"
    echo ""
    echo "============================================================================"
}

# ============================================================================
# Unmount shares
# ============================================================================
unmount_shares() {
    log_info "Unmounting Azure File shares..."
    
    local shares=("upload" "custom" "cache")
    for share in "${shares[@]}"; do
        local mount_point="${MOUNT_BASE}/${share}"
        if mountpoint -q "$mount_point"; then
            umount "$mount_point"
            log_success "Unmounted ${mount_point}"
        else
            log_warn "${mount_point} is not mounted"
        fi
    done
}

# ============================================================================
# Main
# ============================================================================
main() {
    local action="${1:-mount}"

    echo ""
    echo "============================================================================"
    echo "Azure Files Mount Script"
    echo "============================================================================"
    echo ""

    load_env

    case "$action" in
        mount)
            check_prerequisites
            mount_shares
            create_fstab_entries
            output_status
            ;;
        unmount)
            check_prerequisites
            unmount_shares
            ;;
        *)
            echo "Usage: $0 [mount|unmount]"
            exit 1
            ;;
    esac
}

main "$@"

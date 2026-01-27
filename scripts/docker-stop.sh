#!/bin/bash
# ============================================================================
# Docker Stop Script for SuiteCRM
# ============================================================================
# Gracefully stops the SuiteCRM container.
# Keeps volumes intact (this is not a teardown).
#
# Usage:
#   ./docker-stop.sh          # Interactive mode (default)
#   ./docker-stop.sh -y       # Non-interactive mode
# ============================================================================

# ============================================================================
# SCRIPT CONFIGURATION
# ============================================================================

SCRIPT_NAME="docker-stop"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="${PROJECT_ROOT}/logs"

# Options
INTERACTIVE_MODE=true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BOLD='\033[1m'
NC='\033[0m'

# Container name from docker-compose.yml
CONTAINER_NAME="suitecrm-web"

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
        echo "Docker Stop Log - $(TZ='America/New_York' date)"
        echo "Timezone: America/New_York (Eastern US)"
        echo "============================================================================"
        echo ""
    } >> "$LOG_FILE"
}

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(TZ="America/New_York" date +"%Y-%m-%d %H:%M:%S %Z")
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        INFO)    echo -e "${BLUE}[INFO]${NC} $message" ;;
        SUCCESS) echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        WARN)    echo -e "${YELLOW}[WARN]${NC} $message" ;;
        ERROR)   echo -e "${RED}[ERROR]${NC} $message" ;;
        STEP)    echo -e "${CYAN}[STEP]${NC} $message" ;;
        *)       echo "$message" ;;
    esac
}

log_info() { log "INFO" "$1"; }
log_success() { log "SUCCESS" "$1"; }
log_warn() { log "WARN" "$1"; }
log_error() { log "ERROR" "$1"; }
log_step() { log "STEP" "$1"; }

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
                echo "  -y, --yes      Run without prompting for confirmation"
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
# CHECK DOCKER
# ============================================================================

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running."
        exit 1
    fi
}

# ============================================================================
# CHECK CONTAINER STATUS
# ============================================================================

check_container_status() {
    log_step "Checking container status..."
    
    local container_status
    container_status=$(docker ps -a --filter "name=$CONTAINER_NAME" --format "{{.Status}}" 2>/dev/null)
    
    if [[ -z "$container_status" ]]; then
        log_info "No container found with name '$CONTAINER_NAME'"
        return 1
    fi
    
    if [[ "$container_status" == *"Up"* ]]; then
        log_info "Container '$CONTAINER_NAME' is running"
        return 0
    else
        log_info "Container '$CONTAINER_NAME' is already stopped"
        return 1
    fi
}

# ============================================================================
# INTERACTIVE CONFIRMATION
# ============================================================================

confirm_stop() {
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        echo ""
        read -p "Stop SuiteCRM container? [Y/n] " -r response
        if [[ -n "$response" && ! "$response" =~ ^[Yy] ]]; then
            log_info "Stop cancelled by user"
            exit 0
        fi
        echo ""
    fi
}

# ============================================================================
# STOP CONTAINER
# ============================================================================

stop_container() {
    log_step "Stopping SuiteCRM container..."
    
    cd "$PROJECT_ROOT" || exit 1
    
    log_info "Running: docker compose down"
    
    if docker compose down 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Container stopped"
        return 0
    else
        log_error "Failed to stop container"
        return 1
    fi
}

# ============================================================================
# VERIFY STOPPED
# ============================================================================

verify_stopped() {
    log_step "Verifying container stopped..."
    
    local container_status
    container_status=$(docker ps --filter "name=$CONTAINER_NAME" --format "{{.Status}}" 2>/dev/null)
    
    if [[ -z "$container_status" ]]; then
        log_success "Container is stopped"
        return 0
    else
        log_warn "Container may still be running"
        return 1
    fi
}

# ============================================================================
# OUTPUT SUMMARY
# ============================================================================

output_summary() {
    echo ""
    echo "============================================================================"
    echo "                       SUITECRM STOPPED"
    echo "============================================================================"
    echo ""
    echo "  To start again:"
    echo "    ./scripts/docker-start.sh"
    echo "    or: docker compose up -d"
    echo ""
    echo "  Note: Volumes and data are preserved."
    echo "  To remove everything, use: ./scripts/docker-teardown.sh"
    echo ""
    echo "Log file: $LOG_FILE"
    echo "============================================================================"
}

# ============================================================================
# FINALIZE LOGGING
# ============================================================================

finalize_log() {
    {
        echo ""
        echo "============================================================================"
        echo "STOP COMPLETED"
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
    echo "Docker Stop for SuiteCRM"
    echo "============================================================================"
    echo ""
    
    trap finalize_log EXIT
    
    check_docker
    
    if ! check_container_status; then
        echo ""
        echo "Container is not running. Nothing to stop."
        exit 0
    fi
    
    confirm_stop
    
    if stop_container; then
        verify_stopped
        output_summary
        log_success "SuiteCRM stopped successfully!"
    else
        log_error "Failed to stop SuiteCRM"
        exit 1
    fi
}

main "$@"

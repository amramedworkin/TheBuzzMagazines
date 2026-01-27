#!/bin/bash
# ============================================================================
# Docker Teardown Script for SuiteCRM
# ============================================================================
# Removes all Docker artifacts: containers, images, volumes, networks.
# This is a DESTRUCTIVE operation - use with caution.
#
# Usage:
#   ./docker-teardown.sh          # Interactive mode (requires confirmation)
#   ./docker-teardown.sh -y       # Non-interactive mode
#   ./docker-teardown.sh --prune  # Also prune build cache
# ============================================================================

# ============================================================================
# SCRIPT CONFIGURATION
# ============================================================================

SCRIPT_NAME="docker-teardown"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="${PROJECT_ROOT}/logs"

# Options
INTERACTIVE_MODE=true
PRUNE_CACHE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BOLD='\033[1m'
NC='\033[0m'

# Container/image names
CONTAINER_NAME="suitecrm-web"
NETWORK_NAME="thebuzzmagazines_suitecrm-network"

# Track results
declare -a RESULTS

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
        echo "Docker Teardown Log - $(TZ='America/New_York' date)"
        echo "Timezone: America/New_York (Eastern US)"
        echo "Interactive Mode: $INTERACTIVE_MODE"
        echo "Prune Cache: $PRUNE_CACHE"
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
        SUCCESS) echo -e "${GREEN}[SUCCESS]${NC} $message"; RESULTS+=("${GREEN}✔${NC} $message") ;;
        WARN)    echo -e "${YELLOW}[WARN]${NC} $message" ;;
        ERROR)   echo -e "${RED}[ERROR]${NC} $message"; RESULTS+=("${RED}✘${NC} $message") ;;
        STEP)    echo -e "${CYAN}[STEP]${NC} $message" ;;
        SKIP)    echo -e "${YELLOW}[SKIP]${NC} $message"; RESULTS+=("${YELLOW}○${NC} $message (not found)") ;;
        *)       echo "$message" ;;
    esac
}

log_info() { log "INFO" "$1"; }
log_success() { log "SUCCESS" "$1"; }
log_warn() { log "WARN" "$1"; }
log_error() { log "ERROR" "$1"; }
log_step() { log "STEP" "$1"; }
log_skip() { log "SKIP" "$1"; }

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
            --prune)
                PRUNE_CACHE=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [-y|--yes] [--prune]"
                echo ""
                echo "Options:"
                echo "  -y, --yes      Run without prompting for confirmation"
                echo "  --prune        Also prune Docker build cache"
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
# INTERACTIVE CONFIRMATION
# ============================================================================

confirm_teardown() {
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        echo ""
        echo -e "${RED}========================================${NC}"
        echo -e "${RED}           !!! WARNING !!!              ${NC}"
        echo -e "${RED}========================================${NC}"
        echo ""
        echo "This will PERMANENTLY DELETE:"
        echo "  - SuiteCRM Docker container"
        echo "  - SuiteCRM Docker image"
        echo "  - Docker volumes"
        echo "  - Docker network"
        if [[ "$PRUNE_CACHE" == "true" ]]; then
            echo "  - Docker build cache"
        fi
        echo ""
        echo -e "${YELLOW}Note: Azure Files mounts and data will NOT be affected.${NC}"
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
# STOP AND REMOVE CONTAINER
# ============================================================================

remove_container() {
    log_step "Stopping and removing container..."
    
    cd "$PROJECT_ROOT" || exit 1
    
    # Check if container exists
    if docker ps -a --filter "name=$CONTAINER_NAME" --format "{{.Names}}" 2>/dev/null | grep -q .; then
        log_info "Stopping container '$CONTAINER_NAME'..."
        docker compose down 2>&1 | tee -a "$LOG_FILE"
        log_success "Container removed: $CONTAINER_NAME"
    else
        log_skip "Container: $CONTAINER_NAME"
    fi
}

# ============================================================================
# REMOVE DOCKER IMAGE
# ============================================================================

remove_image() {
    log_step "Removing Docker image..."
    
    cd "$PROJECT_ROOT" || exit 1
    
    # Get image name from docker-compose
    local image_name
    image_name=$(docker compose config --images 2>/dev/null | head -1)
    
    if [[ -z "$image_name" ]]; then
        image_name="thebuzzmagazines-web"
    fi
    
    # Check if image exists
    if docker images "$image_name" --format "{{.Repository}}" 2>/dev/null | grep -q .; then
        log_info "Removing image '$image_name'..."
        if docker rmi "$image_name" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Image removed: $image_name"
        else
            log_error "Failed to remove image: $image_name"
        fi
    else
        log_skip "Image: $image_name"
    fi
}

# ============================================================================
# REMOVE DOCKER VOLUMES
# ============================================================================

remove_volumes() {
    log_step "Removing Docker volumes..."
    
    # Find volumes related to this project
    local volumes
    volumes=$(docker volume ls --filter "name=thebuzzmagazines" --format "{{.Name}}" 2>/dev/null)
    
    if [[ -n "$volumes" ]]; then
        for volume in $volumes; do
            log_info "Removing volume '$volume'..."
            if docker volume rm "$volume" 2>&1 | tee -a "$LOG_FILE"; then
                log_success "Volume removed: $volume"
            else
                log_error "Failed to remove volume: $volume"
            fi
        done
    else
        log_skip "Volumes: thebuzzmagazines_*"
    fi
}

# ============================================================================
# REMOVE DOCKER NETWORK
# ============================================================================

remove_network() {
    log_step "Removing Docker network..."
    
    # Check if network exists
    if docker network ls --filter "name=$NETWORK_NAME" --format "{{.Name}}" 2>/dev/null | grep -q .; then
        log_info "Removing network '$NETWORK_NAME'..."
        if docker network rm "$NETWORK_NAME" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Network removed: $NETWORK_NAME"
        else
            log_error "Failed to remove network: $NETWORK_NAME"
        fi
    else
        log_skip "Network: $NETWORK_NAME"
    fi
}

# ============================================================================
# PRUNE BUILD CACHE
# ============================================================================

prune_cache() {
    if [[ "$PRUNE_CACHE" != "true" ]]; then
        return
    fi
    
    log_step "Pruning Docker build cache..."
    
    if docker builder prune -f 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Build cache pruned"
    else
        log_warn "Failed to prune build cache"
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
    echo "To rebuild and start SuiteCRM:"
    echo "  1. ./scripts/docker-build.sh"
    echo "  2. ./scripts/docker-start.sh"
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
        echo "TEARDOWN COMPLETED"
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
    echo "Docker Teardown for SuiteCRM"
    echo "============================================================================"
    echo ""
    
    trap finalize_log EXIT
    
    check_docker
    confirm_teardown
    
    # Remove all Docker artifacts
    remove_container
    remove_image
    remove_volumes
    remove_network
    prune_cache
    
    output_summary
    log_success "Docker teardown completed!"
}

main "$@"

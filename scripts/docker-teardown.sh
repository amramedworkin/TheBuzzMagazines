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
ENV_FILE="${PROJECT_ROOT}/.env"
LOGS_DIR="${PROJECT_ROOT}/logs"

# Source common utilities (colors, logging, etc.)
source "$SCRIPT_DIR/lib/common.sh"

# Options
INTERACTIVE_MODE=true
PRUNE_CACHE=false

# Container/image/network names - will be set from .env
CONTAINER_NAME=""
NETWORK_NAME=""

# Track results (for summary output)
declare -a RESULTS

# ============================================================================
# CUSTOM LOGGING (extends common.sh to track RESULTS)
# ============================================================================
# Override log function to also track results for summary display

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(TZ="${LOGGING_TZ:-America/New_York}" date +"%Y-%m-%d %H:%M:%S %Z")
    
    # Always write to log file
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
    
    # Track results for summary (always)
    case "$level" in
        SUCCESS) RESULTS+=("${GREEN}✔${NC} $message") ;;
        ERROR)   RESULTS+=("${RED}✘${NC} $message") ;;
        SKIP)    RESULTS+=("${YELLOW}○${NC} $message (not found)") ;;
    esac
    
    # Console output controlled by VERBOSE_MODE
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        case "$level" in
            INFO)    echo -e "${BLUE}[INFO]${NC} $message" ;;
            SUCCESS) echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
            WARN)    echo -e "${YELLOW}[WARN]${NC} $message" ;;
            ERROR)   echo -e "${RED}[ERROR]${NC} $message" ;;
            STEP)    echo -e "${CYAN}[STEP]${NC} $message" ;;
            SKIP)    echo -e "${YELLOW}[SKIP]${NC} $message" ;;
            ACTION)  echo -e "$message" ;;
            *)       echo "$message" ;;
        esac
    else
        # Simple mode: only show errors, warnings, and ACTION results
        case "$level" in
            ERROR)   echo -e "${RED}[ERROR]${NC} $message" ;;
            WARN)    echo -e "${YELLOW}[WARN]${NC} $message" ;;
            ACTION)  echo -e "$message" ;;
        esac
    fi
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
            --prune)
                PRUNE_CACHE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [-y|--yes] [--prune] [-v|--verbose]"
                echo ""
                echo "Options:"
                echo "  -y, --yes      Run without prompting for confirmation"
                echo "  --prune        Also prune Docker build cache"
                echo "  -v, --verbose  Show detailed logging output"
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
# LOAD ENVIRONMENT
# ============================================================================

load_env() {
    load_env_common
    CONTAINER_NAME="${DOCKER_CONTAINER_NAME:-suitecrm-web}"
    NETWORK_NAME="${DOCKER_NETWORK_NAME:-suitecrm-network}"
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
        log_action "Container '$CONTAINER_NAME'" "succeeded" "removed"
    else
        log_skip "Container: $CONTAINER_NAME"
        log_action "Container '$CONTAINER_NAME'" "skipped" "not found"
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
        # Fallback to DOCKER_IMAGE_NAME from env or default
        image_name="${DOCKER_IMAGE_NAME:-suitecrm}"
    fi
    
    # Check if image exists
    if docker images "$image_name" --format "{{.Repository}}" 2>/dev/null | grep -q .; then
        log_info "Removing image '$image_name'..."
        if docker rmi "$image_name" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Image removed: $image_name"
            log_action "Image '$image_name'" "succeeded" "removed"
        else
            log_error "Failed to remove image: $image_name"
            log_action "Image '$image_name'" "failed"
        fi
    else
        log_skip "Image: $image_name"
        log_action "Image '$image_name'" "skipped" "not found"
    fi
}

# ============================================================================
# REMOVE DOCKER VOLUMES
# ============================================================================

remove_volumes() {
    log_step "Removing Docker volumes..."
    
    # Find volumes related to this project using DOCKER_PREFIX
    local volume_filter="${DOCKER_PREFIX:-suitecrm}"
    local volumes
    volumes=$(docker volume ls --filter "name=${volume_filter}" --format "{{.Name}}" 2>/dev/null)
    
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
        log_skip "Volumes: ${volume_filter}_*"
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
    
    load_env
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

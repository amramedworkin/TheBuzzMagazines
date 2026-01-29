#!/bin/bash
# ============================================================================
# Docker Start Script for SuiteCRM
# ============================================================================
# Starts the SuiteCRM container with prerequisite validation.
# Checks for Docker image and Azure Files mounts before starting.
#
# Usage:
#   ./docker-start.sh          # Interactive mode (default)
#   ./docker-start.sh -y       # Non-interactive mode
# ============================================================================

# ============================================================================
# SCRIPT CONFIGURATION
# ============================================================================

SCRIPT_NAME="docker-start"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"
LOGS_DIR="${PROJECT_ROOT}/logs"

# Source common utilities (colors, logging, etc.)
source "$SCRIPT_DIR/lib/common.sh"

# Options
INTERACTIVE_MODE=true

# Container name - will be set from .env (DOCKER_CONTAINER_NAME)
CONTAINER_NAME=""

# ============================================================================
# LOAD ENVIRONMENT
# ============================================================================

load_env() {
    load_env_common
    
    # Set defaults if not defined
    AZURE_FILES_MOUNT_BASE="${AZURE_FILES_MOUNT_BASE:-/mnt/azure/suitecrm}"
    CONTAINER_NAME="${DOCKER_CONTAINER_NAME:-suitecrm-web}"
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
                echo "Usage: $0 [-y|--yes] [-v|--verbose]"
                echo ""
                echo "Options:"
                echo "  -y, --yes      Run without prompting for confirmation"
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
# CHECK DOCKER PREREQUISITES
# ============================================================================

check_docker() {
    log_step "Checking Docker prerequisites..."
    
    # Check Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed."
        exit 1
    fi
    
    # Check Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running."
        exit 1
    fi
    
    log_success "Docker is available"
}

# ============================================================================
# CHECK DOCKER IMAGE
# ============================================================================

check_image() {
    log_step "Checking Docker image..."
    
    cd "$PROJECT_ROOT" || exit 1
    
    # Get the image name from docker-compose
    local image_name
    image_name=$(docker compose config --images 2>/dev/null | head -1)
    
    if [[ -z "$image_name" ]]; then
        # Fallback to DOCKER_IMAGE_NAME from env or default
        image_name="${DOCKER_IMAGE_NAME:-suitecrm}"
    fi
    
    # Check if image exists
    if docker images "$image_name" --format "{{.Repository}}" 2>/dev/null | grep -q .; then
        log_success "Docker image '$image_name' exists"
        return 0
    else
        log_warn "Docker image '$image_name' not found"
        
        if [[ "$INTERACTIVE_MODE" == "true" ]]; then
            echo ""
            read -p "Would you like to build the image now? [Y/n] " -r response
            if [[ -z "$response" || "$response" =~ ^[Yy] ]]; then
                log_info "Building Docker image..."
                if "${SCRIPT_DIR}/docker-build.sh" -y; then
                    log_success "Image built successfully"
                    return 0
                else
                    log_error "Failed to build image"
                    return 1
                fi
            else
                log_error "Cannot start without Docker image. Run: ./scripts/docker-build.sh"
                return 1
            fi
        else
            log_error "Docker image not found. Run: ./scripts/docker-build.sh"
            return 1
        fi
    fi
}

# ============================================================================
# CHECK AZURE FILES MOUNT
# ============================================================================

check_mounts() {
    log_step "Checking Azure Files mounts..."
    
    local mount_base="$AZURE_FILES_MOUNT_BASE"
    local required_mounts=("${AZURE_FILES_SHARE_UPLOAD}" "${AZURE_FILES_SHARE_CUSTOM}" "${AZURE_FILES_SHARE_CACHE}")
    local missing_mounts=()
    local mounted_count=0
    
    for mount in "${required_mounts[@]}"; do
        local mount_point="${mount_base}/${mount}"
        
        if mountpoint -q "$mount_point" 2>/dev/null; then
            log_info "  ✓ $mount_point is mounted"
            ((mounted_count++))
        else
            log_warn "  ✗ $mount_point is NOT mounted"
            missing_mounts+=("$mount")
        fi
    done
    
    if [[ ${#missing_mounts[@]} -eq 0 ]]; then
        log_success "All Azure Files mounts are available"
        return 0
    elif [[ $mounted_count -gt 0 ]]; then
        log_warn "Some mounts are missing: ${missing_mounts[*]}"
    else
        log_warn "Azure Files are not mounted"
    fi
    
    echo ""
    echo -e "${YELLOW}WARNING: Azure Files mounts are required for persistent storage.${NC}"
    echo "Without mounts, uploads and customizations will be lost on container restart."
    echo ""
    echo "To mount Azure Files:"
    echo "  sudo ./scripts/azure-mount-fileshare-to-local.sh"
    echo ""
    
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        read -p "Continue anyway? [y/N] " -r response
        if [[ "$response" =~ ^[Yy] ]]; then
            log_warn "Continuing without mounts (data will not persist)"
            return 0
        else
            log_info "Start cancelled. Mount Azure Files first."
            return 1
        fi
    else
        log_warn "Continuing without mounts in non-interactive mode"
        return 0
    fi
}

# ============================================================================
# CHECK EXISTING CONTAINER
# ============================================================================

check_existing_container() {
    log_step "Checking for existing container..."
    
    local container_status
    container_status=$(docker ps -a --filter "name=$CONTAINER_NAME" --format "{{.Status}}" 2>/dev/null)
    
    if [[ -z "$container_status" ]]; then
        log_info "No existing container found"
        return 0
    fi
    
    if [[ "$container_status" == *"Up"* ]]; then
        log_info "Container '$CONTAINER_NAME' is already running - skipping start"
        
        if [[ "$INTERACTIVE_MODE" == "true" ]]; then
            echo ""
            read -p "Would you like to restart it? [Y/n] " -r response
            if [[ -z "$response" || "$response" =~ ^[Yy] ]]; then
                log_info "Restarting container..."
                cd "$PROJECT_ROOT" || exit 1
                docker compose restart
                log_success "Container restarted"
                show_access_info
                return 2  # Special code: already handled
            else
                log_info "Keeping existing container"
                show_access_info
                return 2
            fi
        else
            # Non-interactive: skip start, container already running
            log_info "To restart, use: ./scripts/cli.sh docker-stop && ./scripts/cli.sh docker-start"
            show_access_info
            return 2
        fi
    else
        log_info "Found stopped container, will be replaced"
        return 0
    fi
}

# ============================================================================
# START CONTAINER
# ============================================================================

start_container() {
    log_step "Starting SuiteCRM container..."
    
    cd "$PROJECT_ROOT" || exit 1
    
    log_info "Running: docker compose up -d"
    
    if docker compose up -d 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Container started"
        return 0
    else
        log_error "Failed to start container"
        return 1
    fi
}

# ============================================================================
# WAIT FOR HEALTH CHECK
# ============================================================================

wait_for_health() {
    log_step "Waiting for container to be healthy..."
    
    local max_attempts="${DOCKER_DB_WAIT_MAX_ATTEMPTS:-30}"
    local wait_interval="${DOCKER_DB_WAIT_INTERVAL:-5}"
    local attempt=1
    local health_status
    
    while [[ $attempt -le $max_attempts ]]; do
        health_status=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null)
        
        case "$health_status" in
            healthy)
                log_success "Container is healthy"
                return 0
                ;;
            unhealthy)
                log_error "Container is unhealthy"
                log_info "Check logs with: docker compose logs"
                return 1
                ;;
            starting)
                log_info "Health check in progress... (attempt $attempt/$max_attempts)"
                ;;
            *)
                log_info "Waiting for health check... (attempt $attempt/$max_attempts)"
                ;;
        esac
        
        sleep "$wait_interval"
        ((attempt++))
    done
    
    log_warn "Health check timeout - container may still be starting"
    log_info "Check status with: docker ps"
    return 0
}

# ============================================================================
# SHOW ACCESS INFO
# ============================================================================

show_access_info() {
    local site_url="${SUITECRM_SITE_URL:-http://localhost}"
    
    echo ""
    echo "============================================================================"
    echo "                       SUITECRM IS RUNNING"
    echo "============================================================================"
    echo ""
    echo -e "  ${GREEN}Access SuiteCRM at:${NC} ${BOLD}${site_url}${NC}"
    echo ""
    echo "  Useful commands:"
    echo "    View logs:     docker compose logs -f"
    echo "    Stop:          ./scripts/docker-stop.sh"
    echo "    Restart:       docker compose restart"
    echo "    Shell access:  docker compose exec web bash"
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
    echo "Docker Start for SuiteCRM"
    echo "============================================================================"
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        echo "Log file: $LOG_FILE"
    fi
    echo ""
    
    trap finalize_log EXIT
    
    load_env
    check_docker
    
    if ! check_image; then
        exit 1
    fi
    
    if ! check_mounts; then
        exit 1
    fi
    
    local container_check
    check_existing_container
    container_check=$?
    
    if [[ $container_check -eq 2 ]]; then
        # Already running/handled - success exit
        log_success "Container already running - no action needed"
        log_action "Container '$CONTAINER_NAME'" "skipped" "already running"
        exit 0
    fi
    
    if start_container; then
        wait_for_health
        show_access_info
        log_success "SuiteCRM started successfully!"
        log_action "Container '$CONTAINER_NAME'" "succeeded"
    else
        log_error "Failed to start SuiteCRM"
        log_action "Container '$CONTAINER_NAME'" "failed"
        exit 1
    fi
}

main "$@"

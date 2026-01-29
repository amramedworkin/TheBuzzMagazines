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
ENV_FILE="${PROJECT_ROOT}/.env"
LOGS_DIR="${PROJECT_ROOT}/logs"

# Source common utilities (colors, logging, etc.)
source "$SCRIPT_DIR/lib/common.sh"

# Options
INTERACTIVE_MODE=true

# Container name - will be set from .env
CONTAINER_NAME=""

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
# LOAD ENVIRONMENT
# ============================================================================

load_env() {
    load_env_common
    CONTAINER_NAME="${DOCKER_CONTAINER_NAME:-suitecrm-web}"
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
    
    load_env
    check_docker
    
    if ! check_container_status; then
        echo ""
        echo "Container is not running. Nothing to stop."
        log_action "Container '$CONTAINER_NAME'" "skipped" "not running"
        exit 0
    fi
    
    confirm_stop
    
    if stop_container; then
        verify_stopped
        output_summary
        log_success "SuiteCRM stopped successfully!"
        log_action "Container '$CONTAINER_NAME' stop" "succeeded"
    else
        log_error "Failed to stop SuiteCRM"
        log_action "Container '$CONTAINER_NAME' stop" "failed"
        exit 1
    fi
}

main "$@"

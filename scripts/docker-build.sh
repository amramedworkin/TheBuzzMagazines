#!/bin/bash
# ============================================================================
# Docker Build Script for SuiteCRM
# ============================================================================
# Builds the SuiteCRM Docker image with logging and validation.
# Reads configuration from .env file.
#
# Usage:
#   ./docker-build.sh          # Interactive mode (default)
#   ./docker-build.sh -y       # Non-interactive mode
#   ./docker-build.sh --no-cache  # Build without cache
# ============================================================================

# ============================================================================
# SCRIPT CONFIGURATION
# ============================================================================

SCRIPT_NAME="docker-build"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"
LOGS_DIR="${PROJECT_ROOT}/logs"

# Source common utilities (colors, logging, etc.)
source "$SCRIPT_DIR/lib/common.sh"

# Options
INTERACTIVE_MODE=true
NO_CACHE=false
FORCE_BUILD=false

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
            --no-cache)
                NO_CACHE=true
                FORCE_BUILD=true  # --no-cache implies force rebuild
                shift
                ;;
            --force|-f)
                FORCE_BUILD=true
                shift
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [-y|--yes] [--no-cache] [--force] [-v|--verbose]"
                echo ""
                echo "Options:"
                echo "  -y, --yes      Run without prompting for confirmation"
                echo "  --no-cache     Build without using Docker cache (implies --force)"
                echo "  --force, -f    Rebuild even if image already exists"
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
# VALIDATE PREREQUISITES
# ============================================================================

validate_prerequisites() {
    log_step "Validating prerequisites..."
    
    # Check Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    log_info "Docker CLI is installed"
    
    # Check Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    log_info "Docker daemon is running"
    
    # Check docker compose is available
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not available. Please install Docker Compose."
        exit 1
    fi
    log_info "Docker Compose is available"
    
    # Check Dockerfile exists
    if [[ ! -f "${PROJECT_ROOT}/Dockerfile" ]]; then
        log_error "Dockerfile not found at ${PROJECT_ROOT}/Dockerfile"
        exit 1
    fi
    log_info "Dockerfile found"
    
    # Check docker-compose.yml exists
    if [[ ! -f "${PROJECT_ROOT}/docker-compose.yml" ]]; then
        log_error "docker-compose.yml not found at ${PROJECT_ROOT}/docker-compose.yml"
        exit 1
    fi
    log_info "docker-compose.yml found"
    
    log_success "All prerequisites validated"
    log_action "Prerequisites validation" "succeeded"
}

# ============================================================================
# CHECK EXISTING IMAGE (PRIOR-SAFE)
# ============================================================================

check_existing_image() {
    local image_name="${DOCKER_IMAGE_NAME:-buzzmag-suitecrm}"
    
    log_step "Checking for existing Docker image..."
    
    if docker image inspect "$image_name" &>/dev/null; then
        log_info "Docker image '$image_name' already exists"
        
        if [[ "$FORCE_BUILD" == "true" ]]; then
            log_info "Force rebuild requested - proceeding with build"
            log_action "Docker image '$image_name'" "rebuilding" "force requested"
            return 1  # Proceed with build
        fi
        
        # Show existing image info in verbose mode
        if [[ "$VERBOSE_MODE" == "true" ]]; then
            echo ""
            echo -e "${BOLD}Existing Image:${NC}"
            docker images "$image_name" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" 2>/dev/null
            echo ""
        fi
        
        log_info "Skipping build - image already exists"
        log_info "Use --force to rebuild, or --no-cache to rebuild without cache"
        log_action "Docker image '$image_name'" "skipped" "already exists"
        return 0  # Skip build
    fi
    
    log_info "No existing image found - proceeding with build"
    return 1  # Proceed with build
}

# ============================================================================
# INTERACTIVE CONFIRMATION
# ============================================================================

confirm_build() {
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        echo ""
        echo -e "${BOLD}Build Configuration:${NC}"
        echo "  Project Root: $PROJECT_ROOT"
        echo "  Dockerfile:   ${PROJECT_ROOT}/Dockerfile"
        echo "  No Cache:     $NO_CACHE"
        echo ""
        read -p "Press Enter to start building, or Ctrl+C to abort... " -r
        echo ""
    fi
}

# ============================================================================
# BUILD DOCKER IMAGE
# ============================================================================

build_image() {
    log_step "Building Docker image..."
    
    local build_args=""
    if [[ "$NO_CACHE" == "true" ]]; then
        build_args="--no-cache"
        log_info "Building without cache"
    fi
    
    local start_time
    start_time=$(date +%s)
    
    cd "$PROJECT_ROOT" || exit 1
    
    # Build using docker compose
    log_info "Running: docker compose build $build_args"
    echo "" >> "$LOG_FILE"
    echo "=== Build Output ===" >> "$LOG_FILE"
    
    # Use pipefail to capture docker compose exit code, not tee's
    set -o pipefail
    local build_exit_code=0
    docker compose build $build_args 2>&1 | tee -a "$LOG_FILE" || build_exit_code=$?
    set +o pipefail
    
    if [[ $build_exit_code -eq 0 ]]; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_success "Docker image built successfully"
        log_info "Build time: ${duration} seconds"
        log_action "Docker image build" "succeeded" "${duration}s"
        
        # Get image info
        get_image_info
        
        return 0
    else
        log_error "Docker build failed with exit code $build_exit_code"
        log_error "Check the log for details: $LOG_FILE"
        log_action "Docker image build" "failed" "exit code $build_exit_code"
        return 1
    fi
}

# ============================================================================
# GET IMAGE INFO
# ============================================================================

get_image_info() {
    log_step "Retrieving image information..."
    
    # Get the image name from docker-compose.yml
    local image_name
    image_name=$(docker compose config --images 2>/dev/null | head -1)
    
    if [[ -z "$image_name" ]]; then
        # Fallback to DOCKER_IMAGE_NAME from env or default
        image_name="${DOCKER_IMAGE_NAME:-suitecrm}"
    fi
    
    # Get image details
    local image_info
    image_info=$(docker images "$image_name" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" 2>/dev/null | tail -1)
    
    if [[ -n "$image_info" ]]; then
        echo ""
        echo -e "${BOLD}Image Details:${NC}"
        docker images "$image_name" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" 2>/dev/null
        echo ""
        
        # Log image info
        {
            echo ""
            echo "=== Image Details ==="
            docker images "$image_name" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" 2>/dev/null
        } >> "$LOG_FILE"
    fi
}

# ============================================================================
# OUTPUT SUMMARY
# ============================================================================

output_summary() {
    echo ""
    echo "============================================================================"
    echo "                       BUILD COMPLETE"
    echo "============================================================================"
    echo ""
    echo "Next steps:"
    echo "  1. Mount Azure Files (if not already mounted):"
    echo "     sudo ./scripts/azure-mount-fileshare-to-local.sh"
    echo ""
    echo "  2. Start the container:"
    echo "     ./scripts/docker-start.sh"
    echo "     or: docker compose up -d"
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
    load_env_common
    
    echo ""
    echo "============================================================================"
    echo "Docker Build for SuiteCRM"
    echo "============================================================================"
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        echo "Log file: $LOG_FILE"
    fi
    echo ""
    
    trap finalize_log EXIT
    
    validate_prerequisites
    
    # Check if image already exists (prior-safe behavior)
    if check_existing_image; then
        # Image exists and not forced - skip build
        echo ""
        echo "============================================================================"
        echo "                    BUILD SKIPPED - Image Already Exists"
        echo "============================================================================"
        echo ""
        echo "The Docker image already exists. To rebuild:"
        echo "  - Use --force to rebuild with cache"
        echo "  - Use --no-cache to rebuild from scratch"
        echo ""
        echo "Log file: $LOG_FILE"
        echo "============================================================================"
        log_success "Build skipped - image already exists"
        exit 0
    fi
    
    confirm_build
    
    if build_image; then
        output_summary
        log_success "Build completed successfully!"
    else
        log_error "Build failed. See log for details: $LOG_FILE"
        exit 1
    fi
}

main "$@"

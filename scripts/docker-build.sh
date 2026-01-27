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

# Options
INTERACTIVE_MODE=true
NO_CACHE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BOLD='\033[1m'
NC='\033[0m'

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
        echo "Docker Build Log - $(TZ='America/New_York' date)"
        echo "Timezone: America/New_York (Eastern US)"
        echo "Interactive Mode: $INTERACTIVE_MODE"
        echo "No Cache: $NO_CACHE"
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
            --no-cache)
                NO_CACHE=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [-y|--yes] [--no-cache]"
                echo ""
                echo "Options:"
                echo "  -y, --yes      Run without prompting for confirmation"
                echo "  --no-cache     Build without using Docker cache"
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
    
    if docker compose build $build_args 2>&1 | tee -a "$LOG_FILE"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_success "Docker image built successfully"
        log_info "Build time: ${duration} seconds"
        
        # Get image info
        get_image_info
        
        return 0
    else
        log_error "Docker build failed. Check the log for details."
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
        image_name="thebuzzmagazines-web"
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
# FINALIZE LOGGING
# ============================================================================

finalize_log() {
    {
        echo ""
        echo "============================================================================"
        echo "BUILD COMPLETED"
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
    echo "Docker Build for SuiteCRM"
    echo "============================================================================"
    echo "Log file: $LOG_FILE"
    echo ""
    
    trap finalize_log EXIT
    
    validate_prerequisites
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

#!/bin/bash
# ============================================================================
# Docker Validation Script for SuiteCRM
# ============================================================================
# Validates the status of all Docker components:
# - Docker daemon, image, container, health, volumes, network, mounts
#
# Usage:
#   ./docker-validate.sh
# ============================================================================

# ============================================================================
# SCRIPT CONFIGURATION
# ============================================================================

SCRIPT_NAME="docker-validate"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"
LOGS_DIR="${PROJECT_ROOT}/logs"

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
declare -a COMPONENT_NAMES
declare -a COMPONENT_TYPES
declare -a COMPONENT_STATUS
declare -a COMPONENT_DETAILS

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
        echo "Docker Validation Log - $(TZ='America/New_York' date)"
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
        SUCCESS) echo -e "${GREEN}[OK]${NC} $message" ;;
        WARN)    echo -e "${YELLOW}[WARN]${NC} $message" ;;
        ERROR)   echo -e "${RED}[FAIL]${NC} $message" ;;
        CHECK)   echo -e "${CYAN}[CHECK]${NC} $message" ;;
        *)       echo "$message" ;;
    esac
}

log_info() { log "INFO" "$1"; }
log_ok() { log "SUCCESS" "$1"; }
log_warn() { log "WARN" "$1"; }
log_fail() { log "ERROR" "$1"; }
log_check() { log "CHECK" "$1"; }

# ============================================================================
# LOAD ENVIRONMENT
# ============================================================================

load_env() {
    if [[ -f "$ENV_FILE" ]]; then
        set -a
        source "$ENV_FILE"
        set +a
        
        # Expand nested variables
        eval "AZURE_FILES_MOUNT_BASE=$AZURE_FILES_MOUNT_BASE"
    fi
    
    # Set default if not defined
    AZURE_FILES_MOUNT_BASE="${AZURE_FILES_MOUNT_BASE:-/mnt/azure/suitecrm}"
}

# ============================================================================
# PARSE COMMAND LINE ARGUMENTS
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                echo "Usage: $0"
                echo ""
                echo "Validates Docker environment for SuiteCRM."
                echo ""
                echo "Checks:"
                echo "  - Docker daemon running"
                echo "  - Docker image exists"
                echo "  - Container status"
                echo "  - Container health"
                echo "  - Docker volumes"
                echo "  - Docker network"
                echo "  - Azure Files mounts"
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
# RECORD RESULT
# ============================================================================

record_result() {
    local name="$1"
    local type="$2"
    local status="$3"
    local details="$4"
    
    COMPONENT_NAMES+=("$name")
    COMPONENT_TYPES+=("$type")
    COMPONENT_STATUS+=("$status")
    COMPONENT_DETAILS+=("$details")
}

# ============================================================================
# CHECK DOCKER DAEMON
# ============================================================================

check_docker_daemon() {
    log_check "Docker Daemon"
    
    if ! command -v docker &> /dev/null; then
        log_fail "Docker CLI not installed"
        record_result "docker" "Daemon" "NOT INSTALLED" "Docker CLI not found"
        return 1
    fi
    
    if docker info &> /dev/null; then
        local version
        version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
        log_ok "Docker daemon running (v$version)"
        record_result "docker" "Daemon" "RUNNING" "Version $version"
        return 0
    else
        log_fail "Docker daemon not running"
        record_result "docker" "Daemon" "NOT RUNNING" "Start Docker service"
        return 1
    fi
}

# ============================================================================
# CHECK DOCKER IMAGE
# ============================================================================

check_docker_image() {
    log_check "Docker Image"
    
    cd "$PROJECT_ROOT" || return 1
    
    # Get image name from docker-compose
    local image_name
    image_name=$(docker compose config --images 2>/dev/null | head -1)
    
    if [[ -z "$image_name" ]]; then
        image_name="thebuzzmagazines-web"
    fi
    
    # Check if image exists
    local image_info
    image_info=$(docker images "$image_name" --format "{{.Size}} ({{.CreatedSince}})" 2>/dev/null | head -1)
    
    if [[ -n "$image_info" ]]; then
        log_ok "Image exists: $image_name - $image_info"
        record_result "$image_name" "Image" "EXISTS" "$image_info"
        return 0
    else
        log_warn "Image not found: $image_name"
        record_result "$image_name" "Image" "NOT FOUND" "Run docker-build.sh"
        return 1
    fi
}

# ============================================================================
# CHECK CONTAINER STATUS
# ============================================================================

check_container_status() {
    log_check "Container Status"
    
    local container_status
    container_status=$(docker ps -a --filter "name=$CONTAINER_NAME" --format "{{.Status}}" 2>/dev/null)
    
    if [[ -z "$container_status" ]]; then
        log_warn "Container not found: $CONTAINER_NAME"
        record_result "$CONTAINER_NAME" "Container" "NOT FOUND" "Run docker-start.sh"
        return 1
    fi
    
    if [[ "$container_status" == *"Up"* ]]; then
        local uptime
        uptime=$(docker ps --filter "name=$CONTAINER_NAME" --format "{{.Status}}" 2>/dev/null)
        log_ok "Container running: $uptime"
        record_result "$CONTAINER_NAME" "Container" "RUNNING" "$uptime"
        return 0
    else
        log_warn "Container stopped: $container_status"
        record_result "$CONTAINER_NAME" "Container" "STOPPED" "$container_status"
        return 1
    fi
}

# ============================================================================
# CHECK CONTAINER HEALTH
# ============================================================================

check_container_health() {
    log_check "Container Health"
    
    # Check if container is running first
    if ! docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" 2>/dev/null | grep -q .; then
        log_info "Skipping health check - container not running"
        record_result "$CONTAINER_NAME" "Health" "N/A" "Container not running"
        return 1
    fi
    
    local health_status
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null)
    
    case "$health_status" in
        healthy)
            log_ok "Container is healthy"
            record_result "$CONTAINER_NAME" "Health" "HEALTHY" "All checks passing"
            return 0
            ;;
        unhealthy)
            log_fail "Container is unhealthy"
            record_result "$CONTAINER_NAME" "Health" "UNHEALTHY" "Check docker logs"
            return 1
            ;;
        starting)
            log_warn "Health check in progress"
            record_result "$CONTAINER_NAME" "Health" "STARTING" "Wait for health check"
            return 1
            ;;
        *)
            log_info "No health check configured"
            record_result "$CONTAINER_NAME" "Health" "NONE" "No health check"
            return 0
            ;;
    esac
}

# ============================================================================
# CHECK DOCKER VOLUMES
# ============================================================================

check_volumes() {
    log_check "Docker Volumes"
    
    local volumes
    volumes=$(docker volume ls --filter "name=thebuzzmagazines" --format "{{.Name}}" 2>/dev/null)
    
    if [[ -n "$volumes" ]]; then
        local count
        count=$(echo "$volumes" | wc -l)
        log_ok "$count volume(s) found"
        for volume in $volumes; do
            record_result "$volume" "Volume" "EXISTS" ""
        done
        return 0
    else
        log_info "No project volumes found"
        record_result "thebuzzmagazines_*" "Volume" "NONE" "No volumes created"
        return 0
    fi
}

# ============================================================================
# CHECK DOCKER NETWORK
# ============================================================================

check_network() {
    log_check "Docker Network"
    
    if docker network ls --filter "name=$NETWORK_NAME" --format "{{.Name}}" 2>/dev/null | grep -q .; then
        log_ok "Network exists: $NETWORK_NAME"
        record_result "$NETWORK_NAME" "Network" "EXISTS" ""
        return 0
    else
        log_info "Network not found: $NETWORK_NAME"
        record_result "$NETWORK_NAME" "Network" "NOT FOUND" "Created on start"
        return 0
    fi
}

# ============================================================================
# CHECK AZURE FILES MOUNTS
# ============================================================================

check_mounts() {
    log_check "Azure Files Mounts"
    
    local mount_base="$AZURE_FILES_MOUNT_BASE"
    local mounts=("upload" "custom" "cache")
    local mounted_count=0
    
    for mount in "${mounts[@]}"; do
        local mount_point="${mount_base}/${mount}"
        
        if mountpoint -q "$mount_point" 2>/dev/null; then
            log_ok "Mounted: $mount_point"
            record_result "$mount_point" "Mount" "MOUNTED" ""
            ((mounted_count++))
        else
            log_warn "Not mounted: $mount_point"
            record_result "$mount_point" "Mount" "NOT MOUNTED" "Run azure-mount.sh"
        fi
    done
    
    if [[ $mounted_count -eq ${#mounts[@]} ]]; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# OUTPUT SUMMARY TABLE
# ============================================================================

output_summary() {
    local total=${#COMPONENT_NAMES[@]}
    local ok_count=0
    local warn_count=0
    local fail_count=0
    
    # Count statuses
    for status in "${COMPONENT_STATUS[@]}"; do
        case "$status" in
            RUNNING|EXISTS|HEALTHY|MOUNTED)
                ((ok_count++))
                ;;
            NOT\ FOUND|NOT\ MOUNTED|STOPPED|STARTING|NONE|N/A)
                ((warn_count++))
                ;;
            NOT\ RUNNING|NOT\ INSTALLED|UNHEALTHY)
                ((fail_count++))
                ;;
        esac
    done
    
    # Calculate column widths
    local name_width=30
    local type_width=12
    local status_width=15
    local detail_width=25
    
    # Print summary header
    echo ""
    echo "============================================================================"
    echo "                    DOCKER VALIDATION SUMMARY"
    echo "============================================================================"
    echo ""
    
    # Print table header
    printf "${BOLD}%-${name_width}s  %-${type_width}s  %-${status_width}s  %-${detail_width}s${NC}\n" \
        "COMPONENT" "TYPE" "STATUS" "DETAILS"
    printf "%s\n" "$(printf '=%.0s' $(seq 1 $((name_width + type_width + status_width + detail_width + 6))))"
    
    # Print each row
    for i in "${!COMPONENT_NAMES[@]}"; do
        local name="${COMPONENT_NAMES[$i]}"
        local type="${COMPONENT_TYPES[$i]}"
        local status="${COMPONENT_STATUS[$i]}"
        local details="${COMPONENT_DETAILS[$i]}"
        
        # Truncate long names
        if [[ ${#name} -gt $name_width ]]; then
            name="${name:0:$((name_width-3))}..."
        fi
        
        # Truncate long details
        if [[ ${#details} -gt $detail_width ]]; then
            details="${details:0:$((detail_width-3))}..."
        fi
        
        # Color the status
        local status_colored
        case "$status" in
            RUNNING|EXISTS|HEALTHY|MOUNTED)
                status_colored="${GREEN}${status}${NC}"
                ;;
            NOT\ FOUND|NOT\ MOUNTED|STOPPED|STARTING|NONE|N/A)
                status_colored="${YELLOW}${status}${NC}"
                ;;
            NOT\ RUNNING|NOT\ INSTALLED|UNHEALTHY)
                status_colored="${RED}${status}${NC}"
                ;;
            *)
                status_colored="$status"
                ;;
        esac
        
        printf "%-${name_width}s  %-${type_width}s  %b  %-${detail_width}s\n" \
            "$name" "$type" "$status_colored" "$details"
    done
    
    # Print summary footer
    printf "%s\n" "$(printf '=%.0s' $(seq 1 $((name_width + type_width + status_width + detail_width + 6))))"
    echo ""
    echo -e "${BOLD}Summary:${NC} ${GREEN}$ok_count OK${NC}, ${YELLOW}$warn_count warnings${NC}, ${RED}$fail_count failures${NC}"
    echo ""
    
    # Overall status
    if [[ $fail_count -gt 0 ]]; then
        echo -e "${RED}✘ Some components have failures${NC}"
    elif [[ $warn_count -gt 0 ]]; then
        echo -e "${YELLOW}○ Some components need attention${NC}"
    else
        echo -e "${GREEN}✔ All components are ready${NC}"
    fi
    
    echo ""
    echo "Log file: $LOG_FILE"
    echo "============================================================================"
    
    # Log summary
    {
        echo ""
        echo "Summary: $ok_count OK, $warn_count warnings, $fail_count failures"
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
    echo "Docker Validation for SuiteCRM"
    echo "============================================================================"
    echo ""
    
    load_env
    
    echo "Checking Docker components..."
    echo ""
    
    # Run all checks (continue even if some fail)
    check_docker_daemon
    
    # Only continue with other checks if Docker is running
    if docker info &> /dev/null; then
        check_docker_image
        check_container_status
        check_container_health
        check_volumes
        check_network
    fi
    
    check_mounts
    
    output_summary
}

main "$@"

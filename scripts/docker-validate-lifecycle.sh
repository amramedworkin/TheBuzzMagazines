#!/bin/bash
# ============================================================================
# Docker Lifecycle Validation Script for SuiteCRM
# ============================================================================
# Validates Docker environment at different stages of the build/deploy lifecycle:
#
# PRE      - Prerequisites before building the Docker image
# POST     - Validation after image build and local container start
# DEPLOYED - Validation of Azure deployment
#
# Usage:
#   ./docker-validate-lifecycle.sh pre        # Pre-build validation
#   ./docker-validate-lifecycle.sh post       # Post-build validation
#   ./docker-validate-lifecycle.sh deployed   # Azure deployment validation
#   ./docker-validate-lifecycle.sh all        # Run all phases
#   ./docker-validate-lifecycle.sh --help     # Show help
# ============================================================================

# ============================================================================
# SCRIPT CONFIGURATION
# ============================================================================

SCRIPT_NAME="docker-validate-lifecycle"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"
LOGS_DIR="${PROJECT_ROOT}/logs"

# Source common utilities (colors, logging, etc.)
source "$SCRIPT_DIR/lib/common.sh"

# Container/image/network names - will be set from .env
CONTAINER_NAME=""
NETWORK_NAME=""

# Validation results tracking
declare -a CHECK_NAMES
declare -a CHECK_STATUS
declare -a CHECK_DETAILS
declare -a CHECK_PHASE

TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_WARNINGS=0
CURRENT_PHASE=""

# ============================================================================
# CUSTOM LOGGING (uses Unicode symbols for lifecycle validation)
# ============================================================================
# Override log function to use Unicode symbols appropriate for validation output

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(TZ="${LOGGING_TZ:-America/New_York}" date +"%Y-%m-%d %H:%M:%S %Z")
    
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
    
    case "$level" in
        INFO)    echo -e "${BLUE}[INFO]${NC} $message" ;;
        SUCCESS) echo -e "${GREEN}[✓]${NC} $message" ;;
        WARN)    echo -e "${YELLOW}[⚠]${NC} $message" ;;
        ERROR)   echo -e "${RED}[✗]${NC} $message" ;;
        CHECK)   echo -e "${CYAN}[→]${NC} $message" ;;
        PHASE)   echo -e "${MAGENTA}${BOLD}[$message]${NC}" ;;
        *)       echo "$message" ;;
    esac
}

# ============================================================================
# LOAD ENVIRONMENT
# ============================================================================

load_env() {
    load_env_common
    
    # Set defaults if not defined
    AZURE_FILES_MOUNT_BASE="${AZURE_FILES_MOUNT_BASE:-/mnt/azure/suitecrm}"
    AZURE_CONTAINER_APP_NAME="${AZURE_CONTAINER_APP_NAME:-suitecrm}"
    CONTAINER_NAME="${DOCKER_CONTAINER_NAME:-suitecrm-web}"
    NETWORK_NAME="${DOCKER_NETWORK_NAME:-suitecrm-network}"
}

# ============================================================================
# RECORD CHECK RESULT
# ============================================================================

record_check() {
    local name="$1"
    local status="$2"
    local details="$3"
    
    CHECK_NAMES+=("$name")
    CHECK_STATUS+=("$status")
    CHECK_DETAILS+=("$details")
    CHECK_PHASE+=("$CURRENT_PHASE")
    
    case "$status" in
        PASS)
            ((TOTAL_PASSED++))
            log "SUCCESS" "$name"
            ;;
        FAIL)
            ((TOTAL_FAILED++))
            log "ERROR" "$name: $details"
            ;;
        WARN)
            ((TOTAL_WARNINGS++))
            log "WARN" "$name: $details"
            ;;
    esac
}

# ============================================================================
# PHASE HEADER
# ============================================================================

print_phase_header() {
    local phase="$1"
    local description="$2"
    
    CURRENT_PHASE="$phase"
    
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC}  ${BOLD}${phase} VALIDATION${NC} - ${description}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    {
        echo ""
        echo "============================================================================"
        echo "$phase VALIDATION - $description"
        echo "============================================================================"
    } >> "$LOG_FILE"
}

# ============================================================================
# PRE-BUILD VALIDATION CHECKS
# ============================================================================

validate_pre_docker_installed() {
    log "CHECK" "Checking Docker CLI..."
    
    if command -v docker &> /dev/null; then
        local version
        version=$(docker --version 2>/dev/null | head -1)
        record_check "Docker CLI installed" "PASS" "$version"
        return 0
    else
        record_check "Docker CLI installed" "FAIL" "Docker CLI not found in PATH"
        return 1
    fi
}

validate_pre_docker_daemon() {
    log "CHECK" "Checking Docker daemon..."
    
    if docker info &> /dev/null; then
        local version
        version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
        record_check "Docker daemon running" "PASS" "Version $version"
        return 0
    else
        record_check "Docker daemon running" "FAIL" "Docker daemon not responding - start Docker service"
        return 1
    fi
}

validate_pre_docker_compose() {
    log "CHECK" "Checking Docker Compose..."
    
    if docker compose version &> /dev/null; then
        local version
        version=$(docker compose version --short 2>/dev/null)
        record_check "Docker Compose available" "PASS" "Version $version"
        return 0
    else
        record_check "Docker Compose available" "FAIL" "Docker Compose not available"
        return 1
    fi
}

validate_pre_dockerfile() {
    log "CHECK" "Checking Dockerfile..."
    
    if [[ -f "${PROJECT_ROOT}/Dockerfile" ]]; then
        local lines
        lines=$(wc -l < "${PROJECT_ROOT}/Dockerfile")
        record_check "Dockerfile exists" "PASS" "$lines lines"
        return 0
    else
        record_check "Dockerfile exists" "FAIL" "Not found at ${PROJECT_ROOT}/Dockerfile"
        return 1
    fi
}

validate_pre_compose_file() {
    log "CHECK" "Checking docker-compose.yml..."
    
    if [[ -f "${PROJECT_ROOT}/docker-compose.yml" ]]; then
        # Validate YAML syntax
        if docker compose -f "${PROJECT_ROOT}/docker-compose.yml" config --quiet 2>/dev/null; then
            record_check "docker-compose.yml valid" "PASS" "Syntax validated"
            return 0
        else
            record_check "docker-compose.yml valid" "FAIL" "Invalid YAML syntax"
            return 1
        fi
    else
        record_check "docker-compose.yml valid" "FAIL" "File not found"
        return 1
    fi
}

validate_pre_entrypoint() {
    log "CHECK" "Checking docker-entrypoint.sh..."
    
    local entrypoint="${PROJECT_ROOT}/docker-entrypoint.sh"
    if [[ -f "$entrypoint" ]]; then
        if [[ -x "$entrypoint" ]]; then
            record_check "docker-entrypoint.sh" "PASS" "Executable"
            return 0
        else
            record_check "docker-entrypoint.sh" "WARN" "Not executable (will be fixed during build)"
            return 0
        fi
    else
        record_check "docker-entrypoint.sh" "FAIL" "File not found"
        return 1
    fi
}

validate_pre_env_file() {
    log "CHECK" "Checking .env file..."
    
    if [[ ! -f "$ENV_FILE" ]]; then
        record_check ".env file exists" "FAIL" "Copy .env.example to .env and configure"
        return 1
    fi
    
    record_check ".env file exists" "PASS" "Found"
    
    # Run env-validate.sh if available
    log "CHECK" "Validating .env contents..."
    
    local env_script="${SCRIPT_DIR}/env-validate.sh"
    if [[ -x "$env_script" ]]; then
        if "$env_script" --quiet 2>/dev/null; then
            record_check ".env configuration valid" "PASS" "All required variables set"
            return 0
        else
            record_check ".env configuration valid" "FAIL" "Run ./scripts/env-validate.sh for details"
            return 1
        fi
    else
        record_check ".env configuration valid" "WARN" "env-validate.sh not found"
        return 0
    fi
}

validate_pre_disk_space() {
    log "CHECK" "Checking available disk space..."
    
    local available_kb
    available_kb=$(df "${PROJECT_ROOT}" --output=avail 2>/dev/null | tail -1 | tr -d ' ')
    local available_gb=$((available_kb / 1024 / 1024))
    
    if [[ $available_gb -ge 5 ]]; then
        record_check "Disk space available" "PASS" "${available_gb}GB free"
        return 0
    elif [[ $available_gb -ge 2 ]]; then
        record_check "Disk space available" "WARN" "Only ${available_gb}GB free (recommend 5GB+)"
        return 0
    else
        record_check "Disk space available" "FAIL" "Only ${available_gb}GB free (need 2GB minimum)"
        return 1
    fi
}

validate_pre_port_available() {
    local port="${DOCKER_HOST_PORT:-80}"
    log "CHECK" "Checking port $port availability..."
    
    if ! ss -tln 2>/dev/null | grep -q ":${port} " && ! netstat -tln 2>/dev/null | grep -q ":${port} "; then
        record_check "Port $port available" "PASS" "Not in use"
        return 0
    else
        local process
        process=$(ss -tlnp 2>/dev/null | grep ":${port} " | head -1 || netstat -tlnp 2>/dev/null | grep ":${port} " | head -1)
        record_check "Port $port available" "WARN" "In use - may conflict: $process"
        return 0
    fi
}

validate_pre_azure_mounts() {
    log "CHECK" "Checking Azure Files mount paths..."
    
    local mount_base="$AZURE_FILES_MOUNT_BASE"
    local all_mounted=true
    local mount_status=""
    
    for mount in "${AZURE_FILES_SHARE_UPLOAD}" "${AZURE_FILES_SHARE_CUSTOM}" "${AZURE_FILES_SHARE_CACHE}"; do
        local mount_point="${mount_base}/${mount}"
        if mountpoint -q "$mount_point" 2>/dev/null; then
            mount_status+="$mount:OK "
        else
            mount_status+="$mount:NOT_MOUNTED "
            all_mounted=false
        fi
    done
    
    if [[ "$all_mounted" == "true" ]]; then
        record_check "Azure Files mounts" "PASS" "$mount_status"
    else
        record_check "Azure Files mounts" "WARN" "$mount_status"
    fi
    return 0
}

# ============================================================================
# POST-BUILD VALIDATION CHECKS
# ============================================================================

validate_post_image_exists() {
    log "CHECK" "Checking Docker image..."
    
    cd "$PROJECT_ROOT" || return 1
    
    local image_name
    image_name=$(docker compose config --images 2>/dev/null | head -1)
    # Fallback to DOCKER_IMAGE_NAME from env or default
    [[ -z "$image_name" ]] && image_name="${DOCKER_IMAGE_NAME:-suitecrm}"
    
    local image_info
    image_info=$(docker images "$image_name" --format "{{.Size}} ({{.CreatedSince}})" 2>/dev/null | head -1)
    
    if [[ -n "$image_info" ]]; then
        record_check "Docker image exists" "PASS" "$image_name: $image_info"
        return 0
    else
        record_check "Docker image exists" "FAIL" "Image not found - run docker-build.sh"
        return 1
    fi
}

validate_post_image_layers() {
    log "CHECK" "Inspecting image layers..."
    
    cd "$PROJECT_ROOT" || return 1
    
    local image_name
    image_name=$(docker compose config --images 2>/dev/null | head -1)
    # Fallback to DOCKER_IMAGE_NAME from env or default
    [[ -z "$image_name" ]] && image_name="${DOCKER_IMAGE_NAME:-suitecrm}"
    
    local layer_count
    layer_count=$(docker history "$image_name" --quiet 2>/dev/null | wc -l)
    
    if [[ $layer_count -gt 0 ]]; then
        record_check "Image layer inspection" "PASS" "$layer_count layers"
        return 0
    else
        record_check "Image layer inspection" "FAIL" "Cannot inspect image layers"
        return 1
    fi
}

validate_post_container_status() {
    log "CHECK" "Checking container status..."
    
    local container_status
    container_status=$(docker ps -a --filter "name=$CONTAINER_NAME" --format "{{.Status}}" 2>/dev/null)
    
    if [[ -z "$container_status" ]]; then
        record_check "Container exists" "WARN" "Not created - run docker-start.sh"
        return 0
    fi
    
    if [[ "$container_status" == *"Up"* ]]; then
        record_check "Container running" "PASS" "$container_status"
        return 0
    else
        record_check "Container running" "WARN" "Status: $container_status"
        return 0
    fi
}

validate_post_container_health() {
    log "CHECK" "Checking container health..."
    
    # Check if container is running first
    if ! docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" 2>/dev/null | grep -q .; then
        record_check "Container health" "WARN" "Container not running"
        return 0
    fi
    
    local health_status
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null)
    
    case "$health_status" in
        healthy)
            record_check "Container health" "PASS" "Healthy"
            return 0
            ;;
        unhealthy)
            # Get last health check log
            local last_log
            last_log=$(docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' "$CONTAINER_NAME" 2>/dev/null | tail -1)
            record_check "Container health" "FAIL" "Unhealthy: $last_log"
            return 1
            ;;
        starting)
            record_check "Container health" "WARN" "Health check in progress"
            return 0
            ;;
        *)
            record_check "Container health" "WARN" "No health check configured"
            return 0
            ;;
    esac
}

validate_post_container_logs() {
    log "CHECK" "Checking container logs for errors..."
    
    if ! docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" 2>/dev/null | grep -q .; then
        record_check "Container logs" "WARN" "Container not running"
        return 0
    fi
    
    local error_count
    error_count=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -ciE "(error|fatal|exception|failed)" 2>/dev/null || echo "0")
    
    if [[ $error_count -eq 0 ]]; then
        record_check "Container logs" "PASS" "No errors found"
        return 0
    elif [[ $error_count -lt 5 ]]; then
        record_check "Container logs" "WARN" "$error_count potential error(s) - check docker logs"
        return 0
    else
        record_check "Container logs" "WARN" "$error_count+ potential errors - check docker logs"
        return 0
    fi
}

validate_post_http_response() {
    log "CHECK" "Testing HTTP response..."
    
    if ! docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" 2>/dev/null | grep -q .; then
        record_check "HTTP response" "WARN" "Container not running"
        return 0
    fi
    
    local site_url="${SUITECRM_SITE_URL:-http://localhost}"
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${site_url}/" 2>/dev/null)
    
    case "$http_code" in
        200|302|301)
            record_check "HTTP response" "PASS" "HTTP $http_code"
            return 0
            ;;
        000)
            record_check "HTTP response" "FAIL" "No response - container may not be ready"
            return 1
            ;;
        *)
            record_check "HTTP response" "WARN" "HTTP $http_code - may need configuration"
            return 0
            ;;
    esac
}

validate_post_volumes() {
    log "CHECK" "Checking Docker volumes..."
    
    # Filter volumes by DOCKER_PREFIX or project name
    local volume_filter="${DOCKER_PREFIX:-suitecrm}"
    local volumes
    volumes=$(docker volume ls --filter "name=${volume_filter}" --format "{{.Name}}" 2>/dev/null)
    
    if [[ -n "$volumes" ]]; then
        local count
        count=$(echo "$volumes" | wc -l)
        record_check "Docker volumes" "PASS" "$count volume(s) created"
    else
        record_check "Docker volumes" "WARN" "No project volumes (using bind mounts)"
    fi
    return 0
}

validate_post_network() {
    log "CHECK" "Checking Docker network..."
    
    if docker network ls --filter "name=$NETWORK_NAME" --format "{{.Name}}" 2>/dev/null | grep -q .; then
        record_check "Docker network" "PASS" "$NETWORK_NAME exists"
        return 0
    else
        record_check "Docker network" "WARN" "Network not found (created on start)"
        return 0
    fi
}

validate_post_db_connectivity() {
    log "CHECK" "Testing database connectivity from container..."
    
    if ! docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" 2>/dev/null | grep -q .; then
        record_check "Database connectivity" "WARN" "Container not running"
        return 0
    fi
    
    # Try to run a simple PHP database check inside the container
    local db_test
    db_test=$(docker exec "$CONTAINER_NAME" php -r "
        \$host = getenv('SUITECRM_RUNTIME_MYSQL_HOST');
        \$port = getenv('SUITECRM_RUNTIME_MYSQL_PORT') ?: 3306;
        \$user = getenv('SUITECRM_RUNTIME_MYSQL_USER');
        \$pass = getenv('SUITECRM_RUNTIME_MYSQL_PASSWORD');
        \$name = getenv('SUITECRM_RUNTIME_MYSQL_NAME');
        
        \$conn = @new mysqli(\$host, \$user, \$pass, \$name, \$port);
        if (\$conn->connect_error) {
            echo 'FAIL:' . \$conn->connect_error;
        } else {
            echo 'OK:Connected to ' . \$host;
            \$conn->close();
        }
    " 2>&1)
    
    if [[ "$db_test" == OK:* ]]; then
        record_check "Database connectivity" "PASS" "${db_test#OK:}"
        return 0
    elif [[ "$db_test" == FAIL:* ]]; then
        record_check "Database connectivity" "WARN" "${db_test#FAIL:}"
        return 0
    else
        record_check "Database connectivity" "WARN" "Could not test - $db_test"
        return 0
    fi
}

# ============================================================================
# DEPLOYED VALIDATION CHECKS (Azure)
# ============================================================================

validate_deployed_az_cli() {
    log "CHECK" "Checking Azure CLI..."
    
    if command -v az &> /dev/null; then
        local version
        version=$(az version --query '"azure-cli"' -o tsv 2>/dev/null)
        record_check "Azure CLI installed" "PASS" "Version $version"
        return 0
    else
        record_check "Azure CLI installed" "FAIL" "az CLI not found in PATH"
        return 1
    fi
}

validate_deployed_az_login() {
    log "CHECK" "Checking Azure login status..."
    
    if az account show &> /dev/null; then
        local account
        account=$(az account show --query 'name' -o tsv 2>/dev/null)
        record_check "Azure login" "PASS" "Logged in: $account"
        return 0
    else
        record_check "Azure login" "FAIL" "Not logged in - run: az login"
        return 1
    fi
}

validate_deployed_subscription() {
    log "CHECK" "Checking Azure subscription..."
    
    local current_sub
    current_sub=$(az account show --query 'id' -o tsv 2>/dev/null)
    
    if [[ -n "$AZURE_SUBSCRIPTION_ID" && "$current_sub" == "$AZURE_SUBSCRIPTION_ID" ]]; then
        record_check "Azure subscription" "PASS" "Correct subscription active"
        return 0
    elif [[ -n "$current_sub" ]]; then
        record_check "Azure subscription" "WARN" "Active sub: $current_sub (expected: $AZURE_SUBSCRIPTION_ID)"
        return 0
    else
        record_check "Azure subscription" "FAIL" "Cannot determine subscription"
        return 1
    fi
}

validate_deployed_resource_group() {
    log "CHECK" "Checking Azure resource group..."
    
    local rg="${AZURE_RESOURCE_GROUP:-${AZURE_RESOURCE_PREFIX}-rg}"
    
    if az group show --name "$rg" &> /dev/null; then
        local location
        location=$(az group show --name "$rg" --query 'location' -o tsv 2>/dev/null)
        record_check "Resource group exists" "PASS" "$rg ($location)"
        return 0
    else
        record_check "Resource group exists" "FAIL" "$rg not found - run azure-provision-infra.sh"
        return 1
    fi
}

validate_deployed_acr() {
    log "CHECK" "Checking Azure Container Registry..."
    
    local acr="${AZURE_ACR_NAME:-${AZURE_RESOURCE_PREFIX}acr}"
    local rg="${AZURE_RESOURCE_GROUP:-${AZURE_RESOURCE_PREFIX}-rg}"
    
    if az acr show --name "$acr" --resource-group "$rg" &> /dev/null; then
        local login_server
        login_server=$(az acr show --name "$acr" --resource-group "$rg" --query 'loginServer' -o tsv 2>/dev/null)
        record_check "Container Registry" "PASS" "$login_server"
        return 0
    else
        record_check "Container Registry" "FAIL" "$acr not found"
        return 1
    fi
}

validate_deployed_acr_image() {
    log "CHECK" "Checking image in ACR..."
    
    local acr="${AZURE_ACR_NAME:-${AZURE_RESOURCE_PREFIX}acr}"
    
    local images
    images=$(az acr repository list --name "$acr" -o tsv 2>/dev/null)
    
    if [[ -n "$images" ]]; then
        local count
        count=$(echo "$images" | wc -l)
        record_check "ACR images" "PASS" "$count image(s) pushed"
        return 0
    else
        record_check "ACR images" "WARN" "No images in registry - push with docker-push.sh"
        return 0
    fi
}

validate_deployed_container_app_env() {
    log "CHECK" "Checking Container Apps Environment..."
    
    local cae="${AZURE_CONTAINER_APP_ENV:-${AZURE_RESOURCE_PREFIX}-cae}"
    local rg="${AZURE_RESOURCE_GROUP:-${AZURE_RESOURCE_PREFIX}-rg}"
    
    if az containerapp env show --name "$cae" --resource-group "$rg" &> /dev/null; then
        local status
        status=$(az containerapp env show --name "$cae" --resource-group "$rg" --query 'properties.provisioningState' -o tsv 2>/dev/null)
        record_check "Container Apps Environment" "PASS" "$cae ($status)"
        return 0
    else
        record_check "Container Apps Environment" "FAIL" "$cae not found"
        return 1
    fi
}

validate_deployed_container_app() {
    log "CHECK" "Checking Container App..."
    
    local app="${AZURE_CONTAINER_APP_NAME:-suitecrm}"
    local rg="${AZURE_RESOURCE_GROUP:-${AZURE_RESOURCE_PREFIX}-rg}"
    
    if az containerapp show --name "$app" --resource-group "$rg" &> /dev/null; then
        local status
        status=$(az containerapp show --name "$app" --resource-group "$rg" --query 'properties.runningStatus' -o tsv 2>/dev/null)
        
        local fqdn
        fqdn=$(az containerapp show --name "$app" --resource-group "$rg" --query 'properties.configuration.ingress.fqdn' -o tsv 2>/dev/null)
        
        if [[ "$status" == "Running" ]]; then
            record_check "Container App" "PASS" "Running at https://$fqdn"
        else
            record_check "Container App" "WARN" "Status: $status (https://$fqdn)"
        fi
        return 0
    else
        record_check "Container App" "FAIL" "$app not found"
        return 1
    fi
}

validate_deployed_container_app_replicas() {
    log "CHECK" "Checking Container App replicas..."
    
    local app="${AZURE_CONTAINER_APP_NAME:-suitecrm}"
    local rg="${AZURE_RESOURCE_GROUP:-${AZURE_RESOURCE_PREFIX}-rg}"
    
    local replicas
    replicas=$(az containerapp replica list --name "$app" --resource-group "$rg" -o json 2>/dev/null)
    
    if [[ -n "$replicas" && "$replicas" != "[]" ]]; then
        local count
        count=$(echo "$replicas" | jq length 2>/dev/null || echo "unknown")
        record_check "Container App replicas" "PASS" "$count running"
        return 0
    else
        record_check "Container App replicas" "WARN" "No replicas found or app not deployed"
        return 0
    fi
}

validate_deployed_https_response() {
    log "CHECK" "Testing HTTPS response from Azure..."
    
    local app="${AZURE_CONTAINER_APP_NAME:-suitecrm}"
    local rg="${AZURE_RESOURCE_GROUP:-${AZURE_RESOURCE_PREFIX}-rg}"
    
    local fqdn
    fqdn=$(az containerapp show --name "$app" --resource-group "$rg" --query 'properties.configuration.ingress.fqdn' -o tsv 2>/dev/null)
    
    if [[ -z "$fqdn" ]]; then
        record_check "Azure HTTPS response" "WARN" "Cannot determine Container App URL"
        return 0
    fi
    
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "https://$fqdn/" 2>/dev/null)
    
    case "$http_code" in
        200|302|301)
            record_check "Azure HTTPS response" "PASS" "HTTP $http_code from https://$fqdn"
            return 0
            ;;
        000)
            record_check "Azure HTTPS response" "FAIL" "No response from https://$fqdn"
            return 1
            ;;
        *)
            record_check "Azure HTTPS response" "WARN" "HTTP $http_code from https://$fqdn"
            return 0
            ;;
    esac
}

validate_deployed_mysql() {
    log "CHECK" "Checking Azure MySQL server..."
    
    local mysql="${AZURE_PROVISION_MYSQL_SERVER_NAME:-${AZURE_RESOURCE_PREFIX}-mysql}"
    local rg="${AZURE_RESOURCE_GROUP:-${AZURE_RESOURCE_PREFIX}-rg}"
    
    if az mysql flexible-server show --name "$mysql" --resource-group "$rg" &> /dev/null; then
        local state
        state=$(az mysql flexible-server show --name "$mysql" --resource-group "$rg" --query 'state' -o tsv 2>/dev/null)
        
        if [[ "$state" == "Ready" ]]; then
            record_check "Azure MySQL" "PASS" "$mysql is Ready"
        else
            record_check "Azure MySQL" "WARN" "$mysql state: $state"
        fi
        return 0
    else
        record_check "Azure MySQL" "FAIL" "$mysql not found"
        return 1
    fi
}

validate_deployed_storage_account() {
    log "CHECK" "Checking Azure Storage Account..."
    
    local storage="${AZURE_STORAGE_ACCOUNT_NAME:-${AZURE_RESOURCE_PREFIX}storage}"
    local rg="${AZURE_RESOURCE_GROUP:-${AZURE_RESOURCE_PREFIX}-rg}"
    
    if az storage account show --name "$storage" --resource-group "$rg" &> /dev/null; then
        local status
        status=$(az storage account show --name "$storage" --resource-group "$rg" --query 'statusOfPrimary' -o tsv 2>/dev/null)
        record_check "Azure Storage Account" "PASS" "$storage ($status)"
        return 0
    else
        record_check "Azure Storage Account" "FAIL" "$storage not found"
        return 1
    fi
}

# ============================================================================
# RUN VALIDATION PHASES
# ============================================================================

run_pre_validation() {
    print_phase_header "PRE" "Prerequisites for Docker build"
    
    validate_pre_docker_installed
    validate_pre_docker_daemon
    validate_pre_docker_compose
    validate_pre_dockerfile
    validate_pre_compose_file
    validate_pre_entrypoint
    validate_pre_env_file
    validate_pre_disk_space
    validate_pre_port_available
    validate_pre_azure_mounts
}

run_post_validation() {
    print_phase_header "POST" "Post-build and container validation"
    
    validate_post_image_exists
    validate_post_image_layers
    validate_post_container_status
    validate_post_container_health
    validate_post_container_logs
    validate_post_http_response
    validate_post_volumes
    validate_post_network
    validate_post_db_connectivity
}

run_deployed_validation() {
    print_phase_header "DEPLOYED" "Azure deployment validation"
    
    validate_deployed_az_cli || return 0
    validate_deployed_az_login || return 0
    validate_deployed_subscription
    validate_deployed_resource_group
    validate_deployed_acr
    validate_deployed_acr_image
    validate_deployed_container_app_env
    validate_deployed_container_app
    validate_deployed_container_app_replicas
    validate_deployed_https_response
    validate_deployed_mysql
    validate_deployed_storage_account
}

# ============================================================================
# RECOMMENDATIONS FOR FAILED CHECKS
# ============================================================================

print_pre_recommendations() {
    local has_pre_failures=false
    
    # Check if there are any PRE phase failures
    for i in "${!CHECK_NAMES[@]}"; do
        if [[ "${CHECK_STATUS[$i]}" == "FAIL" && "${CHECK_PHASE[$i]}" == "PRE" ]]; then
            has_pre_failures=true
            break
        fi
    done
    
    if [[ "$has_pre_failures" == "false" ]]; then
        return
    fi
    
    echo ""
    echo -e "${BOLD}Recommendations to fix failures:${NC}"
    echo ""
    
    for i in "${!CHECK_NAMES[@]}"; do
        if [[ "${CHECK_STATUS[$i]}" == "FAIL" && "${CHECK_PHASE[$i]}" == "PRE" ]]; then
            case "${CHECK_NAMES[$i]}" in
                "Docker CLI installed")
                    echo -e "  ${CYAN}Docker CLI not installed:${NC}"
                    echo "    Install Docker Desktop or Docker Engine:"
                    echo "      https://docs.docker.com/get-docker/"
                    echo ""
                    ;;
                "Docker daemon running")
                    echo -e "  ${CYAN}Docker daemon not running:${NC}"
                    echo "    Start Docker service:"
                    echo "      sudo systemctl start docker"
                    echo "    Or open Docker Desktop application"
                    echo ""
                    ;;
                "Docker Compose available")
                    echo -e "  ${CYAN}Docker Compose not available:${NC}"
                    echo "    Docker Compose is included with Docker Desktop."
                    echo "    For Docker Engine, install the plugin:"
                    echo "      sudo apt install docker-compose-plugin"
                    echo ""
                    ;;
                "Dockerfile exists")
                    echo -e "  ${CYAN}Dockerfile not found:${NC}"
                    echo "    Ensure you are in the correct project directory."
                    echo "    The Dockerfile should be at: ${PROJECT_ROOT}/Dockerfile"
                    echo ""
                    ;;
                "docker-compose.yml valid")
                    echo -e "  ${CYAN}docker-compose.yml invalid or missing:${NC}"
                    echo "    Check YAML syntax errors:"
                    echo "      docker compose config"
                    echo "    Ensure the file exists at: ${PROJECT_ROOT}/docker-compose.yml"
                    echo ""
                    ;;
                "docker-entrypoint.sh")
                    echo -e "  ${CYAN}docker-entrypoint.sh not found:${NC}"
                    echo "    This file should exist at: ${PROJECT_ROOT}/docker-entrypoint.sh"
                    echo "    Check that you have the complete project files."
                    echo ""
                    ;;
                ".env file exists")
                    echo -e "  ${CYAN}.env file missing:${NC}"
                    echo "    Copy the example file and configure your values:"
                    echo "      cp .env.example .env"
                    echo "    Then run validation to check configuration:"
                    echo "      ./scripts/env-validate.sh"
                    echo ""
                    ;;
                ".env configuration valid")
                    echo -e "  ${CYAN}.env configuration invalid:${NC}"
                    echo "    Run the validation script for detailed errors:"
                    echo "      ./scripts/env-validate.sh"
                    echo "    Fix any placeholder values or missing variables."
                    echo ""
                    ;;
                "Disk space available")
                    echo -e "  ${CYAN}Insufficient disk space:${NC}"
                    echo "    Docker images require at least 2GB of free space."
                    echo "    Free up disk space by removing unused files or Docker artifacts:"
                    echo "      docker system prune -a"
                    echo ""
                    ;;
                "Port "*" available")
                    local port="${DOCKER_HOST_PORT:-80}"
                    echo -e "  ${CYAN}Port $port is in use:${NC}"
                    echo "    Option 1: Stop the service using port $port"
                    echo "    Option 2: Change DOCKER_HOST_PORT in .env to an available port"
                    echo "      Common alternatives: 8080, 8081, 8888, 9080"
                    echo ""
                    ;;
            esac
        fi
    done
}

print_post_recommendations() {
    local has_post_failures=false
    
    for i in "${!CHECK_NAMES[@]}"; do
        if [[ "${CHECK_STATUS[$i]}" == "FAIL" && "${CHECK_PHASE[$i]}" == "POST" ]]; then
            has_post_failures=true
            break
        fi
    done
    
    if [[ "$has_post_failures" == "false" ]]; then
        return
    fi
    
    echo ""
    echo -e "${BOLD}Recommendations to fix failures:${NC}"
    echo ""
    
    for i in "${!CHECK_NAMES[@]}"; do
        if [[ "${CHECK_STATUS[$i]}" == "FAIL" && "${CHECK_PHASE[$i]}" == "POST" ]]; then
            case "${CHECK_NAMES[$i]}" in
                "Docker image exists")
                    echo -e "  ${CYAN}Docker image not found:${NC}"
                    echo "    Build the Docker image first:"
                    echo "      ./scripts/docker-build.sh"
                    echo ""
                    ;;
                "Image layer inspection")
                    echo -e "  ${CYAN}Cannot inspect image:${NC}"
                    echo "    The image may be corrupted. Rebuild it:"
                    echo "      ./scripts/docker-build.sh --no-cache"
                    echo ""
                    ;;
                "Container status")
                    echo -e "  ${CYAN}Container not running:${NC}"
                    echo "    Start the container:"
                    echo "      ./scripts/docker-start.sh"
                    echo ""
                    ;;
                "Container health")
                    echo -e "  ${CYAN}Container unhealthy:${NC}"
                    echo "    Check container logs for errors:"
                    echo "      docker logs ${CONTAINER_NAME}"
                    echo "    Restart the container:"
                    echo "      ./scripts/docker-stop.sh && ./scripts/docker-start.sh"
                    echo ""
                    ;;
                "HTTP response")
                    echo -e "  ${CYAN}HTTP not responding:${NC}"
                    echo "    Wait for container to fully start, then check logs:"
                    echo "      docker logs ${CONTAINER_NAME}"
                    echo "    Ensure port mapping is correct in docker-compose.yml"
                    echo ""
                    ;;
            esac
        fi
    done
}

print_deployed_recommendations() {
    local has_deployed_failures=false
    
    for i in "${!CHECK_NAMES[@]}"; do
        if [[ "${CHECK_STATUS[$i]}" == "FAIL" && "${CHECK_PHASE[$i]}" == "DEPLOYED" ]]; then
            has_deployed_failures=true
            break
        fi
    done
    
    if [[ "$has_deployed_failures" == "false" ]]; then
        return
    fi
    
    echo ""
    echo -e "${BOLD}Recommendations to fix failures:${NC}"
    echo ""
    
    for i in "${!CHECK_NAMES[@]}"; do
        if [[ "${CHECK_STATUS[$i]}" == "FAIL" && "${CHECK_PHASE[$i]}" == "DEPLOYED" ]]; then
            case "${CHECK_NAMES[$i]}" in
                "Azure CLI installed")
                    echo -e "  ${CYAN}Azure CLI not installed:${NC}"
                    echo "    Install Azure CLI:"
                    echo "      https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
                    echo ""
                    ;;
                "Azure login")
                    echo -e "  ${CYAN}Not logged into Azure:${NC}"
                    echo "    Log in to Azure:"
                    echo "      az login"
                    echo ""
                    ;;
                "Resource group exists")
                    echo -e "  ${CYAN}Azure resources not provisioned:${NC}"
                    echo "    Provision Azure infrastructure:"
                    echo "      ./scripts/azure-provision-infra.sh"
                    echo ""
                    ;;
                *)
                    # Generic Azure resource recommendation
                    echo -e "  ${CYAN}${CHECK_NAMES[$i]}:${NC}"
                    echo "    Check Azure portal or run provisioning:"
                    echo "      ./scripts/azure-provision-infra.sh"
                    echo ""
                    ;;
            esac
        fi
    done
}

print_warning_recommendations() {
    local has_warnings=false
    
    # Check if there are any warnings
    for i in "${!CHECK_NAMES[@]}"; do
        if [[ "${CHECK_STATUS[$i]}" == "WARN" ]]; then
            has_warnings=true
            break
        fi
    done
    
    if [[ "$has_warnings" == "false" ]]; then
        return
    fi
    
    echo ""
    echo -e "${BOLD}Suggested remediation for warnings:${NC}"
    echo ""
    
    for i in "${!CHECK_NAMES[@]}"; do
        if [[ "${CHECK_STATUS[$i]}" == "WARN" ]]; then
            case "${CHECK_NAMES[$i]}" in
                "Azure Files mounts")
                    echo -e "  ${YELLOW}Azure Files mounts not mounted:${NC}"
                    echo "    For local development with Azure storage persistence:"
                    echo "      sudo ./scripts/azure-mount-fileshare-to-local.sh"
                    echo "    Or continue without mounts (data stored in Docker volumes only)"
                    echo ""
                    ;;
                "Port "*" available")
                    local port="${DOCKER_HOST_PORT:-80}"
                    echo -e "  ${YELLOW}Port $port is in use:${NC}"
                    echo "    Option 1: Stop the service currently using port $port"
                    echo "    Option 2: Change DOCKER_HOST_PORT in .env to an available port"
                    echo "      Common alternatives: 8080, 8081, 8888, 9080"
                    echo ""
                    ;;
                "docker-entrypoint.sh")
                    echo -e "  ${YELLOW}docker-entrypoint.sh not executable:${NC}"
                    echo "    Make the script executable (optional, fixed during build):"
                    echo "      chmod +x docker-entrypoint.sh"
                    echo ""
                    ;;
                "Container health")
                    echo -e "  ${YELLOW}Container health check issue:${NC}"
                    echo "    The container may still be starting. Wait and retry:"
                    echo "      docker logs ${CONTAINER_NAME}"
                    echo ""
                    ;;
                "Container logs")
                    echo -e "  ${YELLOW}Warnings in container logs:${NC}"
                    echo "    Review container logs for details:"
                    echo "      docker logs ${CONTAINER_NAME}"
                    echo ""
                    ;;
                "Database connectivity")
                    echo -e "  ${YELLOW}Database connection issue:${NC}"
                    echo "    Check database configuration in .env"
                    echo "    Verify MySQL server is running and accessible"
                    echo ""
                    ;;
                *)
                    # Generic warning - no specific recommendation
                    ;;
            esac
        fi
    done
}

# ============================================================================
# OUTPUT SUMMARY
# ============================================================================

output_summary() {
    local total=$((TOTAL_PASSED + TOTAL_FAILED + TOTAL_WARNINGS))
    
    echo ""
    echo "============================================================================"
    echo "                    VALIDATION SUMMARY"
    echo "============================================================================"
    echo ""
    
    # Print table header
    printf "${BOLD}%-40s  %-8s  %-8s  %s${NC}\n" "CHECK" "PHASE" "STATUS" "DETAILS"
    printf "%s\n" "$(printf '─%.0s' $(seq 1 85))"
    
    # Print each row
    for i in "${!CHECK_NAMES[@]}"; do
        local name="${CHECK_NAMES[$i]}"
        local status="${CHECK_STATUS[$i]}"
        local details="${CHECK_DETAILS[$i]}"
        local phase="${CHECK_PHASE[$i]}"
        
        # Color the status
        local status_colored
        case "$status" in
            PASS) status_colored="${GREEN}PASS${NC}" ;;
            FAIL) status_colored="${RED}FAIL${NC}" ;;
            WARN) status_colored="${YELLOW}WARN${NC}" ;;
        esac
        
        printf "%-40s  %-8s  %b  %-30s\n" "$name" "$phase" "$status_colored" "$details"
    done
    
    printf "%s\n" "$(printf '─%.0s' $(seq 1 85))"
    echo ""
    echo -e "${BOLD}Results:${NC} ${GREEN}$TOTAL_PASSED passed${NC}, ${RED}$TOTAL_FAILED failed${NC}, ${YELLOW}$TOTAL_WARNINGS warnings${NC}"
    echo ""
    
    # Overall status
    if [[ $TOTAL_FAILED -gt 0 ]]; then
        echo -e "${RED}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║${NC}  ${BOLD}${RED}✗ VALIDATION FAILED${NC} - $TOTAL_FAILED check(s) require attention"
        echo -e "${RED}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        
        # Print recommendations for each phase that has failures
        print_pre_recommendations
        print_post_recommendations
        print_deployed_recommendations
        
        # Also show warning recommendations if there are warnings
        print_warning_recommendations
    elif [[ $TOTAL_WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║${NC}  ${BOLD}${YELLOW}○ VALIDATION PASSED WITH WARNINGS${NC} - $TOTAL_WARNINGS warning(s)"
        echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
        
        # Print warning recommendations
        print_warning_recommendations
    else
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║${NC}  ${BOLD}${GREEN}✓ ALL VALIDATIONS PASSED${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    fi
    
    echo ""
    echo "Log file: $LOG_FILE"
    echo "============================================================================"
    
    # Log summary
    {
        echo ""
        echo "Summary: $TOTAL_PASSED passed, $TOTAL_FAILED failed, $TOTAL_WARNINGS warnings"
        echo "Exit code: $([ $TOTAL_FAILED -eq 0 ] && echo 0 || echo 1)"
    } >> "$LOG_FILE"
}

# ============================================================================
# HELP
# ============================================================================

show_help() {
    cat << EOF
Docker Lifecycle Validation Script for SuiteCRM

Usage: $0 <phase> [options]

PHASES:
  pre          Validate prerequisites before Docker build
  post         Validate after image build and container start
  deployed     Validate Azure deployment
  all          Run all validation phases

OPTIONS:
  -h, --help   Show this help message

EXAMPLES:
  $0 pre                 # Check if ready to build
  $0 post                # Check after build and start
  $0 deployed            # Check Azure deployment
  $0 all                 # Run complete validation

PRE VALIDATION CHECKS:
  - Docker CLI installed
  - Docker daemon running
  - Docker Compose available
  - Dockerfile exists and valid
  - docker-compose.yml valid
  - docker-entrypoint.sh exists
  - .env file configured
  - Disk space available
  - Port 80 available
  - Azure Files mounts (optional)

POST VALIDATION CHECKS:
  - Docker image exists
  - Image layers valid
  - Container running
  - Container healthy
  - Container logs clean
  - HTTP response working
  - Docker volumes/network
  - Database connectivity

DEPLOYED VALIDATION CHECKS:
  - Azure CLI installed
  - Azure login valid
  - Correct subscription
  - Resource group exists
  - Container Registry exists
  - Images pushed to ACR
  - Container Apps Environment
  - Container App running
  - HTTPS response
  - Azure MySQL server
  - Storage account

EXIT CODES:
  0 - All validations passed (may have warnings)
  1 - One or more validations failed

EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local phase="${1:-}"
    
    # Handle help
    if [[ "$phase" == "-h" || "$phase" == "--help" ]]; then
        show_help
        exit 0
    fi
    
    # Validate phase argument
    if [[ -z "$phase" ]]; then
        echo -e "${RED}Error: Phase argument required${NC}"
        echo ""
        echo "Usage: $0 <pre|post|deployed|all>"
        echo "       $0 --help for more information"
        exit 1
    fi
    
    setup_logging
    load_env
    
    echo ""
    echo "============================================================================"
    echo "Docker Lifecycle Validation for SuiteCRM"
    echo "============================================================================"
    echo "Log file: $LOG_FILE"
    
    case "$phase" in
        pre)
            run_pre_validation
            ;;
        post)
            run_post_validation
            ;;
        deployed)
            run_deployed_validation
            ;;
        all)
            run_pre_validation
            run_post_validation
            run_deployed_validation
            ;;
        *)
            echo -e "${RED}Error: Unknown phase '$phase'${NC}"
            echo ""
            echo "Valid phases: pre, post, deployed, all"
            exit 1
            ;;
    esac
    
    output_summary
    
    # Exit with failure if any checks failed
    if [[ $TOTAL_FAILED -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main "$@"

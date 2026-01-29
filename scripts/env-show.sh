#!/bin/bash
# ============================================================================
# Environment Variable Display Script
# ============================================================================
# Displays .env variables with fully expanded values, grouped by category.
#
# Usage:
#   ./env-show.sh              # Show all variables (default)
#   ./env-show.sh all          # Show all variables
#   ./env-show.sh azure        # Show Azure-related variables
#   ./env-show.sh docker       # Show Docker-related variables
#   ./env-show.sh mysql        # Show MySQL/database variables
#   ./env-show.sh suitecrm     # Show SuiteCRM application variables
#   ./env-show.sh migration    # Show migration-related variables
#   ./env-show.sh global       # Show global configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"

# Source common utilities
source "$SCRIPT_DIR/lib/common.sh"

# Category to display (default: all)
CATEGORY="${1:-all}"

# ============================================================================
# LOAD AND EXPAND ENVIRONMENT
# ============================================================================

load_and_expand_env() {
    if [[ ! -f "$ENV_FILE" ]]; then
        echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
        exit 1
    fi
    
    # Source the .env file
    set -a
    source "$ENV_FILE"
    set +a
    
    # Expand all derived variables using load_env_common
    load_env_common
}

# ============================================================================
# DISPLAY HELPERS
# ============================================================================

print_group_header() {
    local title="$1"
    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  $title${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"
}

print_subgroup_header() {
    local title="$1"
    echo ""
    echo -e "${YELLOW}--- $title ---${NC}"
}

print_var() {
    local name="$1"
    local value="$2"
    local description="$3"
    
    # Mask passwords
    if [[ "$name" == *PASSWORD* || "$name" == *SECRET* ]]; then
        if [[ -n "$value" ]]; then
            local masked="${value:0:2}***${value: -2}"
            echo -e "  ${GREEN}$name${NC}=${DIM}$masked${NC}"
        else
            echo -e "  ${GREEN}$name${NC}=${DIM}(not set)${NC}"
        fi
    else
        if [[ -n "$value" ]]; then
            echo -e "  ${GREEN}$name${NC}=$value"
        else
            echo -e "  ${GREEN}$name${NC}=${DIM}(not set)${NC}"
        fi
    fi
    
    if [[ -n "$description" ]]; then
        echo -e "      ${DIM}${ITALIC}$description${NC}"
    fi
}

# ============================================================================
# DISPLAY FUNCTIONS BY CATEGORY
# ============================================================================

show_global() {
    print_group_header "GLOBAL CONFIGURATION"
    
    print_subgroup_header "Master Settings"
    print_var "GLOBAL_PREFIX" "$GLOBAL_PREFIX" "Naming prefix for all resources"
    print_var "GLOBAL_PASSWORD" "$GLOBAL_PASSWORD" "Default password for development"
    
    print_subgroup_header "Derived Prefixes"
    print_var "AZURE_RESOURCE_PREFIX" "$AZURE_RESOURCE_PREFIX" "Azure resource naming prefix"
    print_var "DOCKER_PREFIX" "$DOCKER_PREFIX" "Docker naming prefix"
    
    print_subgroup_header "Derived Passwords"
    print_var "SUITECRM_PASSWORD" "$SUITECRM_PASSWORD" "SuiteCRM/DB password"
    print_var "AZURE_PASSWORD" "$AZURE_PASSWORD" "Azure admin password"
    print_var "DOCKER_PASSWORD" "$DOCKER_PASSWORD" "Docker password"
    
    print_subgroup_header "General Settings"
    print_var "TZ" "$TZ" "Timezone"
}

show_azure() {
    print_group_header "AZURE CONFIGURATION"
    
    print_subgroup_header "Subscription & Location"
    print_var "AZURE_SUBSCRIPTION_ID" "$AZURE_SUBSCRIPTION_ID" "Azure subscription GUID"
    print_var "AZURE_LOCATION" "$AZURE_LOCATION" "Azure region"
    print_var "AZURE_RESOURCE_GROUP" "$AZURE_RESOURCE_GROUP" "Resource group name"
    
    print_subgroup_header "MySQL Flexible Server"
    print_var "AZURE_PROVISION_MYSQL_SERVER_NAME" "$AZURE_PROVISION_MYSQL_SERVER_NAME" "MySQL server name"
    print_var "AZURE_PROVISION_MYSQL_SKU" "$AZURE_PROVISION_MYSQL_SKU" "MySQL compute tier"
    print_var "AZURE_PROVISION_MYSQL_STORAGE_GB" "$AZURE_PROVISION_MYSQL_STORAGE_GB" "Storage size in GB"
    print_var "AZURE_PROVISION_MYSQL_VERSION" "$AZURE_PROVISION_MYSQL_VERSION" "MySQL version"
    
    print_subgroup_header "Storage Account"
    print_var "AZURE_STORAGE_ACCOUNT_NAME" "$AZURE_STORAGE_ACCOUNT_NAME" "Storage account name"
    print_var "AZURE_STORAGE_SKU" "$AZURE_STORAGE_SKU" "Storage redundancy"
    print_var "AZURE_FILES_MOUNT_BASE" "$AZURE_FILES_MOUNT_BASE" "Local mount point"
    
    print_subgroup_header "Container Registry"
    print_var "AZURE_ACR_NAME" "$AZURE_ACR_NAME" "ACR name"
    print_var "AZURE_ACR_SKU" "$AZURE_ACR_SKU" "ACR tier"
    
    print_subgroup_header "Container Apps"
    print_var "AZURE_CONTAINER_APP_ENV" "$AZURE_CONTAINER_APP_ENV" "Container Apps Environment"
    print_var "AZURE_CONTAINER_APP_NAME" "$AZURE_CONTAINER_APP_NAME" "Container App name"
}

show_docker() {
    print_group_header "DOCKER CONFIGURATION"
    
    print_subgroup_header "Base Image & Platform"
    print_var "DOCKER_PHP_BASE_IMAGE" "$DOCKER_PHP_BASE_IMAGE" "PHP base image"
    print_var "DOCKER_SUITECRM_VERSION" "$DOCKER_SUITECRM_VERSION" "SuiteCRM version"
    print_var "DOCKER_PLATFORM" "$DOCKER_PLATFORM" "Target platform"
    
    print_subgroup_header "Container Naming"
    print_var "DOCKER_IMAGE_NAME" "$DOCKER_IMAGE_NAME" "Image name"
    print_var "DOCKER_IMAGE_TAG" "$DOCKER_IMAGE_TAG" "Image tag"
    print_var "DOCKER_CONTAINER_NAME" "$DOCKER_CONTAINER_NAME" "Container name"
    print_var "DOCKER_NETWORK_NAME" "$DOCKER_NETWORK_NAME" "Network name"
    
    print_subgroup_header "Labels"
    print_var "DOCKER_LABEL_MAINTAINER" "$DOCKER_LABEL_MAINTAINER" "Maintainer label"
    print_var "DOCKER_LABEL_DESCRIPTION" "$DOCKER_LABEL_DESCRIPTION" "Description label"
    
    print_subgroup_header "PHP Configuration"
    print_var "DOCKER_PHP_MEMORY_LIMIT" "$DOCKER_PHP_MEMORY_LIMIT" "PHP memory limit"
    print_var "DOCKER_PHP_UPLOAD_MAX_FILESIZE" "$DOCKER_PHP_UPLOAD_MAX_FILESIZE" "Max upload size"
    print_var "DOCKER_PHP_POST_MAX_SIZE" "$DOCKER_PHP_POST_MAX_SIZE" "Max POST size"
    print_var "DOCKER_PHP_MAX_EXECUTION_TIME" "$DOCKER_PHP_MAX_EXECUTION_TIME" "Max execution time"
    print_var "DOCKER_PHP_MAX_INPUT_TIME" "$DOCKER_PHP_MAX_INPUT_TIME" "Max input time"
    print_var "DOCKER_PHP_MAX_INPUT_VARS" "$DOCKER_PHP_MAX_INPUT_VARS" "Max input variables"
    
    print_subgroup_header "OPcache Configuration"
    print_var "DOCKER_OPCACHE_MEMORY" "$DOCKER_OPCACHE_MEMORY" "OPcache memory (MB)"
    print_var "DOCKER_OPCACHE_INTERNED_STRINGS" "$DOCKER_OPCACHE_INTERNED_STRINGS" "Interned strings (MB)"
    print_var "DOCKER_OPCACHE_MAX_FILES" "$DOCKER_OPCACHE_MAX_FILES" "Max cached files"
    
    print_subgroup_header "Ports"
    print_var "DOCKER_HOST_PORT" "$DOCKER_HOST_PORT" "Host port"
    print_var "DOCKER_CONTAINER_PORT" "$DOCKER_CONTAINER_PORT" "Container port"
    
    print_subgroup_header "Health Check"
    print_var "DOCKER_HEALTHCHECK_INTERVAL" "$DOCKER_HEALTHCHECK_INTERVAL" "Check interval"
    print_var "DOCKER_HEALTHCHECK_TIMEOUT" "$DOCKER_HEALTHCHECK_TIMEOUT" "Check timeout"
    print_var "DOCKER_HEALTHCHECK_RETRIES" "$DOCKER_HEALTHCHECK_RETRIES" "Max retries"
    print_var "DOCKER_HEALTHCHECK_START_PERIOD" "$DOCKER_HEALTHCHECK_START_PERIOD" "Start grace period"
}

show_mysql() {
    print_group_header "MYSQL / DATABASE CONFIGURATION"
    
    print_subgroup_header "SuiteCRM Runtime Connection"
    print_var "SUITECRM_RUNTIME_MYSQL_HOST" "$SUITECRM_RUNTIME_MYSQL_HOST" "Database host"
    print_var "SUITECRM_RUNTIME_MYSQL_PORT" "$SUITECRM_RUNTIME_MYSQL_PORT" "Database port"
    print_var "SUITECRM_RUNTIME_MYSQL_NAME" "$SUITECRM_RUNTIME_MYSQL_NAME" "Database name"
    print_var "SUITECRM_RUNTIME_MYSQL_USER" "$SUITECRM_RUNTIME_MYSQL_USER" "Database user"
    print_var "SUITECRM_RUNTIME_MYSQL_PASSWORD" "$SUITECRM_RUNTIME_MYSQL_PASSWORD" "Database password"
    
    print_subgroup_header "SSL Settings"
    print_var "SUITECRM_RUNTIME_MYSQL_SSL_ENABLED" "$SUITECRM_RUNTIME_MYSQL_SSL_ENABLED" "SSL enabled"
    print_var "SUITECRM_RUNTIME_MYSQL_SSL_VERIFY" "$SUITECRM_RUNTIME_MYSQL_SSL_VERIFY" "Verify SSL cert"
}

show_suitecrm() {
    print_group_header "SUITECRM APPLICATION CONFIGURATION"
    
    print_subgroup_header "Application Settings"
    print_var "SUITECRM_SITE_URL" "$SUITECRM_SITE_URL" "Site URL"
    print_var "SUITECRM_ADMIN_USER" "$SUITECRM_ADMIN_USER" "Admin username"
    print_var "SUITECRM_ADMIN_PASSWORD" "$SUITECRM_ADMIN_PASSWORD" "Admin password"
    print_var "SUITECRM_LOG_LEVEL" "$SUITECRM_LOG_LEVEL" "Log level"
    print_var "SUITECRM_INSTALLER_LOCKED" "$SUITECRM_INSTALLER_LOCKED" "Installer locked"
    
    print_subgroup_header "Runtime Behavior"
    print_var "SKIP_DB_WAIT" "$SKIP_DB_WAIT" "Skip DB wait on startup"
}

show_migration() {
    print_group_header "MIGRATION CONFIGURATION"
    
    print_subgroup_header "Source Database (Legacy)"
    print_var "MIGRATION_SOURCE_MYSQL_HOST" "$MIGRATION_SOURCE_MYSQL_HOST" "Source host"
    print_var "MIGRATION_SOURCE_MYSQL_PORT" "$MIGRATION_SOURCE_MYSQL_PORT" "Source port"
    print_var "MIGRATION_SOURCE_MYSQL_NAME" "$MIGRATION_SOURCE_MYSQL_NAME" "Source database"
    print_var "MIGRATION_SOURCE_MYSQL_USER" "$MIGRATION_SOURCE_MYSQL_USER" "Source user"
    print_var "MIGRATION_SOURCE_MYSQL_PASSWORD" "$MIGRATION_SOURCE_MYSQL_PASSWORD" "Source password"
    
    print_subgroup_header "Destination Database (SuiteCRM)"
    print_var "MIGRATION_DEST_MYSQL_HOST" "$MIGRATION_DEST_MYSQL_HOST" "Destination host"
    print_var "MIGRATION_DEST_MYSQL_PORT" "$MIGRATION_DEST_MYSQL_PORT" "Destination port"
    print_var "MIGRATION_DEST_MYSQL_NAME" "$MIGRATION_DEST_MYSQL_NAME" "Destination database"
    print_var "MIGRATION_DEST_MYSQL_USER" "$MIGRATION_DEST_MYSQL_USER" "Destination user"
    print_var "MIGRATION_DEST_MYSQL_PASSWORD" "$MIGRATION_DEST_MYSQL_PASSWORD" "Destination password"
    
    print_subgroup_header "Legacy MS Access (Optional)"
    print_var "BUZZ_ADVERT_MSACCESS_PATH" "$BUZZ_ADVERT_MSACCESS_PATH" "Access database path"
    print_var "BUZZ_ADVERT_MSACCESS_DRIVER" "$BUZZ_ADVERT_MSACCESS_DRIVER" "ODBC driver"
    print_var "BUZZ_ADVERT_MSACCESS_USER" "$BUZZ_ADVERT_MSACCESS_USER" "Access user"
    print_var "BUZZ_ADVERT_MSACCESS_PASSWORD" "$BUZZ_ADVERT_MSACCESS_PASSWORD" "Access password"
    
    print_subgroup_header "Backup Settings"
    print_var "BACKUP_DIR" "$BACKUP_DIR" "Backup directory"
}

# ============================================================================
# HELP
# ============================================================================

show_help() {
    cat << EOF
Environment Variable Display Script

Usage: $0 [category]

Categories:
  all        Show all variables (default)
  global     Show global configuration (prefixes, passwords)
  azure      Show Azure-related variables
  docker     Show Docker build configuration
  mysql      Show MySQL/database connection settings
  suitecrm   Show SuiteCRM application settings
  migration  Show migration-related settings

Options:
  -h, --help    Show this help message

Examples:
  $0              # Show all (default)
  $0 azure        # Show Azure configuration only
  $0 docker       # Show Docker configuration only
  $0 mysql        # Show database settings
EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    case "$CATEGORY" in
        -h|--help)
            show_help
            exit 0
            ;;
        all)
            load_and_expand_env
            echo ""
            echo -e "${BOLD}Environment Variables (Fully Expanded)${NC}"
            echo -e "${DIM}Source: $ENV_FILE${NC}"
            show_global
            show_azure
            show_docker
            show_mysql
            show_suitecrm
            show_migration
            echo ""
            ;;
        global)
            load_and_expand_env
            show_global
            echo ""
            ;;
        azure)
            load_and_expand_env
            show_azure
            echo ""
            ;;
        docker)
            load_and_expand_env
            show_docker
            echo ""
            ;;
        mysql|db|database)
            load_and_expand_env
            show_mysql
            echo ""
            ;;
        suitecrm|crm|app)
            load_and_expand_env
            show_suitecrm
            echo ""
            ;;
        migration|migrate)
            load_and_expand_env
            show_migration
            echo ""
            ;;
        *)
            echo -e "${RED}Unknown category: $CATEGORY${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"

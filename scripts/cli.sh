#!/bin/bash
# ============================================================================
# TheBuzzMagazines CLI - Database Migration & Management Tools
# ============================================================================

set -e

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables
ENV_FILE="$PROJECT_ROOT/.env"
if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "ERROR: .env file not found at $ENV_FILE"
    echo "Please create a .env file with database connection settings."
    exit 1
fi

# Set defaults if not defined
BACKUP_DIR="${BACKUP_DIR:-databases/backups}"
SCHEMA_BACKUP_DIR="${SCHEMA_BACKUP_DIR:-database/backups}"

# Ensure backup directory paths are absolute
if [[ ! "$BACKUP_DIR" = /* ]]; then
    BACKUP_DIR="$PROJECT_ROOT/$BACKUP_DIR"
fi

if [[ ! "$SCHEMA_BACKUP_DIR" = /* ]]; then
    SCHEMA_BACKUP_DIR="$PROJECT_ROOT/$SCHEMA_BACKUP_DIR"
fi

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

print_header() {
    echo ""
    echo "============================================================================"
    echo "$1"
    echo "============================================================================"
}

print_success() {
    echo "[SUCCESS] $1"
}

print_error() {
    echo "[ERROR] $1" >&2
}

print_info() {
    echo "[INFO] $1"
}

show_help() {
    cat << EOF
TheBuzzMagazines CLI - Database Migration & Management Tools

Usage: $(basename "$0") <command> [options]

Commands:
    backup-db-source [name]     Backup the source database (full schema + data)
                                Optional: name component to embed in backup filename
                                Example: $(basename "$0") backup-db-source before_schema_update

    backup-schema-source <name> Backup only the schema (no data) of source database
                                Required: name component to embed in schema filename
                                Output: database/backups/<db>_schema_<name>_<timestamp>.sql
                                Example: $(basename "$0") backup-schema-source initial_schema

    validate-env [options]      Validate .env file for required values and placeholders
                                Checks that all required variables are set and not placeholders
                                Returns exit code 1 if validation fails
                                Options:
                                  --errors-only  Only show errors (no warnings/success)
                                  --quiet        Minimal output, just pass/fail

    show-env [category]         Display .env variables with fully expanded values
                                Shows actual resolved values (no \${} references)
                                Categories: all (default), global, azure, docker, mysql, suitecrm, migration

    provision [options]         Run Azure resource provisioning
                                Creates Azure MySQL, Storage, ACR resources
                                Safe to re-run: skips existing resources
                                Options:
                                  -y, --yes        Run without prompting
                                  -v, --verbose    Show detailed logging output
                                  --retry-shares   Only retry file share creation
                                  --status         Show what exists vs needs creation

    mount [options]             Mount Azure Files locally
                                Mounts Azure file shares for local development
                                Options:
                                  -y, --yes        Run without prompting
                                  -v, --verbose    Show detailed logging output
                                Note: Script prompts for sudo password when needed

    unmount [options]           Unmount Azure Files
                                Options:
                                  -y, --yes        Run without prompting
                                  -v, --verbose    Show detailed logging output
                                Note: Script prompts for sudo password when needed

    mount-status                Check Azure Files mount status
                                Shows current mount state (no sudo needed)
                                Useful for automated checks before docker-start

    show-log-provision          Show the most recent azure-provision-infra.sh log
    show-log-mount              Show the most recent azure-mount-fileshare-to-local.sh log
    list-logs                   List all available logs

    generate-env-example        Generate .env.example from .env
                                Copies .env to .env.example, replacing sensitive values
                                (passwords, subscription IDs, API keys) with placeholders
                                while keeping non-sensitive values (hosts, ports, users)

    test-azure-capabilities     Test Azure CLI capabilities and permissions
                                Verifies login status, resource creation permissions,
                                provider registrations, and service accessibility
                                Creates temporary test resources and cleans them up

    validate-resources          Validate Azure resources exist
                                Checks all resources defined in .env against Azure
                                Shows summary table with resource status

    mysql-status [options]      Check Azure MySQL database status
                                Tests server existence, state, and connectivity
                                Options:
                                  --quick, -q    Quick check (server existence only)
                                  --connect, -c  Test MySQL connection with credentials

    teardown [options]          Tear down all Azure infrastructure
                                Deletes MySQL server, ACR, Storage Account, and Resource Group
                                WARNING: This is destructive and cannot be undone
                                Options:
                                  -y, --yes        Run without prompting
                                  -v, --verbose    Show detailed logging output

    docker-build [options]      Build Docker image for SuiteCRM
                                Options:
                                  -y, --yes        Run without prompting
                                  -v, --verbose    Show detailed logging output
                                  --no-cache       Build without Docker cache
                                  --force, -f      Rebuild even if image exists

    docker-start [options]      Start SuiteCRM container
                                Validates image exists and mounts are ready
                                Options:
                                  -y, --yes        Run without prompting
                                  -v, --verbose    Show detailed logging output

    docker-stop [options]       Stop SuiteCRM container gracefully
                                Options:
                                  -y, --yes        Run without prompting
                                  -v, --verbose    Show detailed logging output

    docker-validate             Validate Docker environment
                                Checks image, container, health, volumes, mounts

    docker-validate-pre         Pre-build validation (prerequisites check)
                                Validates Docker, files, .env, disk space, ports

    docker-validate-post        Post-build validation (image and container check)
                                Validates image, container, health, HTTP, DB connectivity

    docker-validate-deployed    Azure deployment validation
                                Validates ACR, Container Apps, MySQL, HTTPS response

    docker-validate-all         Run all Docker lifecycle validations
                                Runs pre, post, and deployed phases

    docker-teardown [options]   Remove all Docker artifacts (DESTRUCTIVE)
                                Removes container, image, volumes, network
                                Options:
                                  -y, --yes        Run without prompting
                                  -v, --verbose    Show detailed logging output
                                  --prune          Also prune build cache

    docker-logs                 View SuiteCRM container logs

    build-status                Show build cycle status summary
                                Checks environment, Azure, mounts, Docker image/container
                                Useful for quickly seeing what steps are complete

    help                        Show this help message

Environment:
    Configuration is loaded from .env file in project root.
    Required variables for database operations:
        MIGRATION_SOURCE_MYSQL_HOST, MIGRATION_SOURCE_MYSQL_PORT, MIGRATION_SOURCE_MYSQL_NAME
        MIGRATION_SOURCE_MYSQL_USER, MIGRATION_SOURCE_MYSQL_PASSWORD

Examples:
    $(basename "$0") backup-db-source
    $(basename "$0") backup-db-source pre_migration
    $(basename "$0") backup-db-source before_updating_schema
    $(basename "$0") backup-schema-source initial_schema
    $(basename "$0") backup-schema-source after_adding_views
    $(basename "$0") show-log-provision
    $(basename "$0") show-log-mount

EOF
}

# ============================================================================
# DATABASE BACKUP FUNCTIONS
# ============================================================================

backup_db_source() {
    local name_component="$1"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_filename
    
    # Build backup filename
    if [[ -n "$name_component" ]]; then
        # Sanitize the name component (replace spaces and special chars with underscore)
        name_component=$(echo "$name_component" | sed 's/[^a-zA-Z0-9_-]/_/g')
        backup_filename="${MIGRATION_SOURCE_MYSQL_NAME}_${name_component}_${timestamp}.sql"
    else
        backup_filename="${MIGRATION_SOURCE_MYSQL_NAME}_${timestamp}.sql"
    fi
    
    local backup_path="$BACKUP_DIR/$backup_filename"
    local compressed_path="${backup_path}.gz"
    
    print_header "Backing Up Source Database"
    
    # Validate required environment variables
    if [[ -z "$MIGRATION_SOURCE_MYSQL_NAME" ]]; then
        print_error "MIGRATION_SOURCE_MYSQL_NAME is not set in .env"
        exit 1
    fi
    
    print_info "Database: $MIGRATION_SOURCE_MYSQL_NAME"
    print_info "Host: ${MIGRATION_SOURCE_MYSQL_HOST:-localhost}:${MIGRATION_SOURCE_MYSQL_PORT:-3306}"
    print_info "Backup file: $backup_filename"
    print_info "Backup location: $BACKUP_DIR/"
    
    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR"
    
    # Build mysqldump command
    local mysqldump_cmd="mysqldump"
    local mysql_opts=""
    
    # Add host if specified
    if [[ -n "$MIGRATION_SOURCE_MYSQL_HOST" ]]; then
        mysql_opts="$mysql_opts -h $MIGRATION_SOURCE_MYSQL_HOST"
    fi
    
    # Add port if specified
    if [[ -n "$MIGRATION_SOURCE_MYSQL_PORT" ]]; then
        mysql_opts="$mysql_opts -P $MIGRATION_SOURCE_MYSQL_PORT"
    fi
    
    # Add user if specified
    if [[ -n "$MIGRATION_SOURCE_MYSQL_USER" ]]; then
        mysql_opts="$mysql_opts -u $MIGRATION_SOURCE_MYSQL_USER"
    fi
    
    # Add password if specified
    if [[ -n "$MIGRATION_SOURCE_MYSQL_PASSWORD" ]]; then
        mysql_opts="$mysql_opts -p$MIGRATION_SOURCE_MYSQL_PASSWORD"
    fi
    
    # Perform the backup with full schema and data
    print_info "Starting backup..."
    echo ""
    
    # mysqldump options:
    #   --single-transaction: Consistent backup without locking (InnoDB)
    #   --routines: Include stored procedures and functions
    #   --triggers: Include triggers
    #   --events: Include scheduled events
    #   --add-drop-database: Include DROP DATABASE statement
    #   --add-drop-table: Include DROP TABLE statements
    #   --create-options: Include all CREATE TABLE options
    #   --complete-insert: Use complete INSERT statements with column names
    #   --extended-insert: Use multiple-row INSERT syntax (faster restore)
    #   --quick: Retrieve rows one at a time (for large tables)
    #   --lock-tables=false: Don't lock tables (using single-transaction instead)
    
    if $mysqldump_cmd $mysql_opts \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --add-drop-database \
        --add-drop-table \
        --create-options \
        --complete-insert \
        --extended-insert \
        --quick \
        --lock-tables=false \
        --databases "$MIGRATION_SOURCE_MYSQL_NAME" > "$backup_path" 2>&1; then
        
        # Get file size
        local file_size=$(du -h "$backup_path" | cut -f1)
        
        # Compress the backup
        print_info "Compressing backup..."
        if gzip "$backup_path"; then
            local compressed_size=$(du -h "$compressed_path" | cut -f1)
            echo ""
            print_success "Backup completed successfully!"
            echo ""
            echo "  File: $compressed_path"
            echo "  Original size: $file_size"
            echo "  Compressed size: $compressed_size"
            echo ""
        else
            echo ""
            print_success "Backup completed (compression failed, keeping uncompressed)"
            echo ""
            echo "  File: $backup_path"
            echo "  Size: $file_size"
            echo ""
        fi
    else
        print_error "Backup failed!"
        # Show the error output if the file was created
        if [[ -f "$backup_path" ]]; then
            cat "$backup_path"
            rm -f "$backup_path"
        fi
        exit 1
    fi
}

# ============================================================================
# SCHEMA-ONLY BACKUP FUNCTION
# ============================================================================

backup_schema_source() {
    local name_component="$1"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_filename
    
    # Name component is required for schema backups
    if [[ -z "$name_component" ]]; then
        print_error "Name component is required for schema backup"
        echo "Usage: $(basename "$0") backup-schema-source <name>"
        echo "Example: $(basename "$0") backup-schema-source initial_schema"
        exit 1
    fi
    
    # Sanitize the name component (replace spaces and special chars with underscore)
    name_component=$(echo "$name_component" | sed 's/[^a-zA-Z0-9_-]/_/g')
    backup_filename="${MIGRATION_SOURCE_MYSQL_NAME}_schema_${name_component}_${timestamp}.sql"
    
    local backup_path="$SCHEMA_BACKUP_DIR/$backup_filename"
    
    print_header "Backing Up Source Database Schema (No Data)"
    
    # Validate required environment variables
    if [[ -z "$MIGRATION_SOURCE_MYSQL_NAME" ]]; then
        print_error "MIGRATION_SOURCE_MYSQL_NAME is not set in .env"
        exit 1
    fi
    
    print_info "Database: $MIGRATION_SOURCE_MYSQL_NAME"
    print_info "Host: ${MIGRATION_SOURCE_MYSQL_HOST:-localhost}:${MIGRATION_SOURCE_MYSQL_PORT:-3306}"
    print_info "Schema file: $backup_filename"
    print_info "Backup location: $SCHEMA_BACKUP_DIR/"
    
    # Ensure backup directory exists
    mkdir -p "$SCHEMA_BACKUP_DIR"
    
    # Build mysqldump command
    local mysqldump_cmd="mysqldump"
    local mysql_opts=""
    
    # Add host if specified
    if [[ -n "$MIGRATION_SOURCE_MYSQL_HOST" ]]; then
        mysql_opts="$mysql_opts -h $MIGRATION_SOURCE_MYSQL_HOST"
    fi
    
    # Add port if specified
    if [[ -n "$MIGRATION_SOURCE_MYSQL_PORT" ]]; then
        mysql_opts="$mysql_opts -P $MIGRATION_SOURCE_MYSQL_PORT"
    fi
    
    # Add user if specified
    if [[ -n "$MIGRATION_SOURCE_MYSQL_USER" ]]; then
        mysql_opts="$mysql_opts -u $MIGRATION_SOURCE_MYSQL_USER"
    fi
    
    # Add password if specified
    if [[ -n "$MIGRATION_SOURCE_MYSQL_PASSWORD" ]]; then
        mysql_opts="$mysql_opts -p$MIGRATION_SOURCE_MYSQL_PASSWORD"
    fi
    
    # Perform the schema-only backup
    print_info "Starting schema backup..."
    echo ""
    
    # mysqldump options for schema-only:
    #   --no-data: Don't dump table data (schema only)
    #   --routines: Include stored procedures and functions
    #   --triggers: Include triggers
    #   --events: Include scheduled events
    #   --add-drop-database: Include DROP DATABASE statement
    #   --add-drop-table: Include DROP TABLE statements
    #   --create-options: Include all CREATE TABLE options
    
    if $mysqldump_cmd $mysql_opts \
        --no-data \
        --routines \
        --triggers \
        --events \
        --add-drop-database \
        --add-drop-table \
        --create-options \
        --databases "$MIGRATION_SOURCE_MYSQL_NAME" > "$backup_path" 2>&1; then
        
        # Get file size
        local file_size=$(du -h "$backup_path" | cut -f1)
        
        echo ""
        print_success "Schema backup completed successfully!"
        echo ""
        echo "  File: $backup_path"
        echo "  Size: $file_size"
        echo ""
    else
        print_error "Schema backup failed!"
        # Show the error output if the file was created
        if [[ -f "$backup_path" ]]; then
            cat "$backup_path"
            rm -f "$backup_path"
        fi
        exit 1
    fi
}

# ============================================================================
# ENVIRONMENT VALIDATION
# ============================================================================

validate_env() {
    local validate_script="$SCRIPT_DIR/env-validate.sh"
    
    if [[ ! -f "$validate_script" ]]; then
        print_error "env-validate.sh not found at $validate_script"
        exit 1
    fi
    
    # Run the validation script (pass through all arguments)
    "$validate_script" "$@"
}

# ============================================================================
# AZURE PROVISIONING
# ============================================================================

run_provision() {
    local provision_script="$SCRIPT_DIR/azure-provision-infra.sh"
    
    if [[ ! -f "$provision_script" ]]; then
        print_error "azure-provision-infra.sh not found at $provision_script"
        exit 1
    fi
    
    # Run the provisioning script (pass through all arguments)
    "$provision_script" "$@"
}

# ============================================================================
# AZURE FILES MOUNT
# ============================================================================

run_mount() {
    local mount_script="$SCRIPT_DIR/azure-mount-fileshare-to-local.sh"
    
    if [[ ! -f "$mount_script" ]]; then
        print_error "azure-mount-fileshare-to-local.sh not found at $mount_script"
        exit 1
    fi
    
    # Script handles sudo internally - will prompt for password when needed
    "$mount_script" "$@"
}

run_unmount() {
    local mount_script="$SCRIPT_DIR/azure-mount-fileshare-to-local.sh"
    
    if [[ ! -f "$mount_script" ]]; then
        print_error "azure-mount-fileshare-to-local.sh not found at $mount_script"
        exit 1
    fi
    
    # Script handles sudo internally - will prompt for password when needed
    "$mount_script" unmount "$@"
}

run_mount_status() {
    local mount_script="$SCRIPT_DIR/azure-mount-fileshare-to-local.sh"
    
    if [[ ! -f "$mount_script" ]]; then
        print_error "azure-mount-fileshare-to-local.sh not found at $mount_script"
        exit 1
    fi
    
    # Status check doesn't require sudo
    "$mount_script" status
}

run_test_azure_capabilities() {
    local test_script="$SCRIPT_DIR/azure-test-capabilities.sh"
    
    if [[ ! -f "$test_script" ]]; then
        print_error "azure-test-capabilities.sh not found at $test_script"
        exit 1
    fi
    
    # Change to project root so script can find .env
    cd "$PROJECT_ROOT" || exit 1
    
    # Run the test script
    bash "$test_script"
}

run_teardown() {
    local teardown_script="$SCRIPT_DIR/azure-teardown-infra.sh"
    
    if [[ ! -f "$teardown_script" ]]; then
        print_error "azure-teardown-infra.sh not found at $teardown_script"
        exit 1
    fi
    
    # Change to project root so script can find .env
    cd "$PROJECT_ROOT" || exit 1
    
    # Run the teardown script
    bash "$teardown_script"
}

run_validate_resources() {
    local validate_script="$SCRIPT_DIR/azure-validate-resources.sh"
    
    if [[ ! -f "$validate_script" ]]; then
        print_error "azure-validate-resources.sh not found at $validate_script"
        exit 1
    fi
    
    cd "$PROJECT_ROOT" || exit 1
    bash "$validate_script" "$@"
}

run_mysql_status() {
    local status_script="$SCRIPT_DIR/azure-mysql-status.sh"
    
    if [[ ! -f "$status_script" ]]; then
        print_error "azure-mysql-status.sh not found at $status_script"
        exit 1
    fi
    
    cd "$PROJECT_ROOT" || exit 1
    bash "$status_script" "$@"
}

# ============================================================================
# DOCKER FUNCTIONS
# ============================================================================

run_docker_build() {
    local build_script="$SCRIPT_DIR/docker-build.sh"
    
    if [[ ! -f "$build_script" ]]; then
        print_error "docker-build.sh not found at $build_script"
        exit 1
    fi
    
    cd "$PROJECT_ROOT" || exit 1
    bash "$build_script" "$@"
}

run_docker_start() {
    local start_script="$SCRIPT_DIR/docker-start.sh"
    
    if [[ ! -f "$start_script" ]]; then
        print_error "docker-start.sh not found at $start_script"
        exit 1
    fi
    
    cd "$PROJECT_ROOT" || exit 1
    bash "$start_script" "$@"
}

run_docker_stop() {
    local stop_script="$SCRIPT_DIR/docker-stop.sh"
    
    if [[ ! -f "$stop_script" ]]; then
        print_error "docker-stop.sh not found at $stop_script"
        exit 1
    fi
    
    cd "$PROJECT_ROOT" || exit 1
    bash "$stop_script" "$@"
}

run_docker_validate() {
    local validate_script="$SCRIPT_DIR/docker-validate.sh"
    
    if [[ ! -f "$validate_script" ]]; then
        print_error "docker-validate.sh not found at $validate_script"
        exit 1
    fi
    
    cd "$PROJECT_ROOT" || exit 1
    bash "$validate_script"
}

run_docker_validate_lifecycle() {
    local phase="$1"
    local validate_script="$SCRIPT_DIR/docker-validate-lifecycle.sh"
    
    if [[ ! -f "$validate_script" ]]; then
        print_error "docker-validate-lifecycle.sh not found at $validate_script"
        exit 1
    fi
    
    cd "$PROJECT_ROOT" || exit 1
    bash "$validate_script" "$phase"
}

run_docker_teardown() {
    local teardown_script="$SCRIPT_DIR/docker-teardown.sh"
    
    if [[ ! -f "$teardown_script" ]]; then
        print_error "docker-teardown.sh not found at $teardown_script"
        exit 1
    fi
    
    cd "$PROJECT_ROOT" || exit 1
    bash "$teardown_script" "$@"
}

run_docker_logs() {
    cd "$PROJECT_ROOT" || exit 1
    docker compose logs -f
}

# ============================================================================
# BUILD STATUS
# ============================================================================

run_build_status() {
    # Source common.sh for colors
    source "$SCRIPT_DIR/lib/common.sh"
    load_env_common
    
    print_header "Build Cycle Status Summary"
    
    echo "Checking status of each build step..."
    echo ""
    
    local env_status="✗"
    local env_color="$RED"
    local azure_status="✗"
    local azure_color="$RED"
    local azure_note=""
    local mount_status="✗"
    local mount_color="$RED"
    local image_status="✗"
    local image_color="$RED"
    local container_status="✗"
    local container_color="$RED"
    local container_note=""
    
    # Check environment
    if "$SCRIPT_DIR/env-validate.sh" --quiet 2>/dev/null; then
        env_status="✓"
        env_color="$GREEN"
    fi
    
    # Check Azure resources (if logged in)
    if az account show &>/dev/null; then
        # Run azure-validate-resources.sh and check exit code (suppress output)
        if "$SCRIPT_DIR/azure-validate-resources.sh" &>/dev/null; then
            azure_status="✓"
            azure_color="$GREEN"
        else
            azure_status="◑"
            azure_color="$YELLOW"
            azure_note=" (partial)"
        fi
    else
        azure_status="○"
        azure_color="$DIM"
        azure_note=" (not logged in)"
    fi
    
    # Check mounts
    local mount_base="${AZURE_FILES_MOUNT_BASE:-/mnt/azure/suitecrm}"
    if mountpoint -q "$mount_base/${AZURE_FILES_SHARE_UPLOAD:-upload}" 2>/dev/null; then
        mount_status="✓"
        mount_color="$GREEN"
    fi
    
    # Check Docker image
    local image_name="${DOCKER_IMAGE_NAME:-buzzmag-suitecrm}"
    if docker image inspect "$image_name" &>/dev/null; then
        image_status="✓"
        image_color="$GREEN"
    fi
    
    # Check container
    local container_name="${DOCKER_CONTAINER_NAME:-suitecrm-web}"
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container_name}$"; then
        container_status="✓"
        container_color="$GREEN"
    elif docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${container_name}$"; then
        container_status="◑"
        container_color="$YELLOW"
        container_note=" (stopped)"
    fi
    
    echo "───────────────────────────────────────────────────────────────"
    printf "%-6s %-30s %s\n" "Step" "Component" "Status"
    echo "───────────────────────────────────────────────────────────────"
    echo -e "1      Environment (.env)          ${env_color}${env_status}${NC}"
    echo -e "2-3    Azure Resources             ${azure_color}${azure_status}${NC}${azure_note}"
    echo -e "4      Azure Files Mounts          ${mount_color}${mount_status}${NC}"
    echo -e "5-6    Docker Image                ${image_color}${image_status}${NC}"
    echo -e "7-8    Container Running           ${container_color}${container_status}${NC}${container_note}"
    echo "───────────────────────────────────────────────────────────────"
    echo ""
    
    # Recommendations
    echo "Recommendations:"
    echo ""
    
    if [[ "$env_status" == "✗" ]]; then
        echo "  → Run: ./scripts/cli.sh validate-env"
    elif [[ "$azure_status" == "✗" ]] || [[ "$azure_status" == "◑" ]]; then
        if [[ "$azure_status" == "○" ]]; then
            echo "  → Run: az login"
        else
            echo "  → Run: ./scripts/cli.sh provision"
        fi
    elif [[ "$mount_status" == "✗" ]]; then
        echo "  → Run: ./scripts/cli.sh mount"
    elif [[ "$image_status" == "✗" ]]; then
        echo "  → Run: ./scripts/cli.sh docker-build"
    elif [[ "$container_status" == "✗" ]]; then
        echo "  → Run: ./scripts/cli.sh docker-start"
    elif [[ "$container_status" == "◑" ]]; then
        echo "  → Container is stopped. Run: ./scripts/cli.sh docker-start"
    else
        echo "  ✓ All components ready. SuiteCRM should be accessible."
    fi
    
    echo ""
}

# ============================================================================
# LOG VIEWING FUNCTIONS
# ============================================================================

LOGS_DIR="$PROJECT_ROOT/logs"

show_log() {
    local script_name="$1"
    local log_pattern="${LOGS_DIR}/latest_${script_name}_*.log"
    
    # Find the latest log file
    local latest_log
    latest_log=$(ls -t $log_pattern 2>/dev/null | head -1)
    
    if [[ -z "$latest_log" || ! -f "$latest_log" ]]; then
        print_error "No log found for ${script_name}"
        print_info "Run the ${script_name}.sh script first to generate a log"
        exit 1
    fi
    
    print_header "Most Recent ${script_name} Log"
    echo "File: $latest_log"
    echo ""
    cat "$latest_log"
}

list_logs() {
    print_header "Available Logs"
    
    if [[ ! -d "$LOGS_DIR" ]]; then
        print_info "No logs directory found"
        exit 0
    fi
    
    local log_count
    log_count=$(find "$LOGS_DIR" -name "*.log" 2>/dev/null | wc -l)
    
    if [[ "$log_count" -eq 0 ]]; then
        print_info "No log files found"
        exit 0
    fi
    
    echo "Latest logs (prefixed with 'latest_'):"
    echo ""
    
    # Show latest logs first
    for log in "${LOGS_DIR}"/latest_*.log; do
        if [[ -f "$log" ]]; then
            local size
            size=$(du -h "$log" | cut -f1)
            local modified
            modified=$(stat -c '%y' "$log" 2>/dev/null | cut -d'.' -f1)
            echo "  [LATEST] $(basename "$log") ($size, $modified)"
        fi
    done
    
    echo ""
    echo "Previous logs:"
    echo ""
    
    # Show non-latest logs
    for log in "${LOGS_DIR}"/*.log; do
        if [[ -f "$log" && ! "$(basename "$log")" =~ ^latest_ ]]; then
            local size
            size=$(du -h "$log" | cut -f1)
            local modified
            modified=$(stat -c '%y' "$log" 2>/dev/null | cut -d'.' -f1)
            echo "  $(basename "$log") ($size, $modified)"
        fi
    done
    
    echo ""
    print_info "Log directory: $LOGS_DIR"
}

# ============================================================================
# ENVIRONMENT EXAMPLE GENERATOR
# ============================================================================

generate_env_example() {
    print_header "Generating .env.example from .env"
    
    local env_file="$PROJECT_ROOT/.env"
    local example_file="$PROJECT_ROOT/.env.example"
    
    if [[ ! -f "$env_file" ]]; then
        print_error ".env file not found at $env_file"
        exit 1
    fi
    
    print_info "Reading: $env_file"
    print_info "Writing: $example_file"
    
    # Patterns for sensitive values that should be replaced with placeholders
    # These patterns match the variable NAME, and we replace their VALUE
    local sensitive_patterns=(
        "_PASSWORD"
        "_SECRET"
        "_KEY"
        "_TOKEN"
        "_API_KEY"
        "SUBSCRIPTION_ID"
    )
    
    # Process the .env file line by line
    local replaced_count=0
    local kept_count=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments - pass through unchanged
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            echo "$line"
            continue
        fi
        
        # Check if this is a variable assignment
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            local var_name="${BASH_REMATCH[1]}"
            local var_value="${BASH_REMATCH[2]}"
            
            # Check if this variable name matches any sensitive pattern
            local is_sensitive=false
            for pattern in "${sensitive_patterns[@]}"; do
                if [[ "$var_name" == *"$pattern"* ]]; then
                    is_sensitive=true
                    break
                fi
            done
            
            if [[ "$is_sensitive" == true ]]; then
                # Replace with placeholder in [UPPER_CASE] format
                echo "${var_name}=[YOUR_${var_name}_HERE]"
                replaced_count=$((replaced_count + 1))
            else
                # Keep the original value
                echo "$line"
                kept_count=$((kept_count + 1))
            fi
        else
            # Pass through any other lines unchanged
            echo "$line"
        fi
    done < "$env_file" > "$example_file"
    
    echo ""
    print_success ".env.example generated successfully"
    print_info "Sensitive values replaced: $replaced_count"
    print_info "Non-sensitive values kept: $kept_count"
    echo ""
    print_info "Review $example_file to ensure no sensitive data remains."
}

# ============================================================================
# MAIN COMMAND DISPATCHER
# ============================================================================

main() {
    local command="$1"
    shift || true
    
    case "$command" in
        backup-db-source)
            backup_db_source "$1"
            ;;
        backup-schema-source)
            backup_schema_source "$1"
            ;;
        validate-env)
            validate_env "$@"
            ;;
        show-env)
            "$SCRIPT_DIR/env-show.sh" "$@"
            ;;
        provision)
            run_provision "$@"
            ;;
        mount)
            run_mount "$@"
            ;;
        unmount)
            run_unmount "$@"
            ;;
        mount-status)
            run_mount_status
            ;;
        show-log-provision)
            show_log "azure-provision"
            ;;
        show-log-mount)
            show_log "azure-mount"
            ;;
        list-logs)
            list_logs
            ;;
        generate-env-example)
            generate_env_example
            ;;
        test-azure-capabilities)
            run_test_azure_capabilities
            ;;
        validate-resources)
            run_validate_resources
            ;;
        mysql-status)
            run_mysql_status "$@"
            ;;
        teardown)
            run_teardown
            ;;
        docker-build)
            run_docker_build "$@"
            ;;
        docker-start)
            run_docker_start "$@"
            ;;
        docker-stop)
            run_docker_stop "$@"
            ;;
        docker-validate)
            run_docker_validate
            ;;
        docker-validate-pre)
            run_docker_validate_lifecycle "pre"
            ;;
        docker-validate-post)
            run_docker_validate_lifecycle "post"
            ;;
        docker-validate-deployed)
            run_docker_validate_lifecycle "deployed"
            ;;
        docker-validate-all)
            run_docker_validate_lifecycle "all"
            ;;
        docker-teardown)
            run_docker_teardown "$@"
            ;;
        docker-logs)
            run_docker_logs
            ;;
        build-status)
            run_build_status
            ;;
        help|--help|-h|"")
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main with all arguments
main "$@"

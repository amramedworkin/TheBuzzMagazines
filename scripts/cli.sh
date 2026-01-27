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

    provision [options]         Run Azure resource provisioning
                                Creates Azure MySQL, Storage, ACR resources
                                Options:
                                  -y, --yes      Run without prompting

    mount [options]             Mount Azure Files locally
                                Mounts Azure file shares for local development
                                Options:
                                  -y, --yes      Run without prompting
                                Note: Requires sudo

    unmount [options]           Unmount Azure Files
                                Options:
                                  -y, --yes      Run without prompting
                                Note: Requires sudo

    show-log-provision          Show the most recent azure-provision.sh log
    show-log-mount              Show the most recent azure-mount.sh log
    list-logs                   List all available logs

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
    local validate_script="$SCRIPT_DIR/validate-env.sh"
    
    if [[ ! -f "$validate_script" ]]; then
        print_error "validate-env.sh not found at $validate_script"
        exit 1
    fi
    
    # Run the validation script (pass through all arguments)
    "$validate_script" "$@"
}

# ============================================================================
# AZURE PROVISIONING
# ============================================================================

run_provision() {
    local provision_script="$SCRIPT_DIR/azure-provision.sh"
    
    if [[ ! -f "$provision_script" ]]; then
        print_error "azure-provision.sh not found at $provision_script"
        exit 1
    fi
    
    # Run the provisioning script (pass through all arguments)
    "$provision_script" "$@"
}

# ============================================================================
# AZURE FILES MOUNT
# ============================================================================

run_mount() {
    local mount_script="$SCRIPT_DIR/azure-mount.sh"
    
    if [[ ! -f "$mount_script" ]]; then
        print_error "azure-mount.sh not found at $mount_script"
        exit 1
    fi
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "Mount requires sudo. Run: sudo $0 mount $*"
        exit 1
    fi
    
    # Run the mount script (pass through all arguments)
    "$mount_script" "$@"
}

run_unmount() {
    local mount_script="$SCRIPT_DIR/azure-mount.sh"
    
    if [[ ! -f "$mount_script" ]]; then
        print_error "azure-mount.sh not found at $mount_script"
        exit 1
    fi
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "Unmount requires sudo. Run: sudo $0 unmount $*"
        exit 1
    fi
    
    # Run the mount script with unmount action (pass through all arguments)
    "$mount_script" unmount "$@"
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
        provision)
            run_provision "$@"
            ;;
        mount)
            run_mount "$@"
            ;;
        unmount)
            run_unmount "$@"
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

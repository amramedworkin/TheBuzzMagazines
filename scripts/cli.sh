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

    help                        Show this help message

Environment:
    Configuration is loaded from .env file in project root.
    Required variables for database operations:
        SOURCE_DB_HOST, SOURCE_DB_PORT, SOURCE_DB_NAME
        SOURCE_DB_USER, SOURCE_DB_PASSWORD

Examples:
    $(basename "$0") backup-db-source
    $(basename "$0") backup-db-source pre_migration
    $(basename "$0") backup-db-source before_updating_schema
    $(basename "$0") backup-schema-source initial_schema
    $(basename "$0") backup-schema-source after_adding_views

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
        backup_filename="${SOURCE_DB_NAME}_${name_component}_${timestamp}.sql"
    else
        backup_filename="${SOURCE_DB_NAME}_${timestamp}.sql"
    fi
    
    local backup_path="$BACKUP_DIR/$backup_filename"
    local compressed_path="${backup_path}.gz"
    
    print_header "Backing Up Source Database"
    
    # Validate required environment variables
    if [[ -z "$SOURCE_DB_NAME" ]]; then
        print_error "SOURCE_DB_NAME is not set in .env"
        exit 1
    fi
    
    print_info "Database: $SOURCE_DB_NAME"
    print_info "Host: ${SOURCE_DB_HOST:-localhost}:${SOURCE_DB_PORT:-3306}"
    print_info "Backup file: $backup_filename"
    print_info "Backup location: $BACKUP_DIR/"
    
    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR"
    
    # Build mysqldump command
    local mysqldump_cmd="mysqldump"
    local mysql_opts=""
    
    # Add host if specified
    if [[ -n "$SOURCE_DB_HOST" ]]; then
        mysql_opts="$mysql_opts -h $SOURCE_DB_HOST"
    fi
    
    # Add port if specified
    if [[ -n "$SOURCE_DB_PORT" ]]; then
        mysql_opts="$mysql_opts -P $SOURCE_DB_PORT"
    fi
    
    # Add user if specified
    if [[ -n "$SOURCE_DB_USER" ]]; then
        mysql_opts="$mysql_opts -u $SOURCE_DB_USER"
    fi
    
    # Add password if specified
    if [[ -n "$SOURCE_DB_PASSWORD" ]]; then
        mysql_opts="$mysql_opts -p$SOURCE_DB_PASSWORD"
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
        --databases "$SOURCE_DB_NAME" > "$backup_path" 2>&1; then
        
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
    backup_filename="${SOURCE_DB_NAME}_schema_${name_component}_${timestamp}.sql"
    
    local backup_path="$SCHEMA_BACKUP_DIR/$backup_filename"
    
    print_header "Backing Up Source Database Schema (No Data)"
    
    # Validate required environment variables
    if [[ -z "$SOURCE_DB_NAME" ]]; then
        print_error "SOURCE_DB_NAME is not set in .env"
        exit 1
    fi
    
    print_info "Database: $SOURCE_DB_NAME"
    print_info "Host: ${SOURCE_DB_HOST:-localhost}:${SOURCE_DB_PORT:-3306}"
    print_info "Schema file: $backup_filename"
    print_info "Backup location: $SCHEMA_BACKUP_DIR/"
    
    # Ensure backup directory exists
    mkdir -p "$SCHEMA_BACKUP_DIR"
    
    # Build mysqldump command
    local mysqldump_cmd="mysqldump"
    local mysql_opts=""
    
    # Add host if specified
    if [[ -n "$SOURCE_DB_HOST" ]]; then
        mysql_opts="$mysql_opts -h $SOURCE_DB_HOST"
    fi
    
    # Add port if specified
    if [[ -n "$SOURCE_DB_PORT" ]]; then
        mysql_opts="$mysql_opts -P $SOURCE_DB_PORT"
    fi
    
    # Add user if specified
    if [[ -n "$SOURCE_DB_USER" ]]; then
        mysql_opts="$mysql_opts -u $SOURCE_DB_USER"
    fi
    
    # Add password if specified
    if [[ -n "$SOURCE_DB_PASSWORD" ]]; then
        mysql_opts="$mysql_opts -p$SOURCE_DB_PASSWORD"
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
        --databases "$SOURCE_DB_NAME" > "$backup_path" 2>&1; then
        
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

#!/bin/bash

# =================================================================
# TheBuzzMagazines - SuiteCRM Azure Environment | System Control Menu
# =================================================================
# Interactive cascading menu for managing Azure resources, Docker, and SuiteCRM
# =================================================================

# --- Colors (optimized for black background) ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Submenu indicator color (distinct from action items)
SUBMENU_COLOR='\033[1;36m'  # Bold Cyan for submenu titles
SUBMENU_DESC='\033[0;90m'   # Dark gray for submenu descriptions
ACTION_COLOR='\033[0;37m'   # Standard white for action items

# --- Paths & Files ---
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$PROJECT_DIR/scripts"
LOG_DIR="$PROJECT_DIR/logs"
CLI_SCRIPT="$SCRIPT_DIR/cli.sh"

mkdir -p "$LOG_DIR"

# --- Environment Loader ---
load_env() {
    local env_file="$PROJECT_DIR/.env"
    if [ -f "$env_file" ]; then
        set -a
        source "$env_file"
        set +a
        
        # Expand nested variables from .env (they use ${AZURE_RESOURCE_PREFIX})
        # These are evaluated here because bash doesn't expand nested vars on source
        eval "AZURE_RESOURCE_GROUP=$AZURE_RESOURCE_GROUP"
        eval "AZURE_PROVISION_MYSQL_SERVER_NAME=$AZURE_PROVISION_MYSQL_SERVER_NAME"
        eval "AZURE_STORAGE_ACCOUNT_NAME=$AZURE_STORAGE_ACCOUNT_NAME"
        eval "AZURE_ACR_NAME=$AZURE_ACR_NAME"
        eval "AZURE_CONTAINER_APP_ENV=$AZURE_CONTAINER_APP_ENV"
    fi
}

load_env

# --- Status Helpers ---

get_azure_login_status() {
    if az account show &> /dev/null; then
        echo -e "${GREEN}●${NC}"
    else
        echo -e "${RED}○${NC}"
    fi
}

get_docker_status() {
    if docker info &> /dev/null; then
        if docker compose ps 2>/dev/null | grep -q "suitecrm-web"; then
            if docker compose ps 2>/dev/null | grep "suitecrm-web" | grep -q "Up"; then
                echo -e "${GREEN}●${NC}"
            else
                echo -e "${YELLOW}◑${NC}"
            fi
        else
            echo -e "${YELLOW}○${NC}"
        fi
    else
        echo -e "${RED}○${NC}"
    fi
}

get_mount_status() {
    local mount_base="${AZURE_FILES_MOUNT_BASE:-/mnt/azure/suitecrm}"
    if mountpoint -q "$mount_base/upload" 2>/dev/null; then
        echo -e "${GREEN}●${NC}"
    else
        echo -e "${RED}○${NC}"
    fi
}

get_env_status() {
    if "$SCRIPT_DIR/validate-env.sh" --quiet 2>/dev/null; then
        echo -e "${GREEN}●${NC}"
    else
        echo -e "${RED}○${NC}"
    fi
}

# --- Menu Header ---
show_header() {
    local title="$1"
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${BOLD}TheBuzzMagazines${NC} - ${title}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_status_bar() {
    local azure_stat=$(get_azure_login_status)
    local docker_stat=$(get_docker_status)
    local mount_stat=$(get_mount_status)
    local env_stat=$(get_env_status)
    
    echo -e "  ${DIM}Status:${NC} Azure $azure_stat  Docker $docker_stat  Mount $mount_stat  Env $env_stat"
    echo ""
}

# --- Submenu Description Helper ---
print_submenu_option() {
    local key="$1"
    local title="$2"
    local description="$3"
    
    echo -e "    ${BOLD}${key})${NC}  ${SUBMENU_COLOR}${title}${NC}"
    echo -e "        ${SUBMENU_DESC}${description}${NC}"
}

print_action_option() {
    local key="$1"
    local title="$2"
    
    echo -e "    ${BOLD}${key})${NC}  ${ACTION_COLOR}${title}${NC}"
}

# =============================================================================
# MAIN MENU
# =============================================================================

show_main_menu() {
    show_header "Control Center"
    show_status_bar
    
    print_submenu_option "1" "Environment" \
        "validate, edit .env configuration"
    print_submenu_option "2" "Azure Setup" \
        "login, provision resources, mount/unmount files"
    print_submenu_option "3" "Docker" \
        "build, start, stop, view logs"
    print_submenu_option "4" "Database" \
        "backup source db, backup schema"
    print_submenu_option "5" "Logs" \
        "view provision/mount logs, list all"
    print_submenu_option "f" "Quick Actions" \
        "full setup, restart SuiteCRM"
    echo ""
    print_action_option "0" "Exit"
    echo ""
    echo -n "  Select > "
}

# =============================================================================
# ENVIRONMENT SUBMENU
# =============================================================================

show_environment_menu() {
    show_header "Environment Configuration"
    show_status_bar
    
    print_action_option "1" "Validate .env file"
    print_action_option "2" "Edit .env file"
    print_action_option "3" "Generate .env.example (sanitize sensitive data)"
    echo ""
    print_action_option "0" "Back to Main Menu"
    echo ""
    echo -n "  Select > "
}

handle_environment_menu() {
    while true; do
        show_environment_menu
        read -r choice
        case $choice in
            1) validate_env_interactive ;;
            2) edit_env ;;
            3) generate_env_example_interactive ;;
            0) return ;;
            *) ;;
        esac
    done
}

# =============================================================================
# AZURE SETUP SUBMENU
# =============================================================================

show_azure_menu() {
    show_header "Azure Setup"
    show_status_bar
    
    print_action_option "1" "Azure Login"
    print_action_option "2" "Run Provisioning"
    print_action_option "3" "Mount Azure Files"
    print_action_option "4" "Unmount Azure Files"
    print_action_option "5" "Test Azure Capabilities"
    print_action_option "6" "Validate Resources"
    echo -e "  ${RED}---${NC}"
    print_action_option "7" "Teardown Infrastructure (DESTRUCTIVE)"
    echo ""
    print_action_option "0" "Back to Main Menu"
    echo ""
    echo -n "  Select > "
}

handle_azure_menu() {
    while true; do
        show_azure_menu
        read -r choice
        case $choice in
            1) azure_login ;;
            2) run_provision_interactive ;;
            3) run_mount_interactive ;;
            4) run_unmount_interactive ;;
            5) test_azure_capabilities_interactive ;;
            6) validate_resources_interactive ;;
            7) run_teardown_interactive ;;
            0) return ;;
            *) ;;
        esac
    done
}

# =============================================================================
# DOCKER SUBMENU
# =============================================================================

show_docker_menu() {
    show_header "Docker Management"
    show_status_bar
    
    print_action_option "1" "Build Docker Image"
    print_action_option "2" "Start SuiteCRM"
    print_action_option "3" "Stop SuiteCRM"
    print_action_option "4" "Restart SuiteCRM"
    print_action_option "5" "Validate Docker Status"
    print_action_option "6" "View Docker Logs"
    echo -e "  ${RED}---${NC}"
    print_action_option "7" "Teardown Docker (DESTRUCTIVE)"
    echo ""
    print_action_option "0" "Back to Main Menu"
    echo ""
    echo -n "  Select > "
}

handle_docker_menu() {
    while true; do
        show_docker_menu
        read -r choice
        case $choice in
            1) docker_build_interactive ;;
            2) docker_start_interactive ;;
            3) docker_stop_interactive ;;
            4) restart_suitecrm ;;
            5) docker_validate_interactive ;;
            6) docker_logs ;;
            7) docker_teardown_interactive ;;
            0) return ;;
            *) ;;
        esac
    done
}

# =============================================================================
# DATABASE SUBMENU
# =============================================================================

show_database_menu() {
    show_header "Database Operations"
    show_status_bar
    
    print_action_option "1" "Backup Source Database (full)"
    print_action_option "2" "Backup Source Schema (structure only)"
    echo ""
    print_action_option "0" "Back to Main Menu"
    echo ""
    echo -n "  Select > "
}

handle_database_menu() {
    while true; do
        show_database_menu
        read -r choice
        case $choice in
            1) backup_db_interactive ;;
            2) backup_schema_interactive ;;
            0) return ;;
            *) ;;
        esac
    done
}

# =============================================================================
# LOGS SUBMENU
# =============================================================================

show_logs_menu() {
    show_header "Log Viewer"
    
    print_action_option "1" "View Provision Log (latest)"
    print_action_option "2" "View Mount Log (latest)"
    print_action_option "3" "List All Logs"
    echo ""
    print_action_option "0" "Back to Main Menu"
    echo ""
    echo -n "  Select > "
}

handle_logs_menu() {
    while true; do
        show_logs_menu
        read -r choice
        case $choice in
            1) view_provision_log ;;
            2) view_mount_log ;;
            3) list_logs_interactive ;;
            0) return ;;
            *) ;;
        esac
    done
}

# =============================================================================
# QUICK ACTIONS SUBMENU
# =============================================================================

show_quick_menu() {
    show_header "Quick Actions"
    show_status_bar
    
    print_action_option "1" "Full Setup (provision → mount → build → start)"
    print_action_option "2" "Restart SuiteCRM"
    print_action_option "3" "Rebuild & Restart (build → restart)"
    echo ""
    print_action_option "0" "Back to Main Menu"
    echo ""
    echo -n "  Select > "
}

handle_quick_menu() {
    while true; do
        show_quick_menu
        read -r choice
        case $choice in
            1) full_setup ;;
            2) restart_suitecrm ;;
            3) rebuild_and_restart ;;
            0) return ;;
            *) ;;
        esac
    done
}

# =============================================================================
# ACTION FUNCTIONS
# =============================================================================

validate_env_interactive() {
    show_header "Validate Environment"
    
    "$CLI_SCRIPT" validate-env
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

edit_env() {
    local editor="${EDITOR:-nano}"
    "$editor" "$PROJECT_DIR/.env"
    load_env  # Reload after editing
}

generate_env_example_interactive() {
    show_header "Generate .env.example"
    
    "$CLI_SCRIPT" generate-env-example
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

test_azure_capabilities_interactive() {
    show_header "Test Azure Capabilities"
    
    "$CLI_SCRIPT" test-azure-capabilities
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

validate_resources_interactive() {
    show_header "Validate Azure Resources"
    
    "$CLI_SCRIPT" validate-resources
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

run_teardown_interactive() {
    show_header "Teardown Azure Infrastructure"
    
    echo -e "${RED}WARNING: This will permanently delete all Azure resources!${NC}"
    echo -e "${RED}This includes: MySQL Server, Storage Account, ACR, and Resource Group${NC}"
    echo ""
    echo -n "Type 'DELETE' to confirm: "
    read -r confirm
    
    if [[ "$confirm" != "DELETE" ]]; then
        echo -e "${YELLOW}Teardown cancelled.${NC}"
        echo "Press Enter to continue..."
        read -r
        return
    fi
    
    "$CLI_SCRIPT" teardown
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

azure_login() {
    show_header "Azure Login"
    
    az login
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

run_provision_interactive() {
    show_header "Azure Provisioning"
    
    echo -e "${YELLOW}Run in interactive mode (pause at each step)?${NC}"
    echo ""
    print_action_option "1" "Yes, interactive (default)"
    print_action_option "2" "No, run all steps automatically"
    echo ""
    echo -n "  Choice [1]: "
    read -r mode_choice
    
    echo ""
    
    if [[ "$mode_choice" == "2" ]]; then
        "$CLI_SCRIPT" provision -y
    else
        "$CLI_SCRIPT" provision
    fi
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

run_mount_interactive() {
    show_header "Mount Azure Files"
    
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}This action requires sudo.${NC}"
        echo ""
        echo "Re-running with sudo..."
        echo ""
        sudo "$SCRIPT_DIR/azure-mount-fileshare-to-local.sh"
    else
        "$CLI_SCRIPT" mount
    fi
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

run_unmount_interactive() {
    show_header "Unmount Azure Files"
    
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}This action requires sudo.${NC}"
        echo ""
        echo "Re-running with sudo..."
        echo ""
        sudo "$SCRIPT_DIR/azure-mount-fileshare-to-local.sh" unmount
    else
        "$CLI_SCRIPT" unmount
    fi
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

docker_build_interactive() {
    show_header "Build Docker Image"
    
    "$CLI_SCRIPT" docker-build
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

docker_start_interactive() {
    show_header "Start SuiteCRM"
    
    "$CLI_SCRIPT" docker-start
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

docker_stop_interactive() {
    show_header "Stop SuiteCRM"
    
    "$CLI_SCRIPT" docker-stop
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

docker_validate_interactive() {
    show_header "Validate Docker Status"
    
    "$CLI_SCRIPT" docker-validate
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

docker_teardown_interactive() {
    show_header "Teardown Docker"
    
    echo -e "${RED}WARNING: This will remove all Docker containers, images, and volumes!${NC}"
    echo ""
    
    "$CLI_SCRIPT" docker-teardown
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

docker_logs() {
    show_header "Docker Logs"
    
    echo -e "${YELLOW}Select log to view:${NC}"
    echo ""
    print_action_option "1" "Web container (SuiteCRM)"
    print_action_option "2" "All containers"
    echo ""
    echo -n "  Choice [1]: "
    read -r log_choice
    
    echo ""
    echo -e "${DIM}Press Ctrl+C to exit log view${NC}"
    echo ""
    
    cd "$PROJECT_DIR" || exit
    
    case $log_choice in
        2) docker compose logs -f ;;
        *) docker compose logs -f web ;;
    esac
}

backup_db_interactive() {
    show_header "Backup Source Database"
    
    echo -e "${YELLOW}Enter backup description (optional):${NC}"
    echo -n "  > "
    read -r description
    
    echo ""
    "$CLI_SCRIPT" backup-db-source "$description"
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

backup_schema_interactive() {
    show_header "Backup Source Schema"
    
    echo -e "${YELLOW}Enter schema backup name (required):${NC}"
    echo -n "  > "
    read -r name
    
    if [[ -z "$name" ]]; then
        echo -e "${RED}Name is required${NC}"
        echo "Press Enter to continue..."
        read -r
        return
    fi
    
    echo ""
    "$CLI_SCRIPT" backup-schema-source "$name"
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

view_provision_log() {
    show_header "Provision Log"
    
    "$CLI_SCRIPT" show-log-provision
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

view_mount_log() {
    show_header "Mount Log"
    
    "$CLI_SCRIPT" show-log-mount
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

list_logs_interactive() {
    show_header "All Logs"
    
    "$CLI_SCRIPT" list-logs
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

full_setup() {
    show_header "Full Setup"
    
    echo -e "${YELLOW}This will run:${NC}"
    echo "  1. Validate environment"
    echo "  2. Azure provisioning"
    echo "  3. Mount Azure Files"
    echo "  4. Build Docker image"
    echo "  5. Start SuiteCRM"
    echo ""
    echo -n "  Proceed? (y/n) [y]: "
    read -r confirm
    
    if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
        echo -e "${YELLOW}Cancelled${NC}"
        echo "Press Enter to continue..."
        read -r
        return
    fi
    
    echo ""
    
    # Step 1: Validate
    echo -e "${CYAN}Step 1/5: Validating environment...${NC}"
    if ! "$CLI_SCRIPT" validate-env --errors-only; then
        echo -e "${RED}Environment validation failed. Please fix errors first.${NC}"
        echo "Press Enter to continue..."
        read -r
        return
    fi
    echo -e "${GREEN}✓ Environment valid${NC}"
    echo ""
    
    # Step 2: Provision
    echo -e "${CYAN}Step 2/5: Running Azure provisioning...${NC}"
    if ! "$CLI_SCRIPT" provision -y; then
        echo -e "${RED}Provisioning failed. Check logs.${NC}"
        echo "Press Enter to continue..."
        read -r
        return
    fi
    echo -e "${GREEN}✓ Provisioning complete${NC}"
    echo ""
    
    # Step 3: Mount
    echo -e "${CYAN}Step 3/5: Mounting Azure Files...${NC}"
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}Mounting requires sudo...${NC}"
        if ! sudo "$SCRIPT_DIR/azure-mount-fileshare-to-local.sh" -y; then
            echo -e "${RED}Mount failed. Check logs.${NC}"
            echo "Press Enter to continue..."
            read -r
            return
        fi
    else
        if ! "$CLI_SCRIPT" mount -y; then
            echo -e "${RED}Mount failed. Check logs.${NC}"
            echo "Press Enter to continue..."
            read -r
            return
        fi
    fi
    echo -e "${GREEN}✓ Azure Files mounted${NC}"
    echo ""
    
    # Step 4: Build
    echo -e "${CYAN}Step 4/5: Building Docker image...${NC}"
    cd "$PROJECT_DIR" || exit
    if ! docker compose build; then
        echo -e "${RED}Docker build failed.${NC}"
        echo "Press Enter to continue..."
        read -r
        return
    fi
    echo -e "${GREEN}✓ Docker image built${NC}"
    echo ""
    
    # Step 5: Start
    echo -e "${CYAN}Step 5/5: Starting SuiteCRM...${NC}"
    if ! docker compose up -d; then
        echo -e "${RED}Docker start failed.${NC}"
        echo "Press Enter to continue..."
        read -r
        return
    fi
    echo -e "${GREEN}✓ SuiteCRM started${NC}"
    echo ""
    
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Full setup complete!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Access SuiteCRM at: http://localhost"
    echo ""
    echo "Press Enter to continue..."
    read -r
}

restart_suitecrm() {
    show_header "Restart SuiteCRM"
    
    cd "$PROJECT_DIR" || exit
    
    echo -e "${YELLOW}Stopping...${NC}"
    docker compose down
    
    echo ""
    echo -e "${YELLOW}Starting...${NC}"
    docker compose up -d
    
    echo ""
    echo -e "${GREEN}SuiteCRM restarted.${NC}"
    echo "Access at: http://localhost"
    echo ""
    echo "Press Enter to continue..."
    read -r
}

rebuild_and_restart() {
    show_header "Rebuild & Restart"
    
    cd "$PROJECT_DIR" || exit
    
    echo -e "${YELLOW}Stopping...${NC}"
    docker compose down
    
    echo ""
    echo -e "${YELLOW}Building...${NC}"
    if ! docker compose build; then
        echo -e "${RED}Build failed.${NC}"
        echo "Press Enter to continue..."
        read -r
        return
    fi
    
    echo ""
    echo -e "${YELLOW}Starting...${NC}"
    docker compose up -d
    
    echo ""
    echo -e "${GREEN}SuiteCRM rebuilt and restarted.${NC}"
    echo "Access at: http://localhost"
    echo ""
    echo "Press Enter to continue..."
    read -r
}

# =============================================================================
# MAIN LOOP
# =============================================================================

while true; do
    show_main_menu
    read -r choice
    case $choice in
        1) handle_environment_menu ;;
        2) handle_azure_menu ;;
        3) handle_docker_menu ;;
        4) handle_database_menu ;;
        5) handle_logs_menu ;;
        f|F) handle_quick_menu ;;
        0) 
            echo ""
            echo -e "${BLUE}Exiting. Docker containers may still be running.${NC}"
            exit 0 
            ;;
        *)
            # Invalid input, just refresh
            ;;
    esac
done

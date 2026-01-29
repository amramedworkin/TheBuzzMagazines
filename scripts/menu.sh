#!/bin/bash

# =================================================================
# TheBuzzMagazines - SuiteCRM Azure Environment | System Control Menu
# =================================================================
# Interactive cascading menu for managing Azure resources, Docker, and SuiteCRM
# =================================================================

# --- Paths & Files ---
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$PROJECT_DIR/scripts"
LOG_DIR="$PROJECT_DIR/logs"
CLI_SCRIPT="$SCRIPT_DIR/cli.sh"
ENV_FILE="$PROJECT_DIR/.env"

# Source common utilities (colors, logging, etc.)
source "$SCRIPT_DIR/lib/common.sh"

mkdir -p "$LOG_DIR"

# --- Environment Loader ---
load_env() {
    if [ -f "$ENV_FILE" ]; then
        load_env_common
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
    local container_name="${DOCKER_CONTAINER_NAME:-suitecrm-web}"
    if docker info &> /dev/null; then
        if docker compose ps 2>/dev/null | grep -q "$container_name"; then
            if docker compose ps 2>/dev/null | grep "$container_name" | grep -q "Up"; then
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
    if "$SCRIPT_DIR/env-validate.sh" --quiet 2>/dev/null; then
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
    print_submenu_option "6" "Quick Actions" \
        "full setup, restart SuiteCRM"
    echo ""
    print_submenu_option "b" "Build Cycle" \
        "step-by-step local build with validation"
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
    print_submenu_option "4" "Show Environment Variables" \
        "display expanded values by category"
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
            4) handle_show_env_menu ;;
            0) return ;;
            *) ;;
        esac
    done
}

# --- Show Environment Variables Submenu ---
show_env_vars_menu() {
    show_header "Show Environment Variables"
    
    echo -e "  ${DIM}Display fully expanded .env values by category${NC}"
    echo ""
    print_action_option "1" "All Variables"
    print_action_option "2" "Global Configuration"
    print_action_option "3" "Azure Configuration"
    print_action_option "4" "Docker Configuration"
    print_action_option "5" "MySQL / Database"
    print_action_option "6" "SuiteCRM Application"
    print_action_option "7" "Migration Settings"
    echo ""
    print_action_option "0" "Back"
    echo ""
    echo -n "  Select > "
}

handle_show_env_menu() {
    while true; do
        show_env_vars_menu
        read -r choice
        case $choice in
            1) show_env_category "all" ;;
            2) show_env_category "global" ;;
            3) show_env_category "azure" ;;
            4) show_env_category "docker" ;;
            5) show_env_category "mysql" ;;
            6) show_env_category "suitecrm" ;;
            7) show_env_category "migration" ;;
            0) return ;;
            *) ;;
        esac
    done
}

show_env_category() {
    local category="$1"
    clear
    "$SCRIPT_DIR/env-show.sh" "$category"
    echo ""
    echo "Press Enter to continue..."
    read -r
}

# =============================================================================
# AZURE SETUP SUBMENU
# =============================================================================

show_azure_menu() {
    show_header "Azure Setup"
    show_status_bar
    
    print_action_option "1" "Azure Login"
    print_submenu_option "2" "Provisioning" \
        "create resources, check status, retry shares"
    print_submenu_option "3" "Azure Files Mounts" \
        "mount, unmount, check status"
    print_action_option "4" "Test Azure Capabilities"
    print_action_option "5" "Validate Resources"
    print_submenu_option "6" "MySQL Database Status" \
        "check server, database, connectivity"
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
            2) handle_provision_menu ;;
            3) handle_mount_menu ;;
            4) test_azure_capabilities_interactive ;;
            5) validate_resources_interactive ;;
            6) handle_mysql_status_menu ;;
            7) run_teardown_interactive ;;
            0) return ;;
            *) ;;
        esac
    done
}

# =============================================================================
# AZURE FILES MOUNT SUBMENU
# =============================================================================

show_mount_menu() {
    show_header "Azure Files Mounts"
    
    print_action_option "1" "Check Mount Status"
    print_action_option "2" "Mount Azure Files"
    print_action_option "3" "Unmount Azure Files"
    echo ""
    print_action_option "0" "Back"
    echo ""
    echo -n "  Select > "
}

handle_mount_menu() {
    while true; do
        show_mount_menu
        read -r choice
        case $choice in
            1) mount_status_check ;;
            2) run_mount_interactive ;;
            3) run_unmount_interactive ;;
            0) return ;;
            *) ;;
        esac
    done
}

mount_status_check() {
    clear
    "$CLI_SCRIPT" mount-status
    echo ""
    echo "Press Enter to continue..."
    read -r
}

# =============================================================================
# PROVISIONING SUBMENU
# =============================================================================

show_provision_menu() {
    show_header "Azure Provisioning"
    
    print_action_option "1" "Check Status (what exists)"
    print_action_option "2" "Full Provisioning (interactive)"
    print_action_option "3" "Full Provisioning (automatic)"
    print_action_option "4" "Retry File Shares Only"
    echo ""
    print_action_option "0" "Back"
    echo ""
    echo -n "  Select > "
}

handle_provision_menu() {
    while true; do
        show_provision_menu
        read -r choice
        case $choice in
            1) provision_status ;;
            2) provision_interactive ;;
            3) provision_automatic ;;
            4) provision_retry_shares ;;
            0) return ;;
            *) ;;
        esac
    done
}

provision_status() {
    clear
    "$CLI_SCRIPT" provision --status
    echo ""
    echo "Press Enter to continue..."
    read -r
}

provision_interactive() {
    clear
    "$CLI_SCRIPT" provision
    echo ""
    echo "Press Enter to continue..."
    read -r
}

provision_automatic() {
    clear
    "$CLI_SCRIPT" provision -y
    echo ""
    echo "Press Enter to continue..."
    read -r
}

provision_retry_shares() {
    clear
    "$CLI_SCRIPT" provision --retry-shares
    echo ""
    echo "Press Enter to continue..."
    read -r
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
    print_submenu_option "5" "Validate Docker" \
        "pre-build, post-build, deployed, all phases"
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
# BUILD CYCLE SUBMENU
# =============================================================================

show_build_menu() {
    show_header "BUILD CYCLE - Local Development"
    show_status_bar
    
    echo -e "  ${BOLD}BUILD STEPS${NC} ${DIM}(execute in order):${NC}"
    echo -e "  ${DIM}───────────────────────────────────────────────────────────────${NC}"
    print_action_option "1" "Validate Environment       ${DIM}Check .env configuration${NC}"
    print_action_option "2" "Azure Provisioning         ${DIM}Create Azure resources${NC}"
    print_action_option "3" "Validate Azure Resources   ${DIM}Verify resources exist${NC}"
    print_action_option "4" "Mount Azure Files          ${DIM}Mount file shares locally${NC}"
    print_action_option "5" "Pre-Build Validation       ${DIM}Check Docker prerequisites${NC}"
    print_action_option "6" "Build Docker Image         ${DIM}Build the SuiteCRM image${NC}"
    print_action_option "7" "Start Container            ${DIM}Start SuiteCRM container${NC}"
    print_action_option "8" "Post-Build Validation      ${DIM}Verify container health${NC}"
    echo -e "  ${DIM}───────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${BOLD}ACTIONS:${NC}"
    print_action_option "a" "Run All Steps (with validation gates)"
    print_action_option "s" "Show Status Summary"
    echo ""
    print_action_option "0" "Back to Main Menu"
    echo ""
    echo -n "  Select > "
}

handle_build_menu() {
    while true; do
        show_build_menu
        read -r choice
        case $choice in
            1) build_step_1_validate_env ;;
            2) build_step_2_provision ;;
            3) build_step_3_validate_azure ;;
            4) build_step_4_mount ;;
            5) build_step_5_pre_validate ;;
            6) build_step_6_build ;;
            7) build_step_7_start ;;
            8) build_step_8_post_validate ;;
            a|A) build_run_all ;;
            s|S) build_show_status ;;
            0) return ;;
            *) ;;
        esac
    done
}

# --- Build Step Functions ---

build_step_1_validate_env() {
    show_header "Step 1 of 8: Validate Environment"
    echo -e "${DIM}Checking .env configuration...${NC}"
    echo ""
    
    "$CLI_SCRIPT" validate-env
    local result=$?
    
    echo ""
    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}✓ Environment validation passed${NC}"
    else
        echo -e "${RED}✗ Environment validation failed${NC}"
    fi
    
    echo ""
    echo "Press Enter to continue..."
    read -r
    return $result
}

build_step_2_provision() {
    show_header "Step 2 of 8: Azure Provisioning"
    echo -e "${DIM}Creating Azure resources (skips existing)...${NC}"
    echo ""
    
    "$CLI_SCRIPT" provision -y
    local result=$?
    
    echo ""
    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}✓ Azure provisioning complete${NC}"
    else
        echo -e "${RED}✗ Azure provisioning failed${NC}"
    fi
    
    echo ""
    echo "Press Enter to continue..."
    read -r
    return $result
}

build_step_3_validate_azure() {
    show_header "Step 3 of 8: Validate Azure Resources"
    echo -e "${DIM}Verifying all Azure resources exist...${NC}"
    echo ""
    
    "$CLI_SCRIPT" validate-resources
    local result=$?
    
    echo ""
    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}✓ All Azure resources validated${NC}"
    else
        echo -e "${RED}✗ Some Azure resources are missing${NC}"
    fi
    
    echo ""
    echo "Press Enter to continue..."
    read -r
    return $result
}

build_step_4_mount() {
    show_header "Step 4 of 8: Mount Azure Files"
    echo -e "${DIM}Mounting Azure file shares locally...${NC}"
    echo -e "${DIM}Script will prompt for sudo password when needed${NC}"
    echo ""
    
    "$CLI_SCRIPT" mount -y
    local result=$?
    
    echo ""
    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}✓ Azure Files mounted${NC}"
    else
        echo -e "${RED}✗ Mount failed${NC}"
    fi
    
    echo ""
    echo "Press Enter to continue..."
    read -r
    return $result
}

build_step_5_pre_validate() {
    show_header "Step 5 of 8: Pre-Build Validation"
    echo -e "${DIM}Checking Docker prerequisites...${NC}"
    echo ""
    
    "$CLI_SCRIPT" docker-validate-pre
    local result=$?
    
    echo ""
    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}✓ Pre-build validation passed${NC}"
    else
        echo -e "${YELLOW}! Pre-build validation has warnings${NC}"
    fi
    
    echo ""
    echo "Press Enter to continue..."
    read -r
    return $result
}

build_step_6_build() {
    show_header "Step 6 of 8: Build Docker Image"
    echo -e "${DIM}Building the SuiteCRM Docker image...${NC}"
    echo ""
    
    "$CLI_SCRIPT" docker-build -y
    local result=$?
    
    echo ""
    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}✓ Docker image built successfully${NC}"
    else
        echo -e "${RED}✗ Docker build failed${NC}"
    fi
    
    echo ""
    echo "Press Enter to continue..."
    read -r
    return $result
}

build_step_7_start() {
    show_header "Step 7 of 8: Start Container"
    echo -e "${DIM}Starting SuiteCRM container...${NC}"
    echo ""
    
    "$CLI_SCRIPT" docker-start -y
    local result=$?
    
    echo ""
    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}✓ Container started${NC}"
        echo ""
        echo "Access SuiteCRM at: ${SUITECRM_SITE_URL:-http://localhost}"
    else
        echo -e "${RED}✗ Container start failed${NC}"
    fi
    
    echo ""
    echo "Press Enter to continue..."
    read -r
    return $result
}

build_step_8_post_validate() {
    show_header "Step 8 of 8: Post-Build Validation"
    echo -e "${DIM}Verifying container health...${NC}"
    echo ""
    
    "$CLI_SCRIPT" docker-validate-post
    local result=$?
    
    echo ""
    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}✓ Post-build validation passed${NC}"
    else
        echo -e "${YELLOW}! Post-build validation has issues${NC}"
    fi
    
    echo ""
    echo "Press Enter to continue..."
    read -r
    return $result
}

# --- Build Run All ---

build_run_all() {
    show_header "Run All Build Steps"
    
    echo -e "${YELLOW}This will execute all 8 build steps in sequence:${NC}"
    echo ""
    echo "  1. Validate Environment"
    echo "  2. Azure Provisioning"
    echo "  3. Validate Azure Resources"
    echo "  4. Mount Azure Files"
    echo "  5. Pre-Build Validation"
    echo "  6. Build Docker Image"
    echo "  7. Start Container"
    echo "  8. Post-Build Validation"
    echo ""
    echo -e "${DIM}The process stops on first failure.${NC}"
    echo ""
    echo -n "  Continue? (y/n): "
    read -r confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}Cancelled.${NC}"
        echo ""
        echo "Press Enter to continue..."
        read -r
        return
    fi
    
    local total=8
    local failed_step=0
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Step 1: Validate Environment
    echo ""
    echo -e "${CYAN}━━━ Step 1 of $total: Validate Environment ━━━${NC}"
    echo ""
    if ! "$CLI_SCRIPT" validate-env --errors-only; then
        echo -e "${RED}✗ Environment validation failed${NC}"
        failed_step=1
    else
        echo -e "${GREEN}✓ Environment validation passed${NC}"
    fi
    
    # Step 2: Azure Provisioning
    if [[ $failed_step -eq 0 ]]; then
        echo ""
        echo -e "${CYAN}━━━ Step 2 of $total: Azure Provisioning ━━━${NC}"
        echo ""
        if ! "$CLI_SCRIPT" provision -y; then
            echo -e "${RED}✗ Azure provisioning failed${NC}"
            failed_step=2
        else
            echo -e "${GREEN}✓ Azure provisioning complete${NC}"
        fi
    fi
    
    # Step 3: Validate Azure Resources
    if [[ $failed_step -eq 0 ]]; then
        echo ""
        echo -e "${CYAN}━━━ Step 3 of $total: Validate Azure Resources ━━━${NC}"
        echo ""
        if ! "$CLI_SCRIPT" validate-resources; then
            echo -e "${RED}✗ Azure resource validation failed${NC}"
            failed_step=3
        else
            echo -e "${GREEN}✓ Azure resources validated${NC}"
        fi
    fi
    
    # Step 4: Mount Azure Files
    if [[ $failed_step -eq 0 ]]; then
        echo ""
        echo -e "${CYAN}━━━ Step 4 of $total: Mount Azure Files ━━━${NC}"
        echo ""
        if ! "$CLI_SCRIPT" mount -y; then
            echo -e "${RED}✗ Mount failed${NC}"
            failed_step=4
        else
            echo -e "${GREEN}✓ Azure Files mounted${NC}"
        fi
    fi
    
    # Step 5: Pre-Build Validation
    if [[ $failed_step -eq 0 ]]; then
        echo ""
        echo -e "${CYAN}━━━ Step 5 of $total: Pre-Build Validation ━━━${NC}"
        echo ""
        # Pre-build validation warnings don't stop the build
        "$CLI_SCRIPT" docker-validate-pre
        echo -e "${GREEN}✓ Pre-build validation complete${NC}"
    fi
    
    # Step 6: Build Docker Image
    if [[ $failed_step -eq 0 ]]; then
        echo ""
        echo -e "${CYAN}━━━ Step 6 of $total: Build Docker Image ━━━${NC}"
        echo ""
        if ! "$CLI_SCRIPT" docker-build -y; then
            echo -e "${RED}✗ Docker build failed${NC}"
            failed_step=6
        else
            echo -e "${GREEN}✓ Docker image built${NC}"
        fi
    fi
    
    # Step 7: Start Container
    if [[ $failed_step -eq 0 ]]; then
        echo ""
        echo -e "${CYAN}━━━ Step 7 of $total: Start Container ━━━${NC}"
        echo ""
        if ! "$CLI_SCRIPT" docker-start -y; then
            echo -e "${RED}✗ Container start failed${NC}"
            failed_step=7
        else
            echo -e "${GREEN}✓ Container started${NC}"
        fi
    fi
    
    # Step 8: Post-Build Validation
    if [[ $failed_step -eq 0 ]]; then
        echo ""
        echo -e "${CYAN}━━━ Step 8 of $total: Post-Build Validation ━━━${NC}"
        echo ""
        "$CLI_SCRIPT" docker-validate-post
        echo -e "${GREEN}✓ Post-build validation complete${NC}"
    fi
    
    # Summary
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [[ $failed_step -eq 0 ]]; then
        echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}   BUILD CYCLE COMPLETE - All 8 steps passed${NC}"
        echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "Access SuiteCRM at: ${SUITECRM_SITE_URL:-http://localhost}"
    else
        echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
        echo -e "${RED}   BUILD STOPPED at Step $failed_step${NC}"
        echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${DIM}Fix the issue and resume from step $failed_step.${NC}"
    fi
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

# --- Build Status Summary ---

build_show_status() {
    show_header "Build Cycle Status Summary"
    
    echo -e "  ${BOLD}Checking status of each build step...${NC}"
    echo ""
    
    local env_status="${RED}✗${NC}"
    local azure_status="${RED}✗${NC}"
    local mount_status="${RED}✗${NC}"
    local image_status="${RED}✗${NC}"
    local container_status="${RED}✗${NC}"
    
    # Check environment
    if "$SCRIPT_DIR/env-validate.sh" --quiet 2>/dev/null; then
        env_status="${GREEN}✓${NC}"
    fi
    
    # Check Azure resources (if logged in)
    if az account show &>/dev/null; then
        # Run azure-validate-resources.sh and check exit code (suppress output)
        if "$SCRIPT_DIR/azure-validate-resources.sh" &>/dev/null; then
            azure_status="${GREEN}✓${NC}"
        else
            azure_status="${YELLOW}◑${NC}"
        fi
    else
        azure_status="${DIM}○${NC} ${DIM}(not logged in)${NC}"
    fi
    
    # Check mounts
    local mount_base="${AZURE_FILES_MOUNT_BASE:-/mnt/azure/suitecrm}"
    if mountpoint -q "$mount_base/${AZURE_FILES_SHARE_UPLOAD:-upload}" 2>/dev/null; then
        mount_status="${GREEN}✓${NC}"
    fi
    
    # Check Docker image
    local image_name="${DOCKER_IMAGE_NAME:-buzzmag-suitecrm}"
    if docker image inspect "$image_name" &>/dev/null; then
        image_status="${GREEN}✓${NC}"
    fi
    
    # Check container
    local container_name="${DOCKER_CONTAINER_NAME:-suitecrm-web}"
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container_name}$"; then
        container_status="${GREEN}✓${NC}"
    elif docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${container_name}$"; then
        container_status="${YELLOW}◑${NC} ${DIM}(stopped)${NC}"
    fi
    
    echo -e "  ${DIM}───────────────────────────────────────────────────────────────${NC}"
    printf "  %-4s %-30s %s\n" "Step" "Component" "Status"
    echo -e "  ${DIM}───────────────────────────────────────────────────────────────${NC}"
    printf "  %-4s %-30s %b\n" "1" "Environment (.env)" "$env_status"
    printf "  %-4s %-30s %b\n" "2-3" "Azure Resources" "$azure_status"
    printf "  %-4s %-30s %b\n" "4" "Azure Files Mounts" "$mount_status"
    printf "  %-4s %-30s %b\n" "5-6" "Docker Image" "$image_status"
    printf "  %-4s %-30s %b\n" "7-8" "Container Running" "$container_status"
    echo -e "  ${DIM}───────────────────────────────────────────────────────────────${NC}"
    echo ""
    
    # Recommendations
    echo -e "  ${BOLD}Recommendations:${NC}"
    echo ""
    
    if [[ "$env_status" == *"✗"* ]]; then
        echo -e "  ${YELLOW}→${NC} Run Step 1: Validate Environment"
    elif [[ "$azure_status" == *"✗"* ]] || [[ "$azure_status" == *"◑"* ]]; then
        echo -e "  ${YELLOW}→${NC} Run Steps 2-3: Azure Provisioning & Validation"
    elif [[ "$mount_status" == *"✗"* ]]; then
        echo -e "  ${YELLOW}→${NC} Run Step 4: Mount Azure Files"
    elif [[ "$image_status" == *"✗"* ]]; then
        echo -e "  ${YELLOW}→${NC} Run Step 6: Build Docker Image"
    elif [[ "$container_status" == *"✗"* ]]; then
        echo -e "  ${YELLOW}→${NC} Run Step 7: Start Container"
    elif [[ "$container_status" == *"◑"* ]]; then
        echo -e "  ${YELLOW}→${NC} Container is stopped. Run Step 7 to start."
    else
        echo -e "  ${GREEN}✓${NC} All components ready. SuiteCRM should be accessible."
    fi
    
    echo ""
    echo "Press Enter to continue..."
    read -r
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

# =============================================================================
# MYSQL STATUS SUBMENU
# =============================================================================

show_mysql_status_menu() {
    show_header "Azure MySQL Database Status"
    
    print_action_option "1" "Full Status Check"
    print_action_option "2" "Quick Check (server only)"
    print_action_option "3" "Connection Test"
    echo ""
    print_action_option "0" "Back"
    echo ""
    echo -n "  Select > "
}

handle_mysql_status_menu() {
    while true; do
        show_mysql_status_menu
        read -r choice
        case $choice in
            1) mysql_status_full ;;
            2) mysql_status_quick ;;
            3) mysql_status_connect ;;
            0) return ;;
            *) ;;
        esac
    done
}

mysql_status_full() {
    clear
    "$CLI_SCRIPT" mysql-status
    echo ""
    echo "Press Enter to continue..."
    read -r
}

mysql_status_quick() {
    clear
    "$CLI_SCRIPT" mysql-status --quick
    echo ""
    echo "Press Enter to continue..."
    read -r
}

mysql_status_connect() {
    clear
    "$CLI_SCRIPT" mysql-status --connect
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


run_mount_interactive() {
    show_header "Mount Azure Files"
    
    echo -e "${DIM}Script will prompt for sudo password when needed${NC}"
    echo ""
    
    "$CLI_SCRIPT" mount
    
    echo ""
    echo "Press Enter to continue..."
    read -r
}

run_unmount_interactive() {
    show_header "Unmount Azure Files"
    
    echo -e "${DIM}Script will prompt for sudo password when needed${NC}"
    echo ""
    
    "$CLI_SCRIPT" unmount
    
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
    while true; do
        show_header "Docker Validation"
        
        echo -e "  ${YELLOW}Select validation type:${NC}"
        echo ""
        print_action_option "1" "Quick Status Check (image, container, mounts)"
        print_action_option "2" "Pre-Build Validation (prerequisites)"
        print_action_option "3" "Post-Build Validation (container health)"
        print_action_option "4" "Deployed Validation (Azure resources)"
        print_action_option "5" "Full Validation (all phases)"
        echo ""
        print_action_option "0" "Back"
        echo ""
        echo -n "  Select > "
        read -r val_choice
        
        case $val_choice in
            1) 
                show_header "Docker Quick Status"
                "$CLI_SCRIPT" docker-validate
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            2)
                show_header "Pre-Build Validation"
                "$CLI_SCRIPT" docker-validate-pre
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            3)
                show_header "Post-Build Validation"
                "$CLI_SCRIPT" docker-validate-post
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            4)
                show_header "Azure Deployment Validation"
                "$CLI_SCRIPT" docker-validate-deployed
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            5)
                show_header "Full Lifecycle Validation"
                "$CLI_SCRIPT" docker-validate-all
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            0) return ;;
            *) ;;
        esac
    done
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
    echo "Access SuiteCRM at: ${SUITECRM_SITE_URL:-http://localhost}"
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
    echo "Access at: ${SUITECRM_SITE_URL:-http://localhost}"
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
    echo "Access at: ${SUITECRM_SITE_URL:-http://localhost}"
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
        6) handle_quick_menu ;;
        b|B) handle_build_menu ;;
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

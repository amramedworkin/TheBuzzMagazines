#!/bin/bash
# ============================================================================
# Azure Capability & Permission Test Script
# ============================================================================
# Tests Azure CLI permissions by creating and deleting temporary resources.
# 
# NOTE: This script intentionally uses EPHEMERAL resource names (with timestamps)
# rather than .env values because:
#   1. It creates temporary test resources, not production resources
#   2. Unique names prevent conflicts with existing resources
#   3. Resources are destroyed at the end of the test
#
# Configuration values (location, subscription) ARE read from .env
# ============================================================================

# ============================================================================
# SCRIPT CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

RESULTS=()

log_step() { echo -e "\n${BLUE}[STEP]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; RESULTS+=("${GREEN}✔${NC} $1"); }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; RESULTS+=("${RED}✘${NC} $1"); }
log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

# ============================================================================
# LOAD ENVIRONMENT (for configuration values)
# ============================================================================

load_env() {
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "Missing .env file at $ENV_FILE"
        exit 1
    fi
    
    set -a
    source "$ENV_FILE"
    set +a
    
    # Use location from .env, fallback to default
    TEST_LOCATION="${AZURE_LOCATION:-southcentralus}"
}

# ============================================================================
# MAIN
# ============================================================================

echo ""
echo "============================================================================"
echo "Azure Capability & Permission Test"
echo "============================================================================"
echo ""

# 1. Check Azure CLI login
log_step "Checking Azure Authentication..."
if ! az account show &>/dev/null; then
    log_error "Not logged in. Run 'az login' first."
    exit 1
fi
log_success "Authenticated to Azure"

# 2. Load configuration from .env
load_env

# 3. Generate ephemeral resource names (unique per test run)
TIMESTAMP=$(date +%s)
TEST_PREFIX="${AZURE_RESOURCE_PREFIX:-test}"
RAW_STORAGE_NAME="${TEST_PREFIX}captest${TIMESTAMP}"
TEST_STORAGE="${RAW_STORAGE_NAME:0:24}"  # Storage names max 24 chars
TEST_RG="rg-capability-test-${TIMESTAMP}"

log_info "Test Resource Group: $TEST_RG"
log_info "Test Storage Account: $TEST_STORAGE"
log_info "Test Location: $TEST_LOCATION"

# 4. Test Resource Group Creation
log_step "Testing Resource Group Creation..."
if az group create --name "$TEST_RG" --location "$TEST_LOCATION" --output none; then
    log_success "Resource Group creation: PASSED"
else
    log_error "Resource Group creation: FAILED"
    exit 1
fi

# 5. Test Storage Account Creation
log_step "Testing Storage Account Creation..."
log_info "This may take 1-2 minutes..."
if az storage account create \
    --name "$TEST_STORAGE" \
    --resource-group "$TEST_RG" \
    --location "$TEST_LOCATION" \
    --sku Standard_LRS \
    --output none; then
    log_success "Storage Account creation: PASSED"
else
    log_error "Storage Account creation: FAILED"
fi

# 6. Cleanup Test Resources
log_step "Cleaning Up Test Resources..."
log_info "This may take 2-3 minutes..."
if az group delete --name "$TEST_RG" --yes; then
    log_success "Resource cleanup: PASSED"
else
    log_error "Resource cleanup: FAILED"
fi

# 7. Summary
echo ""
echo "============================================================================"
echo "                    CAPABILITY TEST RESULTS"
echo "============================================================================"
for res in "${RESULTS[@]}"; do
    echo -e "  $res"
done
echo "============================================================================"
echo ""
echo "If all tests passed, you have sufficient permissions to run:"
echo "  ./scripts/azure-provision-infra.sh"
echo ""

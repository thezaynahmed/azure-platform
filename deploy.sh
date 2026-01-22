#!/bin/bash
# =============================================================================
# Azure Multi-VNet Infrastructure Deployment Script
# This script deploys the Bicep template at subscription level with multiple RGs
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Default values
LOCATION="centralus"
ENVIRONMENT="prod"
COMPANY_PREFIX="tmb"
ADMIN_USERNAME="azureadmin"
ADMIN_PASSWORD=""
SSH_PUBLIC_KEY=""
VM_SIZE="Standard_B2s"
ADMIN_PUBLIC_IP=""

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Required Options:"
    echo "  -p, --admin-password    Admin password for Windows VMs"
    echo "  -k, --ssh-key          SSH public key for Linux VMs"
    echo ""
    echo "Optional Options:"
    echo "  -l, --location         Azure region (default: centralus)"
    echo "  -e, --environment      Environment (dev/test/prod, default: prod)"
    echo "  -c, --company-prefix   Company prefix (default: tmb)"
    echo "  -u, --admin-username   Admin username (default: azureadmin)"
    echo "  -s, --vm-size          VM size (default: Standard_B2s)"
    echo "  -a, --admin-public-ip  Admin public IP for RDP access (optional)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Note: This deployment creates multiple resource groups automatically:"
    echo "  - rg-{company}-{env}-shared-{location} (shared resources)"
    echo "  - rg-{company}-{env}-vneta-{location} (VNet A infrastructure)"
    echo "  - rg-{company}-{env}-vnetb-{location} (VNet B infrastructure)"
    echo ""
    echo "Examples:"
    echo "  Basic deployment (management server with private IP only):"
    echo "    $0 -p 'MySecurePassword123!' -k 'ssh-rsa AAAAB3NzaC1yc2E...'"
    echo ""
    echo "  With public IP access for management server:"
    echo "    $0 -p 'MySecurePassword123!' -k 'ssh-rsa AAAAB3NzaC1yc2E...' -a '203.0.113.1'"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -c|--company-prefix)
            COMPANY_PREFIX="$2"
            shift 2
            ;;
        -u|--admin-username)
            ADMIN_USERNAME="$2"
            shift 2
            ;;
        -p|--admin-password)
            ADMIN_PASSWORD="$2"
            shift 2
            ;;
        -k|--ssh-key)
            SSH_PUBLIC_KEY="$2"
            shift 2
            ;;
        -s|--vm-size)
            VM_SIZE="$2"
            shift 2
            ;;
        -a|--admin-public-ip)
            ADMIN_PUBLIC_IP="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required parameters

if [[ -z "$ADMIN_PASSWORD" ]]; then
    print_error "Admin password is required"
    show_usage
    exit 1
fi

if [[ -z "$SSH_PUBLIC_KEY" ]]; then
    print_error "SSH public key is required"
    show_usage
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|test|prod)$ ]]; then
    print_error "Environment must be one of: dev, test, prod"
    exit 1
fi

print_status "Starting Azure multi-VNet infrastructure deployment..."
print_status "Location: $LOCATION"
print_status "Environment: $ENVIRONMENT"
print_status "Company Prefix: $COMPANY_PREFIX"
print_status "Admin Username: $ADMIN_USERNAME"
print_status "VM Size: $VM_SIZE"

# Resource group names that will be created
RG_SHARED="rg-${COMPANY_PREFIX}-${ENVIRONMENT}-shared-${LOCATION}"
RG_VNETA="rg-${COMPANY_PREFIX}-${ENVIRONMENT}-vneta-${LOCATION}"
RG_VNETB="rg-${COMPANY_PREFIX}-${ENVIRONMENT}-vnetb-${LOCATION}"

print_status "Resource groups to be created:"
print_status "  Shared: $RG_SHARED"
print_status "  VNet A: $RG_VNETA"
print_status "  VNet B: $RG_VNETB"

# Check if Azure CLI is installed and user is logged in
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it first."
    exit 1
fi

if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

# Get current subscription info
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
print_status "Deploying to subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

# Validate the Bicep template at subscription scope
print_status "Validating Bicep template at subscription scope..."
if ! az deployment sub validate \
    --location "$LOCATION" \
    --template-file main.bicep \
    --parameters environment="$ENVIRONMENT" \
    --parameters location="$LOCATION" \
    --parameters companyPrefix="$COMPANY_PREFIX" \
    --parameters adminUsername="$ADMIN_USERNAME" \
    --parameters adminPassword="$ADMIN_PASSWORD" \
    --parameters sshPublicKey="$SSH_PUBLIC_KEY" \
    --parameters vmSize="$VM_SIZE" \
    --parameters adminPublicIPAddress="$ADMIN_PUBLIC_IP" \
    --output none; then
    print_error "Template validation failed"
    exit 1
fi

print_status "Template validation successful!"

# Deploy the infrastructure at subscription scope
print_status "Deploying infrastructure... This may take 20-30 minutes."
DEPLOYMENT_NAME="azure-multi-vnet-infra-$(date +%Y%m%d-%H%M%S)"

az deployment sub create \
    --location "$LOCATION" \
    --name "$DEPLOYMENT_NAME" \
    --template-file main.bicep \
    --parameters environment="$ENVIRONMENT" \
    --parameters location="$LOCATION" \
    --parameters companyPrefix="$COMPANY_PREFIX" \
    --parameters adminUsername="$ADMIN_USERNAME" \
    --parameters adminPassword="$ADMIN_PASSWORD" \
    --parameters sshPublicKey="$SSH_PUBLIC_KEY" \
    --parameters vmSize="$VM_SIZE" \
    --parameters adminPublicIPAddress="$ADMIN_PUBLIC_IP"

if [[ $? -eq 0 ]]; then
    print_status "Deployment completed successfully!"
    print_status "Deployment name: $DEPLOYMENT_NAME"

    # Get deployment outputs
    print_status "Retrieving deployment outputs..."
    az deployment sub show \
        --name "$DEPLOYMENT_NAME" \
        --query properties.outputs \
        --output yaml

    print_status ""
    print_status "Deployment Summary:"
    print_status "==================="
    print_status "✅ Created 3 resource groups with proper tagging"
    print_status "✅ Deployed VNet A (10.0.0.0/24) with Management, AD, and Automation subnets"
    print_status "✅ Deployed VNet B (10.1.0.0/24) with Windows and Linux application subnets"
    print_status "✅ Established bidirectional VNet peering between VNet A and VNet B"
    print_status "✅ Deployed VMs with Azure naming conventions"
    print_status "✅ Configured NSGs with appropriate security rules"
    print_status "✅ Set up shared storage account for boot diagnostics"
    print_status ""
    print_status "Next steps:"
    print_status "- VMs are accessible via RDP (Windows) and SSH (Linux)"
    print_status "- Configure domain controllers on AD subnet VMs"
    print_status "- Review and adjust NSG rules as needed"
    print_status "- Set up monitoring and alerting in Azure Monitor"
else
    print_error "Deployment failed"
    exit 1
fi
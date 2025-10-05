#!/bin/bash

# =============================================================================
# Enterprise Azure Deployment Script for eShop Legacy MVC
# =============================================================================

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
RESOURCE_GROUP_NAME="rg-eshop-enterprise"
LOCATION="East US"
SUBSCRIPTION_ID=""
DEPLOYMENT_NAME="eshop-enterprise-$(date +%Y%m%d-%H%M%S)"

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Deploy eShop Legacy MVC to Azure with enterprise-grade infrastructure"
    echo ""
    echo "Options:"
    echo "  -g, --resource-group    Resource group name (default: $RESOURCE_GROUP_NAME)"
    echo "  -l, --location          Azure region (default: $LOCATION)"
    echo "  -s, --subscription      Azure subscription ID"
    echo "  -e, --environment       Environment name (dev/staging/prod, default: dev)"
    echo "  -p, --prefix            Resource name prefix (default: eshop)"
    echo "  --validate-only         Only validate the template without deploying"
    echo "  --what-if               Show what changes would be made"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -s your-subscription-id"
    echo "  $0 -g rg-eshop-prod -e prod --validate-only"
    echo "  $0 --what-if"
}

# Parse command line arguments
ENVIRONMENT="dev"
PREFIX="eshop"
VALIDATE_ONLY=false
WHAT_IF=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP_NAME="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -s|--subscription)
            SUBSCRIPTION_ID="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -p|--prefix)
            PREFIX="$2"
            shift 2
            ;;
        --validate-only)
            VALIDATE_ONLY=true
            shift
            ;;
        --what-if)
            WHAT_IF=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$SUBSCRIPTION_ID" ]]; then
    print_error "Subscription ID is required. Use -s or --subscription"
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_error "Environment must be dev, staging, or prod"
    exit 1
fi

print_status "Starting eShop Enterprise deployment..."
print_status "Resource Group: $RESOURCE_GROUP_NAME"
print_status "Location: $LOCATION"
print_status "Environment: $ENVIRONMENT"
print_status "Subscription: $SUBSCRIPTION_ID"

# Check Azure CLI installation
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it first."
    exit 1
fi

# Login check
print_status "Checking Azure CLI authentication..."
if ! az account show &> /dev/null; then
    print_warning "Not logged in to Azure CLI. Please login first."
    az login
fi

# Set subscription
print_status "Setting Azure subscription..."
az account set --subscription "$SUBSCRIPTION_ID"

# Get current user information for Entra ID admin assignment
print_status "Getting current user information..."
CURRENT_USER=$(az ad signed-in-user show --query '{objectId:id, userPrincipalName:userPrincipalName}' -o tsv)
CURRENT_USER_OBJECT_ID=$(echo "$CURRENT_USER" | cut -f1)
CURRENT_USER_UPN=$(echo "$CURRENT_USER" | cut -f2)

print_status "Current User Object ID: $CURRENT_USER_OBJECT_ID"
print_status "Current User UPN: $CURRENT_USER_UPN"

# Create resource group
print_status "Creating resource group..."
az group create \
    --name "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --output table

# Update parameters file with current values
print_status "Updating deployment parameters..."
PARAMS_FILE="main.parameters.json"
cat > "$PARAMS_FILE" << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environmentName": {
      "value": "$ENVIRONMENT"
    },
    "location": {
      "value": "$LOCATION"
    },
    "namePrefix": {
      "value": "$PREFIX"
    },
    "sqlAdminUsername": {
      "value": "eshopadmin"
    },
    "currentUserObjectId": {
      "value": "$CURRENT_USER_OBJECT_ID"
    },
    "currentUserPrincipalName": {
      "value": "$CURRENT_USER_UPN"
    },
    "enableMonitoring": {
      "value": true
    },
    "appServicePlanSku": {
      "value": "B2"
    },
    "sqlDatabaseTier": {
      "value": "Standard"
    },
    "sqlDatabaseSize": {
      "value": "S1"
    }
  }
}
EOF

# Validate template
print_status "Validating Bicep template..."
az deployment group validate \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file "main.bicep" \
    --parameters "@$PARAMS_FILE" \
    --output table

if [[ $? -ne 0 ]]; then
    print_error "Template validation failed!"
    exit 1
fi

print_success "Template validation successful!"

# What-if analysis
if [[ "$WHAT_IF" == true ]]; then
    print_status "Running what-if analysis..."
    az deployment group what-if \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --template-file "main.bicep" \
        --parameters "@$PARAMS_FILE"
    exit 0
fi

# Exit if validate-only flag is set
if [[ "$VALIDATE_ONLY" == true ]]; then
    print_success "Validation completed successfully!"
    exit 0
fi

# Deploy template
print_status "Starting deployment..."
az deployment group create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file "main.bicep" \
    --parameters "@$PARAMS_FILE" \
    --name "$DEPLOYMENT_NAME" \
    --output table

if [[ $? -ne 0 ]]; then
    print_error "Deployment failed!"
    exit 1
fi

# Get deployment outputs
print_status "Getting deployment outputs..."
OUTPUTS=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$DEPLOYMENT_NAME" \
    --query 'properties.outputs' \
    --output json)

print_success "Deployment completed successfully!"
print_status "Deployment outputs:"
echo "$OUTPUTS" | jq '.'

# Extract key information
APP_SERVICE_URL=$(echo "$OUTPUTS" | jq -r '.appServiceUrl.value // empty')
KEY_VAULT_NAME=$(echo "$OUTPUTS" | jq -r '.keyVaultName.value // empty')
SQL_SERVER_NAME=$(echo "$OUTPUTS" | jq -r '.sqlServerName.value // empty')

if [[ -n "$APP_SERVICE_URL" ]]; then
    print_success "Application URL: $APP_SERVICE_URL"
fi

if [[ -n "$KEY_VAULT_NAME" ]]; then
    print_success "Key Vault: $KEY_VAULT_NAME"
fi

if [[ -n "$SQL_SERVER_NAME" ]]; then
    print_success "SQL Server: $SQL_SERVER_NAME"
fi

print_status "Next steps:"
echo "1. Configure your application code to use managed identity for database connections"
echo "2. Update your CI/CD pipeline to deploy to the new App Service"
echo "3. Configure custom domains and SSL certificates if needed"
echo "4. Set up monitoring alerts in Application Insights"
echo "5. Review and configure backup policies"

print_success "Enterprise deployment completed!"
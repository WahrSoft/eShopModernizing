#!/bin/bash

# Enterprise eShop Legacy MVC Deployment Script
# This script deploys the complete infrastructure to Azure

set -e  # Exit on any error

# Configuration
RESOURCE_GROUP_DEV="rg-eshop-dev"
RESOURCE_GROUP_PROD="rg-eshop-prod"
LOCATION="East US 2"
TEMPLATE_FILE="infra/main.enterprise.bicep"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if user is logged in
    if ! az account show &> /dev/null; then
        log_error "You are not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    # Check if bicep is available
    if ! az bicep version &> /dev/null; then
        log_info "Installing Bicep CLI..."
        az bicep install
    fi
    
    log_success "Prerequisites check completed"
}

get_user_info() {
    log_info "Getting user information..."
    
    USER_OBJECT_ID=$(az ad signed-in-user show --query id --output tsv)
    USER_UPN=$(az ad signed-in-user show --query userPrincipalName --output tsv)
    
    if [[ -z "$USER_OBJECT_ID" || -z "$USER_UPN" ]]; then
        log_error "Failed to get user information"
        exit 1
    fi
    
    log_success "User info: $USER_UPN ($USER_OBJECT_ID)"
}

update_parameters() {
    local env=$1
    local param_file="infra/main.${env}.parameters.enterprise.json"
    
    log_info "Updating parameters file: $param_file"
    
    # Create a backup
    cp "$param_file" "${param_file}.backup"
    
    # Update the parameters file with actual user info
    sed -i.tmp "s/REPLACE_WITH_YOUR_OBJECT_ID/$USER_OBJECT_ID/g" "$param_file"
    sed -i.tmp "s/REPLACE_WITH_YOUR_UPN/$USER_UPN/g" "$param_file"
    rm "${param_file}.tmp"
    
    log_success "Parameters file updated"
}

create_resource_group() {
    local rg_name=$1
    
    log_info "Creating resource group: $rg_name"
    
    if az group show --name "$rg_name" &> /dev/null; then
        log_warning "Resource group $rg_name already exists"
    else
        az group create --name "$rg_name" --location "$LOCATION" --tags Environment="$ENVIRONMENT" Purpose="eShop Legacy MVC"
        log_success "Resource group $rg_name created"
    fi
}

validate_deployment() {
    local rg_name=$1
    local param_file=$2
    
    log_info "Validating deployment..."
    
    if az deployment group validate \
        --resource-group "$rg_name" \
        --template-file "$TEMPLATE_FILE" \
        --parameters "$param_file" \
        --parameters currentUserObjectId="$USER_OBJECT_ID" \
        --parameters currentUserPrincipalName="$USER_UPN" \
        --output table; then
        log_success "Template validation passed"
    else
        log_error "Template validation failed"
        exit 1
    fi
}

preview_deployment() {
    local rg_name=$1
    local param_file=$2
    
    log_info "Previewing deployment changes..."
    
    az deployment group what-if \
        --resource-group "$rg_name" \
        --template-file "$TEMPLATE_FILE" \
        --parameters "$param_file" \
        --parameters currentUserObjectId="$USER_OBJECT_ID" \
        --parameters currentUserPrincipalName="$USER_UPN"
}

deploy_infrastructure() {
    local rg_name=$1
    local param_file=$2
    
    log_info "Deploying infrastructure to $rg_name..."
    
    local deployment_name="eshop-infrastructure-$(date +%Y%m%d-%H%M%S)"
    
    if az deployment group create \
        --resource-group "$rg_name" \
        --template-file "$TEMPLATE_FILE" \
        --parameters "$param_file" \
        --parameters currentUserObjectId="$USER_OBJECT_ID" \
        --parameters currentUserPrincipalName="$USER_UPN" \
        --name "$deployment_name" \
        --output table; then
        log_success "Infrastructure deployment completed successfully"
        
        # Get deployment outputs
        log_info "Deployment outputs:"
        az deployment group show \
            --resource-group "$rg_name" \
            --name "$deployment_name" \
            --query 'properties.outputs' \
            --output table
    else
        log_error "Infrastructure deployment failed"
        exit 1
    fi
}

# Main script
main() {
    echo "=============================================="
    echo "eShop Legacy MVC - Enterprise Infrastructure"
    echo "=============================================="
    echo
    
    # Parse command line arguments
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 [dev|prod] [--validate-only] [--preview-only]"
        echo "  dev          Deploy to development environment"
        echo "  prod         Deploy to production environment"
        echo "  --validate-only    Only validate the template"
        echo "  --preview-only     Only preview the changes"
        exit 1
    fi
    
    ENVIRONMENT=$1
    VALIDATE_ONLY=false
    PREVIEW_ONLY=false
    
    # Parse additional flags
    for arg in "$@"; do
        case $arg in
            --validate-only)
                VALIDATE_ONLY=true
                ;;
            --preview-only)
                PREVIEW_ONLY=true
                ;;
        esac
    done
    
    # Set environment-specific variables
    case $ENVIRONMENT in
        dev)
            RESOURCE_GROUP=$RESOURCE_GROUP_DEV
            PARAM_FILE="infra/main.dev.parameters.enterprise.json"
            ;;
        prod)
            RESOURCE_GROUP=$RESOURCE_GROUP_PROD
            PARAM_FILE="infra/main.prod.parameters.enterprise.json"
            ;;
        *)
            log_error "Invalid environment: $ENVIRONMENT. Use 'dev' or 'prod'"
            exit 1
            ;;
    esac
    
    log_info "Environment: $ENVIRONMENT"
    log_info "Resource Group: $RESOURCE_GROUP"
    log_info "Parameter File: $PARAM_FILE"
    echo
    
    # Execute deployment steps
    check_prerequisites
    get_user_info
    update_parameters "$ENVIRONMENT"
    create_resource_group "$RESOURCE_GROUP"
    validate_deployment "$RESOURCE_GROUP" "$PARAM_FILE"
    
    if [[ "$VALIDATE_ONLY" == true ]]; then
        log_success "Validation completed successfully"
        exit 0
    fi
    
    preview_deployment "$RESOURCE_GROUP" "$PARAM_FILE"
    
    if [[ "$PREVIEW_ONLY" == true ]]; then
        log_success "Preview completed successfully"
        exit 0
    fi
    
    # Confirmation for production
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        echo
        log_warning "You are about to deploy to PRODUCTION environment!"
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deployment cancelled"
            exit 0
        fi
    fi
    
    deploy_infrastructure "$RESOURCE_GROUP" "$PARAM_FILE"
    
    log_success "Deployment completed successfully!"
    echo
    log_info "Next steps:"
    echo "1. Configure your application settings"
    echo "2. Deploy your application code"
    echo "3. Test the deployment"
}

# Run main function with all arguments
main "$@"
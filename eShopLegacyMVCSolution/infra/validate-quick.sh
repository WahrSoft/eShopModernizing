#!/bin/bash

# Quick Deployment Validation Script
# This script validates the Bicep templates and helps identify issues before deployment

set -e

echo "=== Azure Infrastructure Deployment Validation ==="
echo ""

# Check if user is logged in to Azure
if ! az account show &> /dev/null; then
    echo "? Error: Please login to Azure first with 'az login'"
    exit 1
fi

# Get user information
USER_OBJECT_ID=$(az ad signed-in-user show --query id --output tsv)
USER_UPN=$(az ad signed-in-user show --query userPrincipalName --output tsv)
SUBSCRIPTION_ID=$(az account show --query id --output tsv)

echo "? Azure Login: OK"
echo "   User: $USER_UPN"
echo "   Subscription: $SUBSCRIPTION_ID"
echo ""

# Set variables
RESOURCE_GROUP_DEV="rg-eshop-dev"
RESOURCE_GROUP_PROD="rg-eshop-prod"
LOCATION="East US 2"

# Function to validate a template
validate_template() {
    local template=$1
    local parameters=$2
    local resource_group=$3
    local mode=$4
    
    echo "Validating $mode template: $template"
    
    # Create resource group if it doesn't exist
    if ! az group show --name "$resource_group" &> /dev/null; then
        echo "  Creating resource group: $resource_group"
        az group create --name "$resource_group" --location "$LOCATION" --tags Environment="${mode}" Purpose="eShop Legacy MVC" > /dev/null
    fi
    
    # Validate template
    if [[ "$template" == *"simple"* ]]; then
        validation_result=$(az deployment group validate \
            --resource-group "$resource_group" \
            --template-file "$template" \
            --parameters "$parameters" \
            --parameters currentUserObjectId="$USER_OBJECT_ID" \
            --query "error" \
            --output json 2>&1)
    else
        validation_result=$(az deployment group validate \
            --resource-group "$resource_group" \
            --template-file "$template" \
            --parameters "$parameters" \
            --parameters currentUserObjectId="$USER_OBJECT_ID" \
            --parameters currentUserPrincipalName="$USER_UPN" \
            --query "error" \
            --output json 2>&1)
    fi
    
    if [[ "$validation_result" == "null" ]]; then
        echo "  ? Validation: PASSED"
        return 0
    else
        echo "  ? Validation: FAILED"
        echo "  Error: $validation_result"
        return 1
    fi
}

# Test enterprise templates
echo "=== Testing Enterprise Templates ==="
echo ""

if validate_template "infra/main.enterprise.bicep" "infra/main.dev.parameters.enterprise.json" "$RESOURCE_GROUP_DEV" "dev"; then
    ENTERPRISE_DEV_OK=true
else
    ENTERPRISE_DEV_OK=false
fi

if validate_template "infra/main.enterprise.bicep" "infra/main.prod.parameters.enterprise.json" "$RESOURCE_GROUP_PROD" "prod"; then
    ENTERPRISE_PROD_OK=true
else
    ENTERPRISE_PROD_OK=false
fi

echo ""

# Test simplified templates
echo "=== Testing Simplified Templates ==="
echo ""

if validate_template "infra/main.simple.bicep" "infra/main.dev.parameters.simple.json" "$RESOURCE_GROUP_DEV" "dev"; then
    SIMPLE_DEV_OK=true
else
    SIMPLE_DEV_OK=false
fi

if validate_template "infra/main.simple.bicep" "infra/main.prod.parameters.simple.json" "$RESOURCE_GROUP_PROD" "prod"; then
    SIMPLE_PROD_OK=true
else
    SIMPLE_PROD_OK=false
fi

echo ""

# Summary
echo "=== Validation Summary ==="
echo ""
echo "Enterprise Templates:"
echo "  Dev Environment:  $([ "$ENTERPRISE_DEV_OK" = true ] && echo "? PASSED" || echo "? FAILED")"
echo "  Prod Environment: $([ "$ENTERPRISE_PROD_OK" = true ] && echo "? PASSED" || echo "? FAILED")"
echo ""
echo "Simplified Templates:"
echo "  Dev Environment:  $([ "$SIMPLE_DEV_OK" = true ] && echo "? PASSED" || echo "? FAILED")"
echo "  Prod Environment: $([ "$SIMPLE_PROD_OK" = true ] && echo "? PASSED" || echo "? FAILED")"
echo ""

# Recommendations
echo "=== Recommendations ==="
echo ""

if [[ "$ENTERPRISE_DEV_OK" = true && "$ENTERPRISE_PROD_OK" = true ]]; then
    echo "? Enterprise templates are working correctly!"
    echo "   You can use the full enterprise deployment with all security features."
elif [[ "$SIMPLE_DEV_OK" = true && "$SIMPLE_PROD_OK" = true ]]; then
    echo "??  Enterprise templates failed, but simplified templates are working."
    echo "   Recommendation: Use simplified deployment for now."
    echo "   Command: Set deployment_mode to 'simple' in GitHub Actions workflow dispatch."
else
    echo "? Both template types have issues. Please check:"
    echo "   1. Your Azure permissions"
    echo "   2. Parameter file values"
    echo "   3. Subscription limits"
    echo "   4. Azure service availability in your region"
fi

echo ""
echo "=== Next Steps ==="
echo ""
echo "1. If validation passed, you can proceed with deployment"
echo "2. Update parameter files with your specific values if needed"
echo "3. Run GitHub Actions workflow or deploy manually"
echo ""

# Exit with appropriate code
if [[ "$SIMPLE_DEV_OK" = true ]]; then
    exit 0
else
    exit 1
fi
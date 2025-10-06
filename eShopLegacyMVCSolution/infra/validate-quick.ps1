# Quick Deployment Validation Script for Windows
# This script validates the Bicep templates and helps identify issues before deployment

$ErrorActionPreference = "Stop"

Write-Host "=== Azure Infrastructure Deployment Validation ===" -ForegroundColor Cyan
Write-Host ""

# Check if user is logged in to Azure
try {
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        throw "Not logged in"
    }
} catch {
    Write-Host "? Error: Please login to Azure first with 'az login'" -ForegroundColor Red
    exit 1
}

# Get user information
$USER_OBJECT_ID = az ad signed-in-user show --query id --output tsv
$USER_UPN = az ad signed-in-user show --query userPrincipalName --output tsv
$SUBSCRIPTION_ID = az account show --query id --output tsv

Write-Host "? Azure Login: OK" -ForegroundColor Green
Write-Host "   User: $USER_UPN"
Write-Host "   Subscription: $SUBSCRIPTION_ID"
Write-Host ""

# Set variables
$RESOURCE_GROUP_DEV = "rg-eshop-dev"
$RESOURCE_GROUP_PROD = "rg-eshop-prod"
$LOCATION = "East US 2"

# Function to validate a template
function Validate-Template {
    param(
        [string]$Template,
        [string]$Parameters,
        [string]$ResourceGroup,
        [string]$Mode
    )
    
    Write-Host "Validating $Mode template: $Template"
    
    # Create resource group if it doesn't exist
    $groupExists = az group show --name $ResourceGroup 2>$null
    if (-not $groupExists) {
        Write-Host "  Creating resource group: $ResourceGroup"
        az group create --name $ResourceGroup --location $LOCATION --tags Environment=$Mode Purpose="eShop Legacy MVC" | Out-Null
    }
    
    # Validate template
    try {
        if ($Template -like "*simple*") {
            $validationResult = az deployment group validate `
                --resource-group $ResourceGroup `
                --template-file $Template `
                --parameters $Parameters `
                --parameters currentUserObjectId=$USER_OBJECT_ID `
                --query "error" `
                --output json 2>&1
        } else {
            $validationResult = az deployment group validate `
                --resource-group $ResourceGroup `
                --template-file $Template `
                --parameters $Parameters `
                --parameters currentUserObjectId=$USER_OBJECT_ID `
                --parameters currentUserPrincipalName=$USER_UPN `
                --query "error" `
                --output json 2>&1
        }
        
        if ($validationResult -eq "null") {
            Write-Host "  ? Validation: PASSED" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  ? Validation: FAILED" -ForegroundColor Red
            Write-Host "  Error: $validationResult" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "  ? Validation: FAILED" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# Test enterprise templates
Write-Host "=== Testing Enterprise Templates ===" -ForegroundColor Cyan
Write-Host ""

$ENTERPRISE_DEV_OK = Validate-Template "infra/main.enterprise.bicep" "infra/main.dev.parameters.enterprise.json" $RESOURCE_GROUP_DEV "dev"
$ENTERPRISE_PROD_OK = Validate-Template "infra/main.enterprise.bicep" "infra/main.prod.parameters.enterprise.json" $RESOURCE_GROUP_PROD "prod"

Write-Host ""

# Test simplified templates
Write-Host "=== Testing Simplified Templates ===" -ForegroundColor Cyan
Write-Host ""

$SIMPLE_DEV_OK = Validate-Template "infra/main.simple.bicep" "infra/main.dev.parameters.simple.json" $RESOURCE_GROUP_DEV "dev"
$SIMPLE_PROD_OK = Validate-Template "infra/main.simple.bicep" "infra/main.prod.parameters.simple.json" $RESOURCE_GROUP_PROD "prod"

Write-Host ""

# Summary
Write-Host "=== Validation Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Enterprise Templates:"
Write-Host "  Dev Environment:  $(if ($ENTERPRISE_DEV_OK) { "? PASSED" } else { "? FAILED" })"
Write-Host "  Prod Environment: $(if ($ENTERPRISE_PROD_OK) { "? PASSED" } else { "? FAILED" })"
Write-Host ""
Write-Host "Simplified Templates:"
Write-Host "  Dev Environment:  $(if ($SIMPLE_DEV_OK) { "? PASSED" } else { "? FAILED" })"
Write-Host "  Prod Environment: $(if ($SIMPLE_PROD_OK) { "? PASSED" } else { "? FAILED" })"
Write-Host ""

# Recommendations
Write-Host "=== Recommendations ===" -ForegroundColor Cyan
Write-Host ""

if ($ENTERPRISE_DEV_OK -and $ENTERPRISE_PROD_OK) {
    Write-Host "? Enterprise templates are working correctly!" -ForegroundColor Green
    Write-Host "   You can use the full enterprise deployment with all security features."
} elseif ($SIMPLE_DEV_OK -and $SIMPLE_PROD_OK) {
    Write-Host "??  Enterprise templates failed, but simplified templates are working." -ForegroundColor Yellow
    Write-Host "   Recommendation: Use simplified deployment for now."
    Write-Host "   Command: Set deployment_mode to 'simple' in GitHub Actions workflow dispatch."
} else {
    Write-Host "? Both template types have issues. Please check:" -ForegroundColor Red
    Write-Host "   1. Your Azure permissions"
    Write-Host "   2. Parameter file values"
    Write-Host "   3. Subscription limits"
    Write-Host "   4. Azure service availability in your region"
}

Write-Host ""
Write-Host "=== Next Steps ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. If validation passed, you can proceed with deployment"
Write-Host "2. Update parameter files with your specific values if needed"
Write-Host "3. Run GitHub Actions workflow or deploy manually"
Write-Host ""

# Exit with appropriate code
if ($SIMPLE_DEV_OK) {
    exit 0
} else {
    exit 1
}
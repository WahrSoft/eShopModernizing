# =============================================================================
# Enterprise Azure Deployment Script for eShop Legacy MVC (PowerShell)
# =============================================================================

param(
    [string]$ResourceGroupName = "rg-eshop-enterprise",
    [string]$Location = "East US",
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment = "dev",
    [string]$Prefix = "eshop",
    [switch]$ValidateOnly,
    [switch]$WhatIf,
    [switch]$Help
)

# Function to write colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Show-Help {
    Write-Host "Usage: .\deploy.ps1 -SubscriptionId <subscription-id> [OPTIONS]"
    Write-Host ""
    Write-Host "Deploy eShop Legacy MVC to Azure with enterprise-grade infrastructure"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -ResourceGroupName    Resource group name (default: $ResourceGroupName)"
    Write-Host "  -Location             Azure region (default: $Location)"
    Write-Host "  -SubscriptionId       Azure subscription ID (required)"
    Write-Host "  -Environment          Environment name (dev/staging/prod, default: dev)"
    Write-Host "  -Prefix               Resource name prefix (default: eshop)"
    Write-Host "  -ValidateOnly         Only validate the template without deploying"
    Write-Host "  -WhatIf               Show what changes would be made"
    Write-Host "  -Help                 Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\deploy.ps1 -SubscriptionId 'your-subscription-id'"
    Write-Host "  .\deploy.ps1 -SubscriptionId 'sub-id' -Environment prod -ValidateOnly"
    Write-Host "  .\deploy.ps1 -SubscriptionId 'sub-id' -WhatIf"
}

if ($Help) {
    Show-Help
    exit 0
}

if (-not $SubscriptionId) {
    Write-Error "Subscription ID is required. Use -SubscriptionId parameter"
    Show-Help
    exit 1
}

$DeploymentName = "eshop-enterprise-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Status "Starting eShop Enterprise deployment..."
Write-Status "Resource Group: $ResourceGroupName"
Write-Status "Location: $Location"
Write-Status "Environment: $Environment"
Write-Status "Subscription: $SubscriptionId"

# Check Azure CLI installation
try {
    $null = Get-Command az -ErrorAction Stop
} catch {
    Write-Error "Azure CLI is not installed. Please install it first."
    exit 1
}

# Check Azure CLI authentication
Write-Status "Checking Azure CLI authentication..."
try {
    $null = az account show 2>$null
} catch {
    Write-Warning "Not logged in to Azure CLI. Please login first."
    az login
}

# Set subscription
Write-Status "Setting Azure subscription..."
az account set --subscription $SubscriptionId

# Get current user information for Entra ID admin assignment
Write-Status "Getting current user information..."
$CurrentUserInfo = az ad signed-in-user show --query '{objectId:id, userPrincipalName:userPrincipalName}' -o tsv
$CurrentUserObjectId = ($CurrentUserInfo -split "`t")[0]
$CurrentUserUPN = ($CurrentUserInfo -split "`t")[1]

Write-Status "Current User Object ID: $CurrentUserObjectId"
Write-Status "Current User UPN: $CurrentUserUPN"

# Create resource group
Write-Status "Creating resource group..."
az group create --name $ResourceGroupName --location $Location --output table

# Update parameters file with current values
Write-Status "Updating deployment parameters..."
$ParamsFile = "main.parameters.json"
$ParametersContent = @{
    '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
    contentVersion = "1.0.0.0"
    parameters = @{
        environmentName = @{ value = $Environment }
        location = @{ value = $Location }
        namePrefix = @{ value = $Prefix }
        sqlAdminUsername = @{ value = "eshopadmin" }
        currentUserObjectId = @{ value = $CurrentUserObjectId }
        currentUserPrincipalName = @{ value = $CurrentUserUPN }
        enableMonitoring = @{ value = $true }
        appServicePlanSku = @{ value = "S1" }
        sqlDatabaseTier = @{ value = "Standard" }
        sqlDatabaseSize = @{ value = "S1" }
    }
} | ConvertTo-Json -Depth 4

$ParametersContent | Out-File -FilePath $ParamsFile -Encoding UTF8

# Validate template
Write-Status "Validating Bicep template..."
$ValidationResult = az deployment group validate `
    --resource-group $ResourceGroupName `
    --template-file "main.bicep" `
    --parameters "@main.parameters.json" `
    --output table

if ($LASTEXITCODE -ne 0) {
    Write-Error "Template validation failed!"
    exit 1
}

Write-Success "Template validation successful!"

# What-if analysis
if ($WhatIf) {
    Write-Status "Running what-if analysis..."
    az deployment group what-if `
        --resource-group $ResourceGroupName `
        --template-file "main.bicep" `
        --parameters "@main.parameters.json"
    exit 0
}

# Exit if validate-only flag is set
if ($ValidateOnly) {
    Write-Success "Validation completed successfully!"
    exit 0
}

# Deploy template
Write-Status "Starting deployment..."
$DeploymentResult = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "main.bicep" `
    --parameters "@main.parameters.json" `
    --name $DeploymentName `
    --output table

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment failed!"
    exit 1
}

# Get deployment outputs
Write-Status "Getting deployment outputs..."
$Outputs = az deployment group show `
    --resource-group $ResourceGroupName `
    --name $DeploymentName `
    --query 'properties.outputs' `
    --output json | ConvertFrom-Json

Write-Success "Deployment completed successfully!"
Write-Status "Deployment outputs:"
$Outputs | ConvertTo-Json -Depth 3

# Extract key information
$AppServiceUrl = $Outputs.appServiceUrl.value
$KeyVaultName = $Outputs.keyVaultName.value
$SqlServerName = $Outputs.sqlServerName.value

if ($AppServiceUrl) {
    Write-Success "Application URL: $AppServiceUrl"
}

if ($KeyVaultName) {
    Write-Success "Key Vault: $KeyVaultName"
}

if ($SqlServerName) {
    Write-Success "SQL Server: $SqlServerName"
}

Write-Status "Next steps:"
Write-Host "1. Configure your application code to use managed identity for database connections"
Write-Host "2. Update your CI/CD pipeline to deploy to the new App Service"
Write-Host "3. Configure custom domains and SSL certificates if needed"
Write-Host "4. Set up monitoring alerts in Application Insights"
Write-Host "5. Review and configure backup policies"

Write-Success "Enterprise deployment completed!"
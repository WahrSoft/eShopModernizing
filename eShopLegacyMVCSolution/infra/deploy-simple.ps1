# Enterprise eShop Legacy MVC Deployment Script
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "prod")]
    [string]$Environment,
    
    [switch]$ValidateOnly,
    [switch]$PreviewOnly
)

# Configuration
$ResourceGroupDev = "rg-eshop-dev"
$ResourceGroupProd = "rg-eshop-prod"
$Location = "North Central US"
$TemplateFile = "./main.enterprise.bicep"

# Functions
function Write-Info {
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

# Main script
Write-Host "eShop Legacy MVC - Enterprise Infrastructure" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Set environment-specific variables
switch ($Environment) {
    "dev" {
        $ResourceGroup = $ResourceGroupDev
        $ParamFile = "./main.dev.parameters.enterprise.json"
    }
    "prod" {
        $ResourceGroup = $ResourceGroupProd
        $ParamFile = "./main.prod.parameters.enterprise.json"
    }
}

Write-Info "Environment: $Environment"
Write-Info "Resource Group: $ResourceGroup"

# Get user information
$UserObjectId = az ad signed-in-user show --query id --output tsv
$UserUPN = az ad signed-in-user show --query userPrincipalName --output tsv

# Create resource group
az group create --name $ResourceGroup --location $Location

# Deploy infrastructure
$DeploymentName = "eshop-infrastructure-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

if ($ValidateOnly) {
    az deployment group validate --resource-group $ResourceGroup --template-file $TemplateFile --parameters $ParamFile --parameters currentUserObjectId=$UserObjectId --parameters currentUserPrincipalName=$UserUPN
} elseif ($PreviewOnly) {
    az deployment group what-if --resource-group $ResourceGroup --template-file $TemplateFile --parameters $ParamFile --parameters currentUserObjectId=$UserObjectId --parameters currentUserPrincipalName=$UserUPN
} else {
    az deployment group create --resource-group $ResourceGroup --template-file $TemplateFile --parameters $ParamFile --parameters currentUserObjectId=$UserObjectId --parameters currentUserPrincipalName=$UserUPN --name $DeploymentName
}

Write-Success "Operation completed successfully!"
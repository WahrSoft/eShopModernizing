# eShop Legacy MVC - Enterprise Azure Infrastructure

This repository contains enterprise-grade Azure infrastructure for the eShop Legacy MVC application using Infrastructure as Code (Bicep) with security best practices.

## Architecture Overview

The solution deploys the following Azure resources:

- **Virtual Network** with multiple subnets and Network Security Groups
- **Azure SQL Database** with Entra ID authentication and private endpoint
- **Redis Cache** with private endpoint for session management
- **Key Vault** for secure secret storage with RBAC access
- **App Service** with VNet integration and managed identity
- **Application Insights** for monitoring and telemetry
- **Private endpoints** for all data services

## Security Features

? **Zero Public Access**: All data services use private endpoints  
? **Managed Identity**: No connection strings or passwords in app configuration  
? **Key Vault Integration**: All secrets stored securely with RBAC access  
? **Entra ID Authentication**: SQL Server uses Azure AD authentication  
? **TLS 1.2 Minimum**: Enforced across all services  
? **Network Segmentation**: Dedicated subnets with NSG rules  

## Prerequisites

### 1. Azure CLI Installation
```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login to Azure
az login

# Set your subscription
az account set --subscription "Your-Subscription-Name"
```

### 2. Required Permissions
Your account needs the following roles in the target subscription:
- **Contributor** (for resource creation)
- **User Access Administrator** (for role assignments)

### 3. Get Your User Information
```bash
# Get your Object ID
az ad signed-in-user show --query id --output tsv

# Get your User Principal Name
az ad signed-in-user show --query userPrincipalName --output tsv
```

## Setup Instructions

### 1. Update Parameter Files
Edit the parameter files and replace the placeholder values:

**For Development (infra/main.dev.parameters.enterprise.json):**
```json
{
  "currentUserObjectId": { "value": "YOUR_OBJECT_ID_HERE" },
  "currentUserPrincipalName": { "value": "YOUR_UPN_HERE" }
}
```

**For Production (infra/main.prod.parameters.enterprise.json):**
```json
{
  "currentUserObjectId": { "value": "YOUR_OBJECT_ID_HERE" },
  "currentUserPrincipalName": { "value": "YOUR_UPN_HERE" }
}
```

### 2. Deploy Infrastructure Manually

#### Development Environment
```bash
# Create resource group
az group create --name rg-eshop-dev --location "East US 2"

# Validate deployment
az deployment group validate \
  --resource-group rg-eshop-dev \
  --template-file infra/main.enterprise.bicep \
  --parameters infra/main.dev.parameters.enterprise.json

# Preview changes
az deployment group what-if \
  --resource-group rg-eshop-dev \
  --template-file infra/main.enterprise.bicep \
  --parameters infra/main.dev.parameters.enterprise.json

# Deploy
az deployment group create \
  --resource-group rg-eshop-dev \
  --template-file infra/main.enterprise.bicep \
  --parameters infra/main.dev.parameters.enterprise.json
```

## GitHub Actions CI/CD Setup

### 1. Create Service Principal for GitHub Actions
```bash
# Create service principal
az ad sp create-for-rbac \
  --name "eshop-github-actions" \
  --role contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --sdk-auth
```

### 2. Add GitHub Secrets
Add **AZURE_CREDENTIALS** secret with the JSON output from the service principal creation.

### 3. Configure Environments
Create **dev** and **prod** environments in your GitHub repository.

## Infrastructure Modules

- **`modules/network.bicep`**: Virtual network, subnets, and NSGs
- **`modules/keyvault.bicep`**: Key Vault with private endpoint
- **`modules/sql.bicep`**: SQL Server and database with Entra ID auth
- **`modules/redis.bicep`**: Redis Cache with private endpoint
- **`modules/appinsights.bicep`**: Application Insights and Log Analytics
- **`modules/appservice.bicep`**: App Service with VNet integration

## Cleanup

To remove all resources:
```bash
az group delete --name rg-eshop-dev --yes --no-wait
```
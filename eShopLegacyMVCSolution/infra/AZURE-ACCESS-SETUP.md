# Azure Access Setup Guide for eShop Legacy MVC Enterprise Deployment

This guide provides step-by-step instructions for setting up Azure access for deploying the eShop Legacy MVC application with enterprise-grade security.

## Prerequisites

1. **Azure Subscription**: You need an active Azure subscription with sufficient permissions
2. **Azure CLI**: Latest version installed on your machine
3. **Git**: For cloning and managing the repository

## Step 1: Install Azure CLI

### Windows
```powershell
# Using winget
winget install Microsoft.AzureCLI

# Or download from: https://aka.ms/installazurecliwindows
```

### macOS
```bash
# Using Homebrew
brew update && brew install azure-cli
```

### Linux (Ubuntu/Debian)
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

## Step 2: Login to Azure

```bash
# Login interactively
az login

# If you have multiple subscriptions, list them
az account list --output table

# Set the subscription you want to use
az account set --subscription "Your-Subscription-Name-or-ID"

# Verify current subscription
az account show
```

## Step 3: Verify Required Permissions

Your account needs the following permissions in the target subscription:

### Required RBAC Roles:
- **Contributor** (for creating and managing resources)
- **User Access Administrator** (for role assignments)

### Check your permissions:
```bash
# Check role assignments
az role assignment list --assignee $(az ad signed-in-user show --query id --output tsv) --all

# Check if you have Contributor access
az role assignment list --assignee $(az ad signed-in-user show --query id --output tsv) --role "Contributor"

# Check if you have User Access Administrator access
az role assignment list --assignee $(az ad signed-in-user show --query id --output tsv) --role "User Access Administrator"
```

## Step 4: Get Your User Information

You'll need this information for the deployment parameters:

```bash
# Get your Object ID
az ad signed-in-user show --query id --output tsv

# Get your User Principal Name (UPN)
az ad signed-in-user show --query userPrincipalName --output tsv

# Save these values - you'll need them for parameter files
```

## Step 5: Update Parameter Files

### Development Environment
Edit `infra/main.dev.parameters.enterprise.json`:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environmentName": {
      "value": "dev"
    },
    "location": {
      "value": "East US 2"
    },
    "baseName": {
      "value": "eshop"
    },
    "sqlAdminUsername": {
      "value": "sqladmin"
    },
    "currentUserObjectId": {
      "value": "YOUR_OBJECT_ID_HERE"
    },
    "currentUserPrincipalName": {
      "value": "YOUR_UPN_HERE"
    }
  }
}
```

### Production Environment
Edit `infra/main.prod.parameters.enterprise.json`:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environmentName": {
      "value": "prod"
    },
    "location": {
      "value": "East US 2"
    },
    "baseName": {
      "value": "eshop"
    },
    "sqlAdminUsername": {
      "value": "sqladmin"
    },
    "currentUserObjectId": {
      "value": "YOUR_OBJECT_ID_HERE"
    },
    "currentUserPrincipalName": {
      "value": "YOUR_UPN_HERE"
    }
  }
}
```

## Step 6: Manual Deployment

### Option A: Using PowerShell Script (Recommended)
```powershell
# Navigate to the repository root
cd path\to\your\repository

# Make the script executable and run for development
.\infra\deploy-simple.ps1 -Environment dev

# For production (with confirmation)
.\infra\deploy-simple.ps1 -Environment prod

# To only validate without deploying
.\infra\deploy-simple.ps1 -Environment dev -ValidateOnly

# To preview changes without deploying
.\infra\deploy-simple.ps1 -Environment dev -PreviewOnly
```

### Option B: Using Azure CLI Directly
```bash
# Create resource group
az group create --name rg-eshop-dev --location "East US 2"

# Get your user info
USER_OBJECT_ID=$(az ad signed-in-user show --query id --output tsv)
USER_UPN=$(az ad signed-in-user show --query userPrincipalName --output tsv)

# Validate the deployment
az deployment group validate \
  --resource-group rg-eshop-dev \
  --template-file infra/main.enterprise.bicep \
  --parameters infra/main.dev.parameters.enterprise.json \
  --parameters currentUserObjectId=$USER_OBJECT_ID \
  --parameters currentUserPrincipalName=$USER_UPN

# Deploy the infrastructure
az deployment group create \
  --resource-group rg-eshop-dev \
  --template-file infra/main.enterprise.bicep \
  --parameters infra/main.dev.parameters.enterprise.json \
  --parameters currentUserObjectId=$USER_OBJECT_ID \
  --parameters currentUserPrincipalName=$USER_UPN \
  --name "eshop-infrastructure-$(date +%Y%m%d-%H%M%S)"
```

## Step 7: GitHub Actions Setup (Optional)

If you want to use GitHub Actions for CI/CD:

### Create Service Principal
```bash
# Create service principal for GitHub Actions
az ad sp create-for-rbac \
  --name "eshop-github-actions" \
  --role contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --sdk-auth
```

### Add GitHub Secrets
1. Go to your GitHub repository
2. Navigate to Settings > Secrets and variables > Actions
3. Add a new secret named `AZURE_CREDENTIALS`
4. Paste the JSON output from the service principal creation

### Configure GitHub Environments
1. Go to Settings > Environments
2. Create `dev` environment
3. Create `prod` environment (with protection rules and required reviewers)

## Step 8: Azure DevOps Setup (Alternative)

If you prefer Azure DevOps:

### Create Service Connection
1. Go to Project Settings > Service connections
2. Create new Azure Resource Manager connection
3. Use Service Principal (automatic) or Service Principal (manual)
4. Name it `azureServiceConnection`

### Create Variable Group
1. Go to Pipelines > Library
2. Create variable group named `eShop-Variables`
3. Add variable `azureServiceConnection` with your service connection name

## Step 9: Verification

After deployment, verify everything is working:

```bash
# Run the validation script
chmod +x infra/validate-deployment.sh
./infra/validate-deployment.sh dev

# Or for production
./infra/validate-deployment.sh prod
```

## Troubleshooting

### Common Issues

1. **Insufficient Permissions**
   ```bash
   # Check your current permissions
   az role assignment list --assignee $(az ad signed-in-user show --query id --output tsv)
   ```

2. **Resource Provider Not Registered**
   ```bash
   # Register required resource providers
   az provider register --namespace Microsoft.Web
   az provider register --namespace Microsoft.Sql
   az provider register --namespace Microsoft.Cache
   az provider register --namespace Microsoft.KeyVault
   az provider register --namespace Microsoft.Insights
   ```

3. **Quota Limits**
   ```bash
   # Check quota usage
   az vm list-usage --location "East US 2" --output table
   ```

4. **Network Security Group Rules**
   - Ensure your IP is allowed if using private endpoints
   - Check NSG rules in the Azure portal

### Getting Help

1. **Azure CLI Help**
   ```bash
   az --help
   az deployment group --help
   ```

2. **Bicep Documentation**
   - [Azure Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)

3. **Azure Support**
   - Create support ticket in Azure portal if you have a support plan

## Security Best Practices

1. **Use Least Privilege**: Only grant minimum required permissions
2. **Enable MFA**: Ensure multi-factor authentication is enabled
3. **Regular Review**: Review and rotate access keys regularly
4. **Monitor Access**: Enable Azure Activity Log monitoring
5. **Conditional Access**: Use conditional access policies for enhanced security

## Cost Management

1. **Set Budgets**: Create budget alerts in Azure portal
2. **Use Tags**: Tag resources for cost tracking
3. **Monitor Usage**: Review Azure Cost Management regularly
4. **Right-size Resources**: Adjust SKUs based on actual usage

## Next Steps

After successful deployment:

1. Configure application settings
2. Set up monitoring and alerting
3. Implement backup strategies
4. Plan for disaster recovery
5. Set up CI/CD pipelines
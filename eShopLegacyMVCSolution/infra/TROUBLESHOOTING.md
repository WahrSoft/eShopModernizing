# Deployment Troubleshooting Guide

This guide helps resolve common deployment issues with the eShop Legacy MVC Azure infrastructure.

## Common Issues and Solutions

### 1. Zone Redundancy Not Supported

**Error**: `Provisioning of zone redundant database/pool is not supported for your current request.`

**Solution**: The SQL module has been updated to disable zone redundancy by default. If you still encounter this issue:

1. Use the simplified deployment:
   ```bash
   az deployment group create \
     --resource-group rg-eshop-dev \
     --template-file infra/main.simple.bicep \
     --parameters infra/main.dev.parameters.simple.json \
     --parameters currentUserObjectId=$(az ad signed-in-user show --query id --output tsv)
   ```

2. Or manually set zone redundancy to false in your parameters.

### 2. Redis RDB Storage Configuration Error

**Error**: `The value of the parameter 'properties.redisConfiguration.rdb-storage-connection-string' is invalid.`

**Solutions**:
- The Redis module has been updated to remove problematic RDB configuration
- Use Standard tier instead of Premium for development environments
- The simplified Redis module uses minimal configuration to avoid parameter conflicts

### 3. SQL Public Network Access Conflicts

**Error**: `Unable to create or modify firewall rules when public network interface for the server is disabled.`

**Solutions**:
- The SQL module now enables public access but restricts it via firewall rules
- Private endpoints are still created for secure access
- For maximum security, you can disable public access after deployment

### 4. Azure AD Only Authentication Parameter Error

**Error**: `Invalid value given for parameter AzureADOnlyAuthentication. Specify a valid parameter value.`

**Solutions**:
- The `azureADOnlyAuthentication` property has been removed from the SQL administrators object
- SQL authentication is now enabled alongside Azure AD authentication for flexibility
- This allows both SQL Server authentication and Azure AD authentication to work

### 5. User Permission Issues

**Error**: Access denied errors during deployment.

**Solutions**:
1. Ensure your user has the required permissions:
   ```bash
   # Check current user
   az ad signed-in-user show --query userPrincipalName

   # Assign required roles
   az role assignment create \
     --role "Contributor" \
     --assignee $(az ad signed-in-user show --query userPrincipalName -o tsv) \
     --scope "/subscriptions/YOUR_SUBSCRIPTION_ID"
   ```

2. Update parameter files with correct user information:
   ```bash
   # Get your object ID
   az ad signed-in-user show --query id --output tsv
   
   # Get your UPN
   az ad signed-in-user show --query userPrincipalName --output tsv
   ```

## Deployment Options

### Option 1: Enterprise Deployment (Recommended for Production)
- Includes VNet integration, private endpoints, and enhanced security
- Use `main.enterprise.bicep` with enterprise parameter files

### Option 2: Simplified Deployment (Recommended for Development/Testing)
- Basic configuration with public endpoints
- Faster deployment, fewer dependencies
- Use `main.simple.bicep` with simple parameter files

### Option 3: Fallback Deployment Commands

If the automated GitHub Actions deployment fails, try these manual commands:

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Create resource group
az group create --name "rg-eshop-dev" --location "East US 2"

# Deploy with simplified template
az deployment group create \
  --resource-group "rg-eshop-dev" \
  --template-file infra/main.simple.bicep \
  --parameters infra/main.dev.parameters.simple.json \
  --parameters currentUserObjectId=$(az ad signed-in-user show --query id --output tsv)
```

## Validation Steps

Before deploying, always validate your template:

```bash
# Validate enterprise template
az deployment group validate \
  --resource-group "rg-eshop-dev" \
  --template-file infra/main.enterprise.bicep \
  --parameters infra/main.dev.parameters.enterprise.json \
  --parameters currentUserObjectId=$(az ad signed-in-user show --query id --output tsv) \
  --parameters currentUserPrincipalName=$(az ad signed-in-user show --query userPrincipalName --output tsv)

# Validate simple template
az deployment group validate \
  --resource-group "rg-eshop-dev" \
  --template-file infra/main.simple.bicep \
  --parameters infra/main.dev.parameters.simple.json \
  --parameters currentUserObjectId=$(az ad signed-in-user show --query id --output tsv)
```

## Monitoring Deployment

Track deployment progress:

```bash
# List recent deployments
az deployment group list \
  --resource-group "rg-eshop-dev" \
  --query "[].{Name:name, State:provisioningState, Timestamp:timestamp}" \
  --output table

# Get detailed deployment information
az deployment group show \
  --resource-group "rg-eshop-dev" \
  --name "YOUR_DEPLOYMENT_NAME" \
  --query "properties.error" \
  --output json
```

## Common Error Patterns and Quick Fixes

### SQL Server Issues
- **Azure AD Authentication Errors**: Use simplified deployment or remove Azure AD configuration
- **Firewall Rule Conflicts**: Ensure public network access is enabled before creating firewall rules
- **Zone Redundancy**: Disable zone redundancy for compatibility

### Redis Cache Issues
- **Invalid Configuration Parameters**: Use simplified Redis configuration without RDB settings
- **SKU Compatibility**: Use Standard tier for development, Premium only for production with supported regions

### Key Vault Issues
- **Access Policy Conflicts**: Ensure current user has proper permissions before deployment
- **Secret Creation Failures**: Verify Key Vault is created before attempting to store secrets

## Getting Help

If you continue to experience issues:

1. Check the Azure Activity Log in the portal
2. Review the GitHub Actions logs for detailed error messages
3. Try the simplified deployment option
4. Contact your Azure administrator for subscription-level permission issues
5. Check Azure service health for regional outages

## Recovery Steps

If deployment partially succeeds but some resources fail:

1. Identify failed resources:
   ```bash
   az deployment group list \
     --resource-group "rg-eshop-dev" \
     --query "[?provisioningState=='Failed']" \
     --output table
   ```

2. Delete failed resources and retry:
   ```bash
   # Example: Delete failed SQL server
   az sql server delete --name "failed-sql-server" --resource-group "rg-eshop-dev"
   ```

3. Re-run the deployment with the same parameters

## Quick Reference

### Most Common Solutions
1. **Use simplified deployment** for fastest resolution
2. **Check user permissions** before deploying
3. **Validate templates** before running deployments
4. **Monitor deployment logs** for specific error details
5. **Clean up failed resources** before retrying
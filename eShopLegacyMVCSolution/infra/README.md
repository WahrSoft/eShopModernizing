# eShop Legacy MVC - Enterprise Azure Infrastructure

This folder contains the Infrastructure as Code (IaC) templates and deployment scripts for deploying the eShop Legacy MVC application to Azure using enterprise-grade best practices.

## Architecture Overview

The infrastructure includes the following components:

### Core Infrastructure
- **Virtual Network (VNet)** with dedicated subnets for different services
- **Network Security Groups (NSGs)** for network-level security
- **Private Endpoints** for secure communication to PaaS services
- **Private DNS Zones** for private endpoint name resolution

### Compute & Application Hosting
- **App Service Plan** with Linux containers support
- **App Service** with .NET 8 runtime and managed identity
- **Staging Slot** for blue-green deployments
- **VNet Integration** for secure outbound connectivity

### Data & Storage
- **Azure SQL Database** with Entra ID authentication
- **SQL Private Endpoint** for secure database access
- **Automated SQL user creation** for managed identity authentication

### Security & Secrets Management
- **Azure Key Vault** with RBAC authorization
- **Key Vault Private Endpoint** for secure secrets access
- **Managed Identity** for passwordless authentication
- **TLS 1.2 minimum** across all services

### Monitoring & Observability
- **Application Insights** for application performance monitoring
- **Log Analytics Workspace** for centralized logging
- **Connection strings and secrets** stored in Key Vault

## Network Architecture

```
???????????????????????????????????????????????????????
?                Virtual Network                      ?
?                 10.0.0.0/16                        ?
???????????????????????????????????????????????????????
?  App Service Subnet (10.0.1.0/24)                 ?
?  ?? App Service with VNet Integration               ?
?  ?? NSG with HTTPS/HTTP rules                      ?
?  ?? Service Endpoints (Key Vault, SQL)             ?
???????????????????????????????????????????????????????
?  Private Endpoints Subnet (10.0.2.0/24)           ?
?  ?? Key Vault Private Endpoint                     ?
?  ?? SQL Server Private Endpoint                    ?
?  ?? Private DNS Zones                              ?
???????????????????????????????????????????????????????
?  SQL Subnet (10.0.3.0/24)                         ?
?  ?? SQL Service Endpoints                          ?
???????????????????????????????????????????????????????
```

## Security Features

### Network Security
- **Private Endpoints**: All PaaS services accessible only through private network
- **Network Security Groups**: Layer 4 firewall rules for subnet-level protection
- **Service Endpoints**: Secure connectivity to Azure services from VNet
- **No Public Database Access**: SQL Server accessible only through private endpoint

### Identity & Access Management
- **Managed Identity**: App Service uses system-assigned managed identity
- **Entra ID Authentication**: SQL Server configured with Entra ID admin
- **RBAC Authorization**: Key Vault uses Azure RBAC instead of access policies
- **Least Privilege Access**: Minimal required permissions for each service

### Data Protection
- **TLS 1.2 Minimum**: All services configured with minimum TLS version
- **Encryption in Transit**: All communications encrypted
- **Key Vault Secrets**: Connection strings and sensitive data stored securely
- **Soft Delete Protection**: Key Vault and SQL Database have soft delete enabled

## File Structure

```
infra/
??? main.bicep                    # Main orchestration template
??? main.parameters.json          # Deployment parameters
??? deploy.sh                     # Linux/macOS deployment script
??? deploy.ps1                    # Windows PowerShell deployment script
??? README.md                     # This file
??? modules/
    ??? network.bicep             # Virtual network and subnets
    ??? keyvault.bicep            # Key Vault with private endpoint
    ??? database.bicep            # SQL Server and database
    ??? monitoring.bicep          # Application Insights and Log Analytics
    ??? appservice.bicep          # App Service and App Service Plan
    ??? keyvault-access.bicep     # Key Vault RBAC assignments
    ??? sql-access.bicep          # SQL managed identity configuration
```

## Prerequisites

1. **Azure CLI** installed and configured
2. **Bicep CLI** (included with Azure CLI 2.20.0+)
3. **Appropriate Azure permissions**:
   - Contributor role on the subscription or resource group
   - User Access Administrator role (for RBAC assignments)
   - Ability to create service principals and assign roles

## Deployment Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `environmentName` | Environment (dev/staging/prod) | dev | No |
| `location` | Azure region | East US | No |
| `namePrefix` | Resource name prefix | eshop | No |
| `sqlAdminUsername` | SQL admin username | eshopadmin | No |
| `currentUserObjectId` | Your Azure AD Object ID | - | Yes |
| `currentUserPrincipalName` | Your email/UPN | - | Yes |
| `enableMonitoring` | Enable Application Insights | true | No |
| `appServicePlanSku` | App Service Plan SKU | B2 | No |
| `sqlDatabaseTier` | SQL Database tier | Standard | No |
| `sqlDatabaseSize` | SQL Database size | S1 | No |

## Quick Start

### Option 1: Using the Deployment Script (Recommended)

#### Linux/macOS:
```bash
cd infra
chmod +x deploy.sh
./deploy.sh -s "your-subscription-id"
```

#### Windows PowerShell:
```powershell
cd infra
.\deploy.ps1 -SubscriptionId "your-subscription-id"
```

### Option 2: Manual Deployment

1. **Get your user information**:
```bash
# Get your Object ID and UPN
az ad signed-in-user show --query '{objectId:id, userPrincipalName:userPrincipalName}' -o table
```

2. **Update parameters file** with your information:
```json
{
  "currentUserObjectId": {
    "value": "your-object-id-here"
  },
  "currentUserPrincipalName": {
    "value": "your-email@domain.com"
  }
}
```

3. **Create resource group**:
```bash
az group create --name rg-eshop-enterprise --location "East US"
```

4. **Validate the template**:
```bash
az deployment group validate \
  --resource-group rg-eshop-enterprise \
  --template-file main.bicep \
  --parameters @main.parameters.json
```

5. **Deploy the template**:
```bash
az deployment group create \
  --resource-group rg-eshop-enterprise \
  --template-file main.bicep \
  --parameters @main.parameters.json \
  --name eshop-deployment
```

## Advanced Deployment Options

### Validate Only
```bash
./deploy.sh -s "subscription-id" --validate-only
```

### What-If Analysis
```bash
./deploy.sh -s "subscription-id" --what-if
```

### Production Deployment
```bash
./deploy.sh -s "subscription-id" -e prod -g rg-eshop-prod
```

## Post-Deployment Configuration

### 1. Application Configuration

Update your application's `appsettings.json` to use Key Vault references:

```json
{
  "ConnectionStrings": {
    "CatalogDBContext": "@Microsoft.KeyVault(VaultName=your-keyvault-name;SecretName=sql-connection-string)"
  },
  "ApplicationInsights": {
    "ConnectionString": "@Microsoft.KeyVault(VaultName=your-keyvault-name;SecretName=app-insights-connection-string)"
  }
}
```

### 2. Database Initialization

The deployment automatically creates a SQL user for the App Service managed identity. Ensure your Entity Framework context is configured for managed identity:

```csharp
services.AddDbContext<CatalogDBContext>(options =>
{
    options.UseSqlServer(configuration.GetConnectionString("CatalogDBContext"));
});
```

### 3. Key Vault Integration

Configure Key Vault in your application:

```csharp
var builder = WebApplication.CreateBuilder(args);

// Add Azure Key Vault
builder.Configuration.AddAzureKeyVault(
    new Uri($"https://{keyVaultName}.vault.azure.net/"),
    new DefaultAzureCredential());
```

### 4. Application Insights Integration

Application Insights is automatically configured through the connection string in Key Vault.

## Monitoring and Troubleshooting

### View Deployment Status
```bash
az deployment group show \
  --resource-group rg-eshop-enterprise \
  --name eshop-deployment \
  --query 'properties.{State:provisioningState, Timestamp:timestamp}'
```

### View Application Logs
```bash
az webapp log tail --name your-app-name --resource-group rg-eshop-enterprise
```

### Test Private Endpoint Connectivity
```bash
# From a VM in the same VNet
nslookup your-keyvault-name.vault.azure.net
nslookup your-sql-server.database.windows.net
```

## Cost Optimization

### Development Environment
- Use Basic App Service Plan (B1/B2)
- Use Standard SQL Database (S0/S1)
- Disable staging slots if not needed

### Production Environment
- Consider Premium App Service Plan for auto-scaling
- Use Standard/Premium SQL Database with appropriate sizing
- Enable zone redundancy for high availability

## Security Considerations

1. **Network Isolation**: All services use private endpoints
2. **Identity-Based Authentication**: No passwords stored or used
3. **Secrets Management**: All secrets stored in Key Vault
4. **Monitoring**: Application Insights tracks all requests and dependencies
5. **Access Control**: RBAC used for fine-grained permissions

## Backup and Disaster Recovery

- **SQL Database**: Automated backups with point-in-time restore
- **Key Vault**: Soft delete enabled with 90-day retention
- **App Service**: Source code should be in version control
- **Infrastructure**: This IaC template serves as the infrastructure backup

## Support and Troubleshooting

### Common Issues

1. **Permission Errors**: Ensure you have Contributor and User Access Administrator roles
2. **Private Endpoint Resolution**: DNS resolution may take a few minutes after deployment
3. **App Service Startup**: Check Application Insights for startup errors

### Getting Help

1. Check Application Insights for application errors
2. Review deployment logs in Azure Portal
3. Use Azure CLI diagnostic commands
4. Check service health in Azure Portal

## Contributing

When making changes to the infrastructure:

1. Always validate templates before deployment
2. Use parameter files for environment-specific values
3. Follow Azure naming conventions
4. Document any new parameters or outputs
5. Test in development environment first

## License

This infrastructure template is part of the eShop Legacy MVC application.
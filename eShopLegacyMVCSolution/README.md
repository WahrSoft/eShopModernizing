# eShop Modernized - Migration to .NET 8 with Azure PaaS

This repository contains the modernized version of the eShopLegacyMVC application, migrated from .NET Framework 4.7.2 to .NET 8 with Azure PaaS services integration.

## ?? **Key Modernizations**

### **Framework Migration**
- ? **ASP.NET MVC 5** ? **ASP.NET Core 8**
- ? **Entity Framework 6** ? **Entity Framework Core 8**
- ? **BinaryFormatter** ? **System.Text.Json** (Security & Performance)
- ? **Web.config** ? **appsettings.json**
- ? **Autofac** ? **Built-in Dependency Injection**

### **Azure PaaS Integration**
- ? **Azure App Service** - Web hosting
- ? **Azure SQL Database** - Primary database
- ? **Azure Blob Storage** - File storage with Managed Identity
- ? **Azure Redis Cache** - Distributed session state
- ? **Azure Application Insights** - Monitoring & telemetry
- ? **Azure Key Vault** - Secrets management

## ?? **Prerequisites**

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- [Entity Framework Core Tools](https://docs.microsoft.com/ef/core/cli/dotnet)

## ?? **Setup Instructions**

### **1. Install Required Tools**

```bash
# Install EF Core Tools globally
dotnet tool install --global dotnet-ef

# Verify installation
dotnet ef --version
```

### **2. Local Development Setup**

```bash
# Navigate to the modernized project
cd src/eShopModernized

# Restore packages
dotnet restore

# Create initial database migration
dotnet ef migrations add InitialCreate

# Update local database
dotnet ef database update

# Run the application
dotnet run
```

The application will be available at `https://localhost:5001` with Swagger UI at the root.

### **3. Azure Deployment**

#### **Option A: Using Azure Developer CLI (Recommended)**

```bash
# Initialize the project (if not already done)
azd init

# Provision Azure resources and deploy
azd up

# Follow prompts to:
# - Select Azure subscription
# - Choose deployment region
# - Provide SQL admin credentials
```

#### **Option B: Manual Bicep Deployment**

```bash
# Login to Azure
az login

# Create resource group
az group create --name rg-eshop-modernized --location eastus

# Validate Bicep template
az deployment group validate \
  --resource-group rg-eshop-modernized \
  --template-file infra/main.bicep \
  --parameters sqlAdminLogin=sqladmin sqlAdminPassword=YourSecurePassword123!

# Deploy infrastructure
az deployment group create \
  --resource-group rg-eshop-modernized \
  --template-file infra/main.bicep \
  --parameters sqlAdminLogin=sqladmin sqlAdminPassword=YourSecurePassword123!

# Deploy application code
dotnet publish -c Release
az webapp deployment source config-zip \
  --resource-group rg-eshop-modernized \
  --name <your-app-service-name> \
  --src ./src/eShopModernized/bin/Release/net8.0/publish.zip
```

## ?? **Configuration**

### **Development Environment**
- Uses SQL Server LocalDB
- In-memory session state
- Local file storage simulation

### **Production Environment**
- Azure SQL Database with Managed Identity authentication
- Azure Redis Cache for session state
- Azure Blob Storage for file storage
- Application Insights for monitoring

## ?? **API Endpoints**

The modernized application provides a RESTful API:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/catalog` | GET | Get paginated catalog items |
| `/api/catalog/{id}` | GET | Get specific catalog item |
| `/api/catalog/types` | GET | Get all catalog types |
| `/api/catalog/brands` | GET | Get all catalog brands |
| `/api/catalog/brands/{id}/items` | GET | Get items by brand |
| `/api/catalog/types/{id}/items` | GET | Get items by type |
| `/health` | GET | Health check endpoint |

## ?? **Security Improvements**

1. **Authentication**: Azure Managed Identity (no connection strings)
2. **Data Protection**: TLS 1.2 minimum, HTTPS redirect
3. **Session Security**: Secure cookies, SameSite protection
4. **SQL Injection**: Parameterized queries with EF Core
5. **CORS**: Configurable cross-origin policies

## ?? **Performance Optimizations**

1. **Async/Await**: All data operations are asynchronous
2. **Connection Pooling**: EF Core connection pooling
3. **Caching**: Redis distributed caching
4. **Retry Logic**: Automatic retry for transient failures
5. **Health Checks**: Proactive monitoring

## ?? **Migration Notes**

### **Breaking Changes from Legacy**
1. **BinaryFormatter Removal**: Legacy serialized endpoints now return JSON
2. **Session State**: Distributed session may not persist local session data
3. **File Storage**: Picture files moved from local storage to Azure Blob Storage
4. **Database Schema**: Minor EF Core migrations may be required

### **Backward Compatibility**
- Legacy endpoints maintained with `[Obsolete]` attributes
- Gradual migration strategy supported
- Configuration migration guides provided

## ?? **Database Migration from Legacy**

```bash
# Export data from legacy SQL Server
sqlcmd -S "(localdb)\MSSQLLocalDB" -d "Microsoft.eShopOnContainers.Services.CatalogDb" -Q "SELECT * FROM Catalog" -o catalog_export.csv

# Import to Azure SQL Database (update connection string)
# Use Azure Data Factory or SQL Server Management Studio
```

## ?? **Monitoring & Troubleshooting**

### **Application Insights Queries**
```kusto
// Application errors
exceptions
| where timestamp > ago(1h)
| project timestamp, message, operation_Name

// Performance issues
requests
| where timestamp > ago(1h)
| where duration > 5000
| project timestamp, name, duration

// Dependency failures
dependencies
| where timestamp > ago(1h)
| where success == false
| project timestamp, name, type, resultCode
```

### **Health Check Monitoring**
- Navigate to `/health` for real-time status
- Includes database, Redis, and storage connectivity checks

## ?? **Next Steps**

1. **Load Testing**: Use Azure Load Testing service
2. **CI/CD Pipeline**: Set up GitHub Actions with azd
3. **Monitoring**: Configure Application Insights alerts
4. **Scaling**: Implement auto-scaling policies
5. **Security**: Add Azure AD authentication

## ?? **Support**

For issues or questions:
1. Check the [troubleshooting guide](./docs/troubleshooting.md)
2. Review Azure service health status
3. Check Application Insights for error details
4. Create an issue in this repository

---

**Migration Status**: ? **Complete** - Ready for production deployment with Azure PaaS services.
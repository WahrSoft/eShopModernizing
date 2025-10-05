# .NET 8 Upgrade Report

## Project target framework modifications

| Project name                                       | Old Target Framework    | New Target Framework | Commits                   |
|:---------------------------------------------------|:-----------------------:|:--------------------:|---------------------------|
| eShopLegacy.Utilities\eShopLegacy.Utilities.csproj| .NETFramework v4.6.1   | net8.0               | 69944ff4, 0c32fa18, c2e81e10 |
| src\eShopLegacyMVC\eShopLegacyMVC.csproj          | .NETFramework v4.7.2   | net8.0               | e8f708d5, 37feeda8, 3818ffa4 |

## NuGet Packages

| Package Name                                        | Old Version | New Version | Commit Id                                 |
|:----------------------------------------------------|:-----------:|:-----------:|-------------------------------------------|
| bootstrap                                          | 4.3.1       | 5.3.8       | 37feeda8 (Security vulnerability)         |
| EntityFramework                                    | 6.2.0       | 6.5.1       | 37feeda8                                  |
| jQuery                                             | 3.5.0       | 3.7.1       | 37feeda8                                  |
| Microsoft.ApplicationInsights                      | 2.9.1       | 2.23.0      | 37feeda8                                  |
| Microsoft.ApplicationInsights.DependencyCollector | 2.9.1       | 2.23.0      | 37feeda8                                  |
| Microsoft.ApplicationInsights.PerfCounterCollector| 2.9.1       | 2.23.0      | 37feeda8                                  |
| Microsoft.ApplicationInsights.WindowsServer       | 2.9.1       | 2.23.0      | 37feeda8                                  |
| Microsoft.ApplicationInsights.WindowsServer.TelemetryChannel | 2.9.1 | 2.23.0 | 37feeda8                         |
| Microsoft.AspNet.TelemetryCorrelation             | 1.0.5       | 1.0.3       | 37feeda8                                  |
| Microsoft.jQuery.Unobtrusive.Validation           | 3.2.11      | 4.0.0       | 37feeda8                                  |
| Newtonsoft.Json                                    | 12.0.1      | 13.0.4      | 37feeda8 (Security vulnerability)         |
| System.Diagnostics.DiagnosticSource               | 4.5.1       | 8.0.1       | 37feeda8                                  |
| System.Diagnostics.PerformanceCounter             | 4.5.0       | 8.0.1       | 37feeda8                                  |
| System.IO.Pipelines                                | 4.5.1       | 8.0.0       | 37feeda8                                  |
| System.Runtime.CompilerServices.Unsafe            | 4.5.0       | 6.1.2       | 37feeda8                                  |
| System.Threading.Channels                          | 4.5.0       | 8.0.0       | 37feeda8                                  |

## All commits

| Commit ID              | Description                                |
|:-----------------------|:-------------------------------------------|
| 69944ff4               | Commit upgrade plan                        |
| 0c32fa18               | Remove references from eShopLegacy.Utilities |
| c2e81e10               | Add net8.0 target to eShopLegacy.Utilities |
| e8f708d5               | Store final changes for step 'Upgrade src\\eShopLegacyMVC\\eShopLegacyMVC.csproj to .NET 8' |
| 5b82cc94               | Feature 4 complete: Configuration management conversion |
| cdc939b3               | Feature 2 complete: RouteCollection registration conversion |
| 09d2dc19               | Feature 1 complete: System.Web.Optimization bundling replacement |
| 06bf5393               | Feature 3 complete: Global.asax.cs application initialization conversion |
| 416ddde5               | Feature 5 complete: Application Insights modernization |
| 37feeda8               | Update NuGet packages in eShopLegacyMVC.csproj |
| 3818ffa4               | Commit changes before fixing errors |

## Project feature upgrades

Contains summary of modifications made to the project assets during different upgrade stages.

### eShopLegacy.Utilities

Here is what changed for the project during upgrade:

- **Project conversion**: Converted from .NET Framework 4.6.1 to .NET 8 with SDK-style project format
- **BinaryFormatter modernization**: Replaced obsolete BinaryFormatter with System.Text.Json for .NET 8 compatibility
- **Assembly references cleanup**: Removed all legacy .NET Framework assembly references

### src\\eShopLegacyMVC

Here is what changed for this project during upgrade:

- **System.Web.Optimization bundling and minification replacement**: Replaced all @Scripts.Render and @Styles.Render with direct HTML tags, removed BundleConfig.cs and related references
- **RouteCollection registration conversion**: Converted route registration from RouteConfig.cs to modern .NET Core route mappings in Program.cs using app.MapControllerRoute
- **Global.asax.cs application initialization conversion**: Moved all application startup logic from Global.asax.cs to Program.cs including Autofac DI setup, session tracking, and logging middleware
- **Configuration management conversion**: Replaced ConfigurationManager with IConfiguration dependency injection pattern throughout the application
- **Application Insights modernization**: Updated from legacy ApplicationInsights.config to modern .NET Core programmatic configuration using AddApplicationInsightsTelemetry
- **Controller modernization**: Updated all controllers from System.Web.Mvc to Microsoft.AspNetCore.Mvc including:
  - CatalogController: Changed ActionResult to IActionResult, updated HTTP status code methods
  - PicController: Updated file serving with IWebHostEnvironment for wwwroot path resolution
  - API Controllers: Converted WebAPI controllers to modern ASP.NET Core API controllers with proper routing attributes
- **Security vulnerability remediation**: Updated bootstrap (4.3.1 → 5.3.8) and Newtonsoft.Json (12.0.1 → 13.0.4)
- **Package compatibility**: Removed incompatible .NET Framework packages and added .NET Core compatible alternatives including Autofac.Extensions.DependencyInjection and Microsoft.AspNetCore.SystemWebAdapters

## Azure Deployment Readiness

The application has been successfully modernized for Azure deployment with the following improvements:

- **PaaS Compatibility**: Converted to .NET 8 for deployment to Azure App Service or Azure Container Apps
- **Configuration Management**: Uses IConfiguration pattern compatible with Azure App Configuration
- **Application Insights**: Modern telemetry configuration ready for Azure Application Insights
- **Security**: Addressed security vulnerabilities in bootstrap and Newtonsoft.Json packages
- **Entity Framework**: Maintained EF 6.x compatibility for gradual migration to EF Core

## Next steps

- Consider migrating from Entity Framework 6.x to Entity Framework Core for better .NET 8 performance
- Evaluate migration from SQL Server LocalDB to Azure SQL Database
- Move static files (Pics folder) to Azure Blob Storage
- Implement containerization with Docker for deployment to Azure Container Apps
- Add comprehensive health checks and monitoring for production deployment
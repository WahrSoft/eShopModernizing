# .NET 8 Upgrade Report

## Project target framework modifications

| Project name                                   | Old Target Framework    | New Target Framework         | Commits                   |
|:-----------------------------------------------|:-----------------------:|:----------------------------:|---------------------------|
| eShopLegacy.Utilities                          |   .NET Framework 4.6.1 | .NET 8.0                     | 78d24842, 1ba7955b, 1eaaec45 |
| eShopLegacyMVC                                 |   .NET Framework 4.7.2 | .NET 8.0                     | 56637bf6, d085a657, 23c13719 |

## NuGet Packages

| Package Name                                        | Old Version | New Version | Description                                |
|:----------------------------------------------------|:-----------:|:-----------:|--------------------------------------------|
| Antlr                                              |   -         |  4.6.6      | Added for .NET 8 compatibility            |
| bootstrap                                          |   4.3.1     |  5.3.8      | Security vulnerability fix                 |
| EntityFramework                                    |   6.2.0     |  6.5.1      | Upgraded to latest compatible version      |
| jQuery                                             |   3.5.0     |  3.7.1      | Deprecated package replacement             |
| Microsoft.ApplicationInsights                      |   2.9.1     |  2.23.0     | Deprecated package replacement             |
| Microsoft.ApplicationInsights.DependencyCollector |   2.9.1     |  2.23.0     | Deprecated package replacement             |
| Microsoft.ApplicationInsights.PerfCounterCollector|   2.9.1     |  2.23.0     | Deprecated package replacement             |
| Microsoft.ApplicationInsights.WindowsServer       |   2.9.1     |  2.23.0     | Deprecated package replacement             |
| Microsoft.ApplicationInsights.WindowsServer.TelemetryChannel | 2.9.1 | 2.23.0 | Deprecated package replacement             |
| Microsoft.AspNet.TelemetryCorrelation             |   1.0.5     |  1.0.3      | Compatibility adjustment                   |
| Microsoft.jQuery.Unobtrusive.Validation           |   3.2.11    |  4.0.0      | Deprecated package replacement             |
| Newtonsoft.Json                                    |   12.0.1    |  13.0.4     | Security vulnerability fix                 |
| System.Diagnostics.DiagnosticSource               |   4.5.1     |  8.0.1      | Upgraded to .NET 8 version                |
| System.Diagnostics.PerformanceCounter             |   4.5.0     |  8.0.1      | Upgraded to .NET 8 version                |
| System.IO.Pipelines                                |   4.5.1     |  8.0.0      | Upgraded to .NET 8 version                |
| System.Runtime.CompilerServices.Unsafe            |   4.5.0     |  6.1.2      | Upgraded to compatible version             |
| System.Threading.Channels                          |   4.5.0     |  8.0.0      | Upgraded to .NET 8 version                |

## All commits

| Commit ID              | Description                                |
|:-----------------------|:-------------------------------------------|
| 8db4bfbe               | Commit upgrade plan                        |
| 78d24842               | Convert Utilities project to SDK-style format |
| 1ba7955b               | Remove legacy references from Utilities project |
| 45bd8c09               | Migrate assembly metadata to MSBuild properties |
| 1eaaec45               | Store final changes for step 'Upgrade eShopLegacy.Utilities' |
| 331eabd0               | RouteCollection feature upgrade completed  |
| 56637bf6               | GlobalFilterCollection feature upgrade completed |
| d085a657               | Convert project to .NET 8 SDK format      |
| 23c13719               | Classic EntityFramework initialization upgrade completed |
| 91741101               | System.Web.Optimization bundling upgrade completed |
| 9824035c               | Update NuGet packages in eShopLegacyMVC.csproj |
| 7a50b6e0               | Global.asax.cs application initialization conversion completed |
| c979922d               | Autofac to ASP.NET Core dependency injection conversion completed |

## Project feature upgrades

Contains summary of modifications made to the project assets during different upgrade stages.

### eShopLegacy.Utilities

Here is what changed for the project during upgrade:

- **Project modernization**: Converted from legacy .NET Framework project format to modern SDK-style project format
- **Target framework upgrade**: Updated from .NET Framework 4.6.1 to .NET 8.0
- **BinaryFormatter replacement**: Replaced obsolete BinaryFormatter with System.Text.Json for modern serialization
- **Assembly metadata migration**: Moved assembly attributes from AssemblyInfo.cs to MSBuild properties in project file
- **Legacy reference cleanup**: Removed unnecessary System.Data.DataSetExtensions and Microsoft.CSharp references

### eShopLegacyMVC

Here is what changed for the project during upgrade:

- **Project modernization**: Converted from legacy .NET Framework 4.7.2 MVC project to modern .NET 8 SDK-style project
- **System.Web.Optimization bundling and minification feature upgrade**: Replaced all @Scripts.Render and @Styles.Render with direct script and link tags, removed BundleConfig and related references
- **GlobalFilterCollection feature upgrade**: Converted global error handling from HandleErrorAttribute to ASP.NET Core middleware with UseExceptionHandler and UseStatusCodePagesWithReExecute
- **RouteCollection feature upgrade**: Converted route registration from RouteTable.Routes to app.MapControllerRoute in Program.cs
- **Classic EntityFramework initialization upgrade**: Moved Database.SetInitializer from Global.asax.cs to Program.cs with dependency injection registration
- **Autofac to ASP.NET Core dependency injection conversion**: Replaced Autofac container with built-in ASP.NET Core DI container, converted all service registrations
- **Global.asax.cs application initialization conversion**: Migrated Application_Start, Session_Start, and Application_BeginRequest logic to ASP.NET Core middleware in Program.cs
- **Controller modernization**: Updated all controllers to use Microsoft.AspNetCore.Mvc instead of System.Web.Mvc
- **API controller conversion**: Converted Web API controllers from System.Web.Http.ApiController to Microsoft.AspNetCore.Mvc.ControllerBase
- **Session state modernization**: Replaced HttpContext.Current.Session with ASP.NET Core session in views and middleware
- **Error handling enhancement**: Added Error and StatusErrorCode action methods with corresponding views for comprehensive error handling

## Security Improvements

- **Bootstrap upgraded** from 4.3.1 to 5.3.8 to address security vulnerabilities
- **Newtonsoft.Json upgraded** from 12.0.1 to 13.0.4 to address security vulnerabilities
- **Removed obsolete BinaryFormatter** which had security concerns and replaced with modern JSON serialization

## Next steps

- Consider migrating from Entity Framework 6 to Entity Framework Core for better .NET 8 integration
- Review and test all application functionality thoroughly in the new .NET 8 environment
- Configure proper logging with modern ASP.NET Core logging providers instead of log4net if desired
- Review application performance and optimize where needed using .NET 8 performance improvements
- Consider implementing modern ASP.NET Core features like health checks, OpenAPI documentation, and configuration providers
- Plan deployment to modern hosting environments that support .NET 8 (Azure App Service, containers, etc.)

# .NET 8 Upgrade Plan

## Execution Steps

Execute steps below sequentially one by one in the order they are listed.

1. Validate that a .NET 8 SDK required for this upgrade is installed on the machine and if not, help to get it installed.
2. Ensure that the SDK version specified in global.json files is compatible with the .NET 8 upgrade.
3. Upgrade eShopLegacy.Utilities\eShopLegacy.Utilities.csproj to .NET 8
4. Upgrade src\eShopLegacyMVC\eShopLegacyMVC.csproj to .NET 8

## Settings

This section contains settings and data used by execution steps.

### Excluded projects

No projects are excluded from this upgrade.

### Aggregate NuGet packages modifications across all projects

NuGet packages used across all selected projects or their dependencies that need version update in projects that reference them.

| Package Name                                        | Current Version | New Version | Description                                    |
|:---------------------------------------------------|:---------------:|:-----------:|:-----------------------------------------------|
| Antlr                                              | 3.5.0.2         | 4.6.6       | Recommended upgrade to Antlr4                 |
| bootstrap                                          | 4.3.1           | 5.3.8       | **Security vulnerability**                     |
| EntityFramework                                    | 6.2.0           | 6.5.1       | Recommended upgrade and deprecated package     |
| jQuery                                             | 3.5.0           | 3.7.1       | Deprecated package with incorrect intellisense |
| Microsoft.ApplicationInsights                      | 2.9.1           | 2.23.0      | Deprecated package upgrade                     |
| Microsoft.ApplicationInsights.DependencyCollector | 2.9.1           | 2.23.0      | Deprecated package upgrade                     |
| Microsoft.ApplicationInsights.PerfCounterCollector| 2.9.1           | 2.23.0      | Deprecated package upgrade                     |
| Microsoft.ApplicationInsights.WindowsServer       | 2.9.1           | 2.23.0      | Deprecated package upgrade                     |
| Microsoft.ApplicationInsights.WindowsServer.TelemetryChannel | 2.9.1 | 2.23.0    | Deprecated package upgrade                     |
| Microsoft.AspNet.TelemetryCorrelation             | 1.0.5           | 1.0.3       | Incompatible package downgrade                 |
| Microsoft.jQuery.Unobtrusive.Validation           | 3.2.11          | 4.0.0       | Deprecated package upgrade                     |
| Newtonsoft.Json                                    | 12.0.1          | 13.0.4      | **Security vulnerability** and recommended upgrade |
| System.Diagnostics.DiagnosticSource               | 4.5.1           | 8.0.1       | Recommended upgrade                            |
| System.Diagnostics.PerformanceCounter             | 4.5.0           | 8.0.1       | Recommended upgrade                            |
| System.IO.Pipelines                                | 4.5.1           | 8.0.0       | Recommended upgrade                            |
| System.Runtime.CompilerServices.Unsafe            | 4.5.0           | 6.1.2       | Recommended upgrade                            |
| System.Threading.Channels                          | 4.5.0           | 8.0.0       | Recommended upgrade                            |

### Project upgrade details

This section contains details about each project upgrade and modifications that need to be done in the project.

#### eShopLegacy.Utilities\eShopLegacy.Utilities.csproj modifications

Project properties changes:
- Target framework should be changed from `.NETFramework,Version=v4.6.1` to `net8.0`
- Convert project file to SDK-style format

#### src\eShopLegacyMVC\eShopLegacyMVC.csproj modifications

Project properties changes:
- Target framework should be changed from `.NETFramework,Version=v4.7.2` to `net8.0`
- Convert project file to SDK-style format

NuGet packages changes:
- **Security vulnerabilities:**
  - bootstrap should be updated from `4.3.1` to `5.3.8` (*security vulnerability*)
  - Newtonsoft.Json should be updated from `12.0.1` to `13.0.4` (*security vulnerability*)
- **Recommended upgrades:**
  - Antlr should be updated from `3.5.0.2` to `4.6.6` (*recommended upgrade to Antlr4*)
  - EntityFramework should be updated from `6.2.0` to `6.5.1` (*recommended upgrade and deprecated*)
  - jQuery should be updated from `3.5.0` to `3.7.1` (*deprecated package*)
  - Microsoft.ApplicationInsights should be updated from `2.9.1` to `2.23.0` (*deprecated package*)
  - Microsoft.ApplicationInsights.DependencyCollector should be updated from `2.9.1` to `2.23.0` (*deprecated package*)
  - Microsoft.ApplicationInsights.PerfCounterCollector should be updated from `2.9.1` to `2.23.0` (*deprecated package*)
  - Microsoft.ApplicationInsights.WindowsServer should be updated from `2.9.1` to `2.23.0` (*deprecated package*)
  - Microsoft.ApplicationInsights.WindowsServer.TelemetryChannel should be updated from `2.9.1` to `2.23.0` (*deprecated package*)
  - Microsoft.AspNet.TelemetryCorrelation should be updated from `1.0.5` to `1.0.3` (*incompatible package*)
  - Microsoft.jQuery.Unobtrusive.Validation should be updated from `3.2.11` to `4.0.0` (*deprecated package*)
  - System.Diagnostics.DiagnosticSource should be updated from `4.5.1` to `8.0.1` (*recommended upgrade*)
  - System.Diagnostics.PerformanceCounter should be updated from `4.5.0` to `8.0.1` (*recommended upgrade*)
  - System.IO.Pipelines should be updated from `4.5.1` to `8.0.0` (*recommended upgrade*)
  - System.Runtime.CompilerServices.Unsafe should be updated from `4.5.0` to `6.1.2` (*recommended upgrade*)
  - System.Threading.Channels should be updated from `4.5.0` to `8.0.0` (*recommended upgrade*)
- **Packages to remove (functionality included in framework):**
  - Microsoft.AspNet.Mvc (*included with new framework reference*)
  - Microsoft.AspNet.Razor (*included with new framework reference*)
  - Microsoft.AspNet.SessionState.SessionStateModule (*included with new framework reference*)
  - Microsoft.AspNet.WebPages (*included with new framework reference*)
  - Microsoft.CodeDom.Providers.DotNetCompilerPlatform (*included with new framework reference*)
  - Microsoft.Net.Compilers (*included with new framework reference*)
  - Microsoft.Web.Infrastructure (*included with new framework reference*)
  - System.Buffers (*included with new framework reference*)
  - System.IO.Compression (*included with new framework reference*)
  - System.IO.Compression.ZipFile (*included with new framework reference*)
  - System.Memory (*included with new framework reference*)
  - System.Numerics.Vectors (*included with new framework reference*)
  - System.Threading.Tasks.Extensions (*included with new framework reference*)
- **Incompatible packages to remove:**
  - Autofac.Mvc5 (*no supported version found*)
  - Microsoft.ApplicationInsights.Agent.Intercept (*no supported version found*)
  - Microsoft.ApplicationInsights.Web (*no supported version found*)
  - Microsoft.AspNet.Web.Optimization (*no supported version found*)

Feature upgrades:
- System.Web.Optimization bundling and minification replacement with direct HTML tags
- RouteCollection registration conversion to .NET Core route mappings
- Global.asax.cs application initialization conversion to .NET Core Program.cs/Startup.cs
- Configuration management conversion from ConfigurationManager to IConfiguration
- Application Insights modernization for .NET Core/8

Other changes:
- Entity Framework 6.x to Entity Framework Core migration considerations
- Azure deployment preparation and PaaS service integration
- Security vulnerability remediation
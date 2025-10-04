# .NET 8 Upgrade Plan

## Execution Steps

Execute steps below sequentially one by one in the order they are listed.

1. Validate that a .NET 8 SDK required for this upgrade is installed on the machine and if not, help to get it installed.
2. Ensure that the SDK version specified in global.json files is compatible with the .NET 8 upgrade.
3. Upgrade eShopLegacy.Utilities\eShopLegacy.Utilities.csproj
4. Upgrade src\eShopLegacyMVC\eShopLegacyMVC.csproj

## Settings

This section contains settings and data used by execution steps.

### Aggregate NuGet packages modifications across all projects

NuGet packages used across all selected projects or their dependencies that need version update in projects that reference them.

| Package Name                                        | Current Version | New Version | Description                                    |
|:---------------------------------------------------|:---------------:|:-----------:|:-----------------------------------------------|
| Antlr                                              |   3.5.0.2       |  4.6.6      | Recommended for .NET 8                        |
| bootstrap                                          |   4.3.1         |  5.3.8      | Security vulnerability                         |
| EntityFramework                                    |   6.2.0         |  6.5.1      | Recommended for .NET 8                        |
| jQuery                                             |   3.5.0         |  3.7.1      | Deprecated package replacement                 |
| Microsoft.ApplicationInsights                      |   2.9.1         |  2.23.0     | Deprecated package replacement                 |
| Microsoft.ApplicationInsights.DependencyCollector |   2.9.1         |  2.23.0     | Deprecated package replacement                 |
| Microsoft.ApplicationInsights.PerfCounterCollector|   2.9.1         |  2.23.0     | Deprecated package replacement                 |
| Microsoft.ApplicationInsights.WindowsServer       |   2.9.1         |  2.23.0     | Deprecated package replacement                 |
| Microsoft.ApplicationInsights.WindowsServer.TelemetryChannel | 2.9.1  |  2.23.0     | Deprecated package replacement                 |
| Microsoft.AspNet.TelemetryCorrelation             |   1.0.5         |  1.0.3      | Recommended for .NET 8                        |
| Microsoft.jQuery.Unobtrusive.Validation           |   3.2.11        |  4.0.0      | Deprecated package replacement                 |
| Newtonsoft.Json                                    |   12.0.1        |  13.0.4     | Security vulnerability                         |
| System.Diagnostics.DiagnosticSource               |   4.5.1         |  8.0.1      | Recommended for .NET 8                        |
| System.Diagnostics.PerformanceCounter             |   4.5.0         |  8.0.1      | Recommended for .NET 8                        |
| System.IO.Pipelines                                |   4.5.1         |  8.0.0      | Recommended for .NET 8                        |
| System.Runtime.CompilerServices.Unsafe            |   4.5.0         |  6.1.2      | Recommended for .NET 8                        |
| System.Threading.Channels                          |   4.5.0         |  8.0.0      | Recommended for .NET 8                        |

### Project upgrade details
This section contains details about each project upgrade and modifications that need to be done in the project.

#### eShopLegacy.Utilities modifications

Project properties changes:
  - Target framework should be changed from `.NETFramework,Version=v4.6.1` to `net8.0`
  - Project file needs to be converted to SDK-style

#### eShopLegacyMVC modifications

Project properties changes:
  - Target framework should be changed from `.NETFramework,Version=v4.7.2` to `net8.0`
  - Project file needs to be converted to SDK-style

NuGet packages changes:
  - Antlr should be updated from `3.5.0.2` to `4.6.6` (*recommended for .NET 8*)
  - bootstrap should be updated from `4.3.1` to `5.3.8` (*security vulnerability*)
  - EntityFramework should be updated from `6.2.0` to `6.5.1` (*recommended for .NET 8*)
  - jQuery should be updated from `3.5.0` to `3.7.1` (*deprecated package replacement*)
  - Microsoft.ApplicationInsights should be updated from `2.9.1` to `2.23.0` (*deprecated package replacement*)
  - Microsoft.ApplicationInsights.DependencyCollector should be updated from `2.9.1` to `2.23.0` (*deprecated package replacement*)
  - Microsoft.ApplicationInsights.PerfCounterCollector should be updated from `2.9.1` to `2.23.0` (*deprecated package replacement*)
  - Microsoft.ApplicationInsights.WindowsServer should be updated from `2.9.1` to `2.23.0` (*deprecated package replacement*)
  - Microsoft.ApplicationInsights.WindowsServer.TelemetryChannel should be updated from `2.9.1` to `2.23.0` (*deprecated package replacement*)
  - Microsoft.AspNet.TelemetryCorrelation should be updated from `1.0.5` to `1.0.3` (*recommended for .NET 8*)
  - Microsoft.jQuery.Unobtrusive.Validation should be updated from `3.2.11` to `4.0.0` (*deprecated package replacement*)
  - Newtonsoft.Json should be updated from `12.0.1` to `13.0.4` (*security vulnerability*)
  - System.Diagnostics.DiagnosticSource should be updated from `4.5.1` to `8.0.1` (*recommended for .NET 8*)
  - System.Diagnostics.PerformanceCounter should be updated from `4.5.0` to `8.0.1` (*recommended for .NET 8*)
  - System.IO.Pipelines should be updated from `4.5.1` to `8.0.0` (*recommended for .NET 8*)
  - System.Runtime.CompilerServices.Unsafe should be updated from `4.5.0` to `6.1.2` (*recommended for .NET 8*)
  - System.Threading.Channels should be updated from `4.5.0` to `8.0.0` (*recommended for .NET 8*)

NuGet packages to remove:
  - Autofac.Mvc5 (*no supported version found*)
  - Microsoft.ApplicationInsights.Agent.Intercept (*no supported version found*)
  - Microsoft.ApplicationInsights.Web (*no supported version found*)
  - Microsoft.AspNet.Web.Optimization (*no supported version found*)
  - Microsoft.AspNet.Mvc (*functionality included with framework reference*)
  - Microsoft.AspNet.Razor (*functionality included with framework reference*)
  - Microsoft.AspNet.SessionState.SessionStateModule (*functionality included with framework reference*)
  - Microsoft.AspNet.WebPages (*functionality included with framework reference*)
  - Microsoft.CodeDom.Providers.DotNetCompilerPlatform (*functionality included with framework reference*)
  - Microsoft.Net.Compilers (*functionality included with framework reference*)
  - Microsoft.Web.Infrastructure (*functionality included with framework reference*)
  - System.Buffers (*functionality included with framework reference*)
  - System.IO.Compression (*functionality included with framework reference*)
  - System.IO.Compression.ZipFile (*functionality included with framework reference*)
  - System.Memory (*functionality included with framework reference*)
  - System.Numerics.Vectors (*functionality included with framework reference*)
  - System.Threading.Tasks.Extensions (*functionality included with framework reference*)

Feature upgrades:
  - System.Web.Optimization bundling and minification feature upgrade: replace all @Scripts.Render and @Styles.Render with direct tags, remove BundleConfig and related references
  - RouteCollection feature upgrade: convert route registration to app.MapControllerRoute in Program.cs
  - GlobalFilterCollection feature upgrade: convert global filters to middleware registrations
  - Classic EntityFramework initialization upgrade: adjust for .NET Core compatibility
  - Autofac to ASP.NET Core dependency injection conversion
  - Global.asax.cs application initialization conversion to .NET Core Program.cs/Startup.cs

Other changes:
  - Convert project files to SDK-style format
  - Update web.config settings to appsettings.json format
  - Migrate Global.asax.cs functionality to .NET Core startup
# .NET 8 Upgrade Plan - Complete Entity Framework to EF Core Migration

## Execution Steps

Execute steps below sequentially one by one in the order they are listed.

1. Validate that a .NET 8 SDK required for this upgrade is installed on the machine and if not, help to get it installed.
2. Ensure that the SDK version specified in global.json files is compatible with the .NET 8 upgrade.
3. **Complete Entity Framework to EF Core Migration for eShopLegacy.Utilities\eShopLegacy.Utilities.csproj**
4. **Complete Entity Framework to EF Core Migration for src\eShopLegacyMVC\eShopLegacyMVC.csproj**
5. **Update DbContext and model configurations for EF Core**
6. **Migrate database initialization and seeding to EF Core patterns**
7. **Update dependency injection and configuration for EF Core**
8. **Remove all Entity Framework 6.x references and compatibility mode code**
9. **Update LINQ queries and data access patterns for EF Core**
10. **Validate and test the complete EF Core migration**

## Settings

This section contains settings and data used by execution steps.

### Excluded projects

No projects are excluded from this upgrade.

### Entity Framework to EF Core Migration Details

**Primary Focus**: Complete migration from Entity Framework 6.x to Entity Framework Core 8.0 with **NO compatibility mode**.

#### Key Migration Areas:

1. **Package References**:
   - Remove: `EntityFramework` (6.5.1)
   - Remove: `Microsoft.EntityFramework.SqlServer` (6.5.1)
   - Add: `Microsoft.EntityFrameworkCore` (8.0.x)
   - Add: `Microsoft.EntityFrameworkCore.SqlServer` (8.0.x)
   - Add: `Microsoft.EntityFrameworkCore.Tools` (8.0.x)
   - Add: `Microsoft.EntityFrameworkCore.Design` (8.0.x)

2. **DbContext Migration**:
   - Replace `System.Data.Entity.DbContext` with `Microsoft.EntityFrameworkCore.DbContext`
   - Update `OnModelCreating` from `DbModelBuilder` to `ModelBuilder`
   - Replace `EntityTypeConfiguration<T>` with `EntityTypeBuilder<T>`
   - Update configuration syntax and patterns

3. **Database Initialization**:
   - Replace `Database.SetInitializer` with EF Core migration patterns
   - Convert `CatalogDBInitializer` to use EF Core seeding patterns
   - Remove `DbConfigurationType` attributes

4. **Connection String Management**:
   - Update from `connectionString` constructor to EF Core `DbContextOptions`
   - Integrate with .NET Core dependency injection
   - Update configuration patterns

5. **Query and Data Access Patterns**:
   - Update any EF6-specific LINQ patterns
   - Replace synchronous methods with async patterns where beneficial
   - Update any direct SQL execution patterns

### Aggregate NuGet packages modifications across all projects

NuGet packages used across all selected projects that need updates for EF Core migration.

| Package Name                               | Current Version | New Version | Description                                                    |
|:------------------------------------------|:---------------:|:-----------:|:---------------------------------------------------------------|
| **EF Core Packages (NEW)**               |                 |             |                                                                |
| Microsoft.EntityFrameworkCore            | N/A             | 8.0.11      | **Core EF Core package - NEW**                               |
| Microsoft.EntityFrameworkCore.SqlServer  | N/A             | 8.0.11      | **SQL Server provider for EF Core - NEW**                   |
| Microsoft.EntityFrameworkCore.Tools      | N/A             | 8.0.11      | **EF Core CLI tools for migrations - NEW**                  |
| Microsoft.EntityFrameworkCore.Design     | N/A             | 8.0.11      | **EF Core design-time tools - NEW**                         |
| **EF6 Packages (REMOVE)**                |                 |             |                                                                |
| EntityFramework                           | 6.5.1           | REMOVE      | **Legacy EF6 package to be completely removed**              |
| Microsoft.EntityFramework.SqlServer      | 6.5.1           | REMOVE      | **Legacy EF6 SQL Server provider to be removed**            |
| **Other Dependencies**                    |                 |             |                                                                |
| Microsoft.Data.SqlClient                 | 6.1.1           | 5.2.2       | **Compatible version for EF Core 8.0**                      |
| Newtonsoft.Json                          | 13.0.4          | 13.0.4      | **Keep current (security compliant)**                        |
| bootstrap                                 | 5.3.3           | 5.3.3       | **Keep current (security compliant)**                        |

### Project upgrade details

This section contains details about each project upgrade and modifications that need to be done.

#### eShopLegacy.Utilities\eShopLegacy.Utilities.csproj modifications

**EF Core Migration Changes:**
- Remove any Entity Framework 6.x references if present
- Add EF Core packages if data access is needed
- Update any data access utilities to use EF Core patterns

#### src\eShopLegacyMVC\eShopLegacyMVC.csproj modifications

**Complete EF Core Migration - NO Compatibility Mode:**

**Package Reference Changes:**
- **REMOVE** `EntityFramework` (6.5.1) - *Complete removal of EF6*
- **REMOVE** `Microsoft.EntityFramework.SqlServer` (6.5.1) - *Complete removal of EF6*
- **ADD** `Microsoft.EntityFrameworkCore` (8.0.11) - *Modern EF Core*
- **ADD** `Microsoft.EntityFrameworkCore.SqlServer` (8.0.11) - *EF Core SQL Server provider*
- **ADD** `Microsoft.EntityFrameworkCore.Tools` (8.0.11) - *EF Core CLI tools*
- **ADD** `Microsoft.EntityFrameworkCore.Design` (8.0.11) - *EF Core design-time support*
- **UPDATE** `Microsoft.Data.SqlClient` from (6.1.1) to (5.2.2) - *EF Core compatible version*

**Code Migration Changes:**

1. **DbContext Migration (`Models\CatalogDBContext.cs`)**:
   - Replace `using System.Data.Entity;` with `using Microsoft.EntityFrameworkCore;`
   - Replace `using System.Data.Entity.ModelConfiguration;` with appropriate EF Core namespaces
   - Remove `using System.Data.Entity.SqlServer;`
   - Remove `[DbConfigurationType(typeof(MicrosoftSqlDbConfiguration))]` attribute
   - Update constructor to accept `DbContextOptions<CatalogDBContext>`
   - Replace `DbModelBuilder` with `ModelBuilder` in `OnModelCreating`
   - Replace `EntityTypeConfiguration<T>` with `EntityTypeBuilder<T>` configurations
   - Update all fluent API calls to EF Core syntax

2. **Model Configuration Updates**:
   - Replace `builder.Entity<T>()` patterns with EF Core equivalents
   - Update `HasRequired` to `HasOne` with `WithMany`
   - Update `HasForeignKey` syntax for EF Core
   - Replace `HasDatabaseGeneratedOption(DatabaseGeneratedOption.None)` with `ValueGeneratedNever()`
   - Update all property configuration methods

3. **Database Initialization Migration (`Models\Infrastructure\CatalogDBInitializer.cs`)**:
   - Remove EF6 `DropCreateDatabaseIfModelChanges<T>` base class
   - Implement EF Core seeding using `ModelBuilder.Entity<T>().HasData()`
   - Replace `Seed` method with EF Core migration seeding patterns
   - Update to use EF Core migration system

4. **Dependency Injection Updates (`Program.cs`)**:
   - Remove EF6 `Database.SetInitializer` calls
   - Add EF Core `AddDbContext` registration
   - Configure connection string using EF Core patterns
   - Remove any EF6-specific configuration code

5. **Controller and Service Updates**:
   - Update any async patterns to use EF Core async methods
   - Replace EF6-specific LINQ patterns with EF Core equivalents
   - Update any direct SQL execution to use EF Core APIs

6. **Configuration and Connection String Updates**:
   - Update connection string registration for EF Core
   - Remove any EF6-specific configuration sections
   - Ensure proper EF Core service registration

**Removed Compatibility Dependencies:**
- No System Web Adapters needed for EF Core
- No legacy Entity Framework compatibility shims
- Complete migration to modern EF Core patterns

**Migration Strategy:**
- **Zero Compatibility Mode**: Complete replacement of EF6 with EF Core
- **Modern Patterns**: Use latest EF Core 8.0 features and patterns
- **Async-First**: Implement async data access patterns throughout
- **Clean Architecture**: Remove all legacy EF6 dependencies and code
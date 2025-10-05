using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.EntityFrameworkCore;
using eShopLegacyMVC.Models;
using eShopLegacyMVC.Models.Infrastructure;
using eShopLegacyMVC.Services;
using System.Reflection;
using System.Diagnostics;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Hosting;
using System;
using System.Linq;
using System.Collections.Generic;
using eShopLegacyMVC;
using Azure.Identity;
using Azure.Extensions.AspNetCore.Configuration.Secrets;
using Azure.Security.KeyVault.Secrets;

var builder = WebApplication.CreateBuilder(args);

// Configure Azure Key Vault integration
if (builder.Configuration.GetValue<bool>("Azure:UseKeyVault"))
{
    var keyVaultUri = builder.Configuration.GetValue<string>("KeyVault:VaultUri");
    if (!string.IsNullOrEmpty(keyVaultUri))
    {
        var secretClient = new SecretClient(new Uri(keyVaultUri), new DefaultAzureCredential());
        builder.Configuration.AddAzureKeyVault(secretClient, new KeyVaultSecretManager());
    }
}

// Configure ASP.NET Core logging
builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();
builder.Logging.AddEventSourceLogger();

// Add Application Insights if connection string is available
var appInsightsConnectionString = builder.Configuration.GetConnectionString("APPLICATIONINSIGHTS_CONNECTION_STRING") 
    ?? builder.Configuration.GetValue<string>("ApplicationInsights:ConnectionString");

if (!string.IsNullOrEmpty(appInsightsConnectionString))
{
    builder.Services.AddApplicationInsightsTelemetry(options =>
    {
        options.ConnectionString = appInsightsConnectionString;
    });
}

// Add services to the container.
builder.Services.AddControllersWithViews();

// Add Web API controllers
builder.Services.AddControllers();

// Add session support
builder.Services.AddSession(options =>
{
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
    options.Cookie.SameSite = SameSiteMode.Lax;
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
    options.IdleTimeout = TimeSpan.FromMinutes(30);
});

// Configure Entity Framework Core
builder.Services.AddDbContext<CatalogDBContext>(options =>
{
    var connectionString = builder.Configuration.GetConnectionString("CatalogDBContext");
    
    if (string.IsNullOrEmpty(connectionString))
    {
        throw new InvalidOperationException("Database connection string 'CatalogDBContext' not found.");
    }
    
    options.UseSqlServer(connectionString, sqlOptions =>
    {
        sqlOptions.EnableRetryOnFailure(
            maxRetryCount: 5,
            maxRetryDelay: TimeSpan.FromSeconds(30),
            errorNumbersToAdd: null);
        sqlOptions.CommandTimeout(120);
    });
    
    // Enable sensitive data logging in development only
    if (builder.Environment.IsDevelopment())
    {
        options.EnableSensitiveDataLogging();
        options.EnableDetailedErrors();
    }
    
    // Add query logging
    options.LogTo(message => System.Diagnostics.Debug.WriteLine(message));
});

// Configure Health Checks
builder.Services.AddHealthChecks()
    .AddCheck<eShopLegacyMVC.HealthChecks.CatalogDbHealthCheck>("catalog_db", tags: new[] { "ready" })
    .AddCheck("self", () => Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Healthy(), tags: new[] { "live" });

// Register application services
RegisterApplicationServices(builder.Services, builder.Configuration);

// Register health check
builder.Services.AddScoped<eShopLegacyMVC.HealthChecks.CatalogDbHealthCheck>();

var app = builder.Build();

// Configure the HTTP request pipeline
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Catalog/Error");
    app.UseStatusCodePagesWithReExecute("/Catalog/StatusErrorCode", "?code={0}");
    app.UseHsts();
}
else
{
    app.UseDeveloperExceptionPage();
}

// Security headers
app.Use(async (context, next) =>
{
    context.Response.Headers.Append("X-Frame-Options", "DENY");
    context.Response.Headers.Append("X-Content-Type-Options", "nosniff");
    context.Response.Headers.Append("X-XSS-Protection", "1; mode=block");
    context.Response.Headers.Append("Referrer-Policy", "strict-origin-when-cross-origin");
    
    if (!app.Environment.IsDevelopment())
    {
        context.Response.Headers.Append("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
    }
    
    await next();
});

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

app.UseSession();

// Health checks
app.MapHealthChecks("/health");
app.MapHealthChecks("/health/ready");
app.MapHealthChecks("/health/live");

// Custom middleware to track session information (converted from Session_Start)
app.Use(async (context, next) =>
{
    if (!context.Session.Keys.Contains("MachineName"))
    {
        context.Session.SetString("MachineName", Environment.MachineName);
        context.Session.SetString("SessionStartTime", DateTime.UtcNow.ToString("O"));
    }
    await next();
});

// Custom middleware for logging (converted from Application_BeginRequest)
app.Use(async (context, next) =>
{
    using var scope = app.Services.CreateScope();
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
    
    // Set correlation properties (equivalent to log4net LogicalThreadContext)
    var activityId = Activity.Current?.Id ?? Guid.NewGuid().ToString();
    var requestInfo = $"{context.Request.Path}, {context.Request.Headers.UserAgent}";
    
    using (logger.BeginScope(new Dictionary<string, object>
    {
        ["ActivityId"] = activityId,
        ["RequestInfo"] = requestInfo,
        ["TraceIdentifier"] = context.TraceIdentifier
    }))
    {
        logger.LogDebug("WebApplication_BeginRequest for {RequestPath}", context.Request.Path);
        await next();
    }
});

// Initialize database with EF Core
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    var logger = services.GetRequiredService<ILogger<Program>>();
    var context = services.GetRequiredService<CatalogDBContext>();
    var mockData = app.Configuration.GetValue<bool>("AppSettings:UseMockData");
    
    try
    {
        logger.LogInformation("Starting database initialization...");
        
        if (!mockData)
        {
            var initializer = services.GetRequiredService<CatalogDBInitializer>();
            await initializer.SeedAsync(context);
            logger.LogInformation("Database initialization completed successfully.");
        }
        else
        {
            // Just ensure the database exists for mock data scenario
            await context.Database.EnsureCreatedAsync();
            logger.LogInformation("Database ensured for mock data scenario.");
        }
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "An error occurred while initializing the database.");
        
        // In production, don't rethrow to prevent startup failure
        // The application can still start and serve requests
        if (app.Environment.IsDevelopment())
        {
            throw;
        }
    }
}

// Map Web API routes (converted from WebApiConfig)
app.MapControllers();

// Map conventional MVC routes
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Catalog}/{action=Index}/{id?}");

// Map API routes
app.MapControllerRoute(
    name: "api",
    pattern: "api/{controller}/{id?}");

app.Run();

static void RegisterApplicationServices(IServiceCollection services, IConfiguration configuration)
{
    var useMockData = configuration.GetValue<bool>("AppSettings:UseMockData");

    // Register catalog service based on configuration
    if (useMockData)
    {
        services.AddSingleton<ICatalogService, CatalogServiceMock>();
    }
    else
    {
        services.AddScoped<ICatalogService, CatalogService>();
    }

    // Register database initializer
    services.AddScoped<CatalogDBInitializer>();
    
    // Keep HiLoGenerator for backward compatibility with existing code that might use it
    services.AddScoped<CatalogItemHiLoGenerator>();
}

// Helper classes for backward compatibility
public class ActivityIdHelper
{
    public override string ToString()
    {
        if (Trace.CorrelationManager.ActivityId == Guid.Empty)
        {
            Trace.CorrelationManager.ActivityId = Guid.NewGuid();
        }

        return Trace.CorrelationManager.ActivityId.ToString();
    }
}

public class WebRequestInfo
{
    private readonly HttpContext _context;

    public WebRequestInfo(HttpContext context)
    {
        _context = context;
    }

    public override string ToString()
    {
        return $"{_context?.Request?.Path}, {_context?.Request?.Headers["User-Agent"]}";
    }
}
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

var builder = WebApplication.CreateBuilder(args);

// Configure ASP.NET Core logging
builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();
builder.Logging.AddEventSourceLogger();

// Add services to the container.
builder.Services.AddControllersWithViews();

// Add Web API controllers
builder.Services.AddControllers();

// Add session support
builder.Services.AddSession();

// Configure Entity Framework Core
builder.Services.AddDbContext<CatalogDBContext>(options =>
{
    options.UseSqlServer(builder.Configuration.GetConnectionString("CatalogDBContext"),
        sqlOptions =>
        {
            sqlOptions.EnableRetryOnFailure(
                maxRetryCount: 5,
                maxRetryDelay: TimeSpan.FromSeconds(30),
                errorNumbersToAdd: null);
        });
    
    // Enable sensitive data logging in development
    if (builder.Environment.IsDevelopment())
    {
        options.EnableSensitiveDataLogging();
        options.EnableDetailedErrors();
    }
});

// Register application services
RegisterApplicationServices(builder.Services, builder.Configuration);

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Catalog/Error"); // Global error handler
    app.UseStatusCodePagesWithReExecute("/Catalog/StatusErrorCode", "?code={0}");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

app.UseSession();

// Custom middleware to track session information (converted from Session_Start)
app.Use(async (context, next) =>
{
    if (!context.Session.Keys.Contains("MachineName"))
    {
        context.Session.SetString("MachineName", Environment.MachineName);
        context.Session.SetString("SessionStartTime", DateTime.Now.ToString());
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
        ["RequestInfo"] = requestInfo
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
        if (!mockData)
        {
            var initializer = services.GetRequiredService<CatalogDBInitializer>();
            initializer.Seed(context);
            logger.LogInformation("Database initialization completed.");
        }
        else
        {
            // Just ensure the database exists for mock data scenario
            context.Database.EnsureCreated();
            logger.LogInformation("Database ensured for mock data scenario.");
        }
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "An error occurred while initializing the database.");
        // In production, you might want to handle this differently
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

    // Register EF Core related services
    services.AddScoped<CatalogItemHiLoGenerator>();
    services.AddScoped<CatalogDBInitializer>();
}

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
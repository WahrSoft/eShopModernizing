using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Autofac;
using Autofac.Extensions.DependencyInjection;
using eShopLegacyMVC.Models;
using eShopLegacyMVC.Models.Infrastructure;
using eShopLegacyMVC.Modules;
using eShopLegacyMVC.Configuration;
using log4net;
using Microsoft.EntityFrameworkCore;
using System.Reflection;
using System.Diagnostics;
using Microsoft.AspNetCore.Http;
using System;
using System.Data.Common;
using Microsoft.Data.SqlClient;

var builder = WebApplication.CreateBuilder(args);

// Configure cache settings
builder.Services.Configure<CacheSettings>(builder.Configuration.GetSection("CacheSettings"));
var cacheSettings = new CacheSettings();
builder.Configuration.GetSection("CacheSettings").Bind(cacheSettings);

// Add Entity Framework Core DbContext
builder.Services.AddDbContext<CatalogDBContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("CatalogDBContext")));

// Add Application Insights telemetry
builder.Services.AddApplicationInsightsTelemetry(options =>
{
    // Configure Application Insights
    options.ConnectionString = builder.Configuration.GetConnectionString("ApplicationInsights");
    options.EnableAdaptiveSampling = true;
    options.EnableQuickPulseMetricStream = true;
    options.EnablePerformanceCounterCollectionModule = true;
    options.EnableDependencyTrackingTelemetryModule = true;
    options.EnableRequestTrackingTelemetryModule = true;
});

// Configure distributed cache based on environment
if (cacheSettings.UseRedis)
{
    var redisConnectionString = builder.Configuration.GetConnectionString("Redis");
    if (!string.IsNullOrEmpty(redisConnectionString))
    {
        builder.Services.AddStackExchangeRedisCache(options =>
        {
            options.Configuration = redisConnectionString;
            options.InstanceName = cacheSettings.InstanceName;
        });
    }
    else
    {
        // Fallback to memory cache if Redis connection string is not configured
        builder.Services.AddDistributedMemoryCache();
        Console.WriteLine("WARNING: Redis is enabled but connection string is missing. Falling back to in-memory cache.");
    }
}
else
{
    // Use in-memory cache for local development
    builder.Services.AddDistributedMemoryCache();
}

// Configure session services
builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromMinutes(cacheSettings.SessionTimeoutMinutes);
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
    options.Cookie.SecurePolicy = builder.Environment.IsDevelopment() 
        ? CookieSecurePolicy.SameAsRequest 
        : CookieSecurePolicy.Always;
});

// Configure Autofac
builder.Host.UseServiceProviderFactory(new AutofacServiceProviderFactory());
builder.Host.ConfigureContainer<ContainerBuilder>(containerBuilder =>
{
    var thisAssembly = Assembly.GetExecutingAssembly();
    
    var mockData = bool.Parse(builder.Configuration["UseMockData"] ?? "false");
    containerBuilder.RegisterModule(new ApplicationModule(mockData));
});

builder.Services.AddSystemWebAdapters()
    .AddWrappedAspNetCoreSession()
    .AddJsonSessionSerializer(options =>
    {
        options.RegisterKey<string>("MachineName");
        options.RegisterKey<string>("SessionStartTime");
    });

// Add services to the container.
builder.Services.AddControllersWithViews();

var app = builder.Build();

// Log cache configuration on startup
var appLogger = app.Services.GetService<ILogger<Program>>();
if (cacheSettings.UseRedis)
{
    appLogger?.LogInformation("Application configured to use Redis distributed cache");
}
else
{
    appLogger?.LogInformation("Application configured to use in-memory distributed cache");
}

// Configure database initialization for EF Core
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    var configuration = services.GetRequiredService<IConfiguration>();
    var mockData = bool.Parse(configuration["UseMockData"] ?? "false");
    
    if (!mockData)
    {
        try
        {
            var catalogContext = services.GetRequiredService<CatalogDBContext>();
            
            // Ensure the database is created and apply any pending migrations
            catalogContext.Database.EnsureCreated();
            
            // Run database seeding if needed
            var catalogInitializer = services.GetRequiredService<CatalogDBInitializer>();
            catalogInitializer.Seed(catalogContext);
        }
        catch (Exception ex)
        {
            appLogger?.LogError(ex, "An error occurred while seeding the database.");
        }
    }
}

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}
else
{
    app.UseDeveloperExceptionPage();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

// Add session middleware BEFORE accessing session
app.UseSession();
app.UseSystemWebAdapters();

// Custom middleware for session tracking (replaces Session_Start)
app.Use(async (context, next) =>
{
    if (context.Session.GetString("MachineName") == null)
    {
        context.Session.SetString("MachineName", Environment.MachineName);
        context.Session.SetString("SessionStartTime", DateTime.Now.ToString());
    }
    await next();
});

// Custom middleware for logging (replaces Application_BeginRequest)
app.Use(async (context, next) =>
{
    var _log = LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);
    
    // Set activity ID for correlation
    if (Trace.CorrelationManager.ActivityId == Guid.Empty)
    {
        Trace.CorrelationManager.ActivityId = Guid.NewGuid();
    }
    
    LogicalThreadContext.Properties["activityid"] = Trace.CorrelationManager.ActivityId.ToString();
    LogicalThreadContext.Properties["requestinfo"] = $"{context.Request.Path}, {context.Request.Headers["User-Agent"]}";
    
    _log.Debug("WebApplication_BeginRequest");
    
    await next();
});

app.MapControllers();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Catalog}/{action=Index}/{id?}");


app.Run();
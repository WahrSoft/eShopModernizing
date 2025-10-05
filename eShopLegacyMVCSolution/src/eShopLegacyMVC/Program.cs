using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;
using Autofac;
using Autofac.Extensions.DependencyInjection;
using eShopLegacyMVC.Models;
using eShopLegacyMVC.Models.Infrastructure;
using eShopLegacyMVC.Modules;
using log4net;
using System.Data.Entity;
using System.Reflection;
using System.Diagnostics;
using Microsoft.AspNetCore.Http;
using System;

var builder = WebApplication.CreateBuilder(args);

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

// Configure session services
builder.Services.AddDistributedMemoryCache();
builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromMinutes(30);
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
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

// Configure database
using (var scope = app.Services.CreateScope())
{
    var configuration = scope.ServiceProvider.GetRequiredService<IConfiguration>();
    var mockData = bool.Parse(configuration["UseMockData"] ?? "false");
    if (!mockData)
    {
        var dbInitializer = scope.ServiceProvider.GetRequiredService<CatalogDBInitializer>();
        Database.SetInitializer<CatalogDBContext>(dbInitializer);
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
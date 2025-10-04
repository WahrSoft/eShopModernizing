using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;
using eShopLegacyMVC.Models;
using eShopLegacyMVC.Models.Infrastructure;
using eShopLegacyMVC.Services;
using System.Data.Entity;
using log4net;
using System.Reflection;
using System.Diagnostics;
using Microsoft.AspNetCore.Http;
using System;
using System.IO;
using System.Linq;
using eShopLegacyMVC;

var builder = WebApplication.CreateBuilder(args);

// Configure log4net
var logRepository = LogManager.GetRepository(Assembly.GetEntryAssembly());
log4net.Config.XmlConfigurator.Configure(logRepository, new FileInfo("log4net.config"));

// Add services to the container.
builder.Services.AddControllersWithViews();

// Add Web API controllers
builder.Services.AddControllers();

// Add session support
builder.Services.AddSession();

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
    LogicalThreadContext.Properties["activityid"] = new ActivityIdHelper();
    LogicalThreadContext.Properties["requestinfo"] = new WebRequestInfo(context);

    var log = LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);
    log.Debug("WebApplication_BeginRequest");

    await next();
});

// Initialize database
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    var mockData = app.Configuration.GetValue<bool>("AppSettings:UseMockData");
    if (!mockData)
    {
        Database.SetInitializer(services.GetRequiredService<CatalogDBInitializer>());
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

    // Register EntityFramework DbContext
    services.AddScoped<CatalogDBContext>(provider =>
        new CatalogDBContext($"name={configuration.GetConnectionString("CatalogDBContext")}"));

    // Register initializer and its dependencies
    services.AddSingleton<CatalogItemHiLoGenerator>();
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
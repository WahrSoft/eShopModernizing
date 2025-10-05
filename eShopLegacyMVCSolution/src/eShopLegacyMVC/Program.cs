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

var builder = WebApplication.CreateBuilder(args);

// Configure Autofac
builder.Host.UseServiceProviderFactory(new AutofacServiceProviderFactory());
builder.Host.ConfigureContainer<ContainerBuilder>(containerBuilder =>
{
    var thisAssembly = Assembly.GetExecutingAssembly();
    containerBuilder.RegisterControllers(thisAssembly);
    
    var mockData = bool.Parse(builder.Configuration["UseMockData"] ?? "false");
    containerBuilder.RegisterModule(new ApplicationModule(mockData));
});

builder.Services.AddSystemWebAdapters()
    .AddWrappedAspNetCoreSession()
    .AddJsonSessionSerializer(options =>
    {
        options.RegisterKey<string>("MachineName");
        options.RegisterKey<string>("SessionStartTime");
    })
    .AddHttpApplication<MvcApplication>();

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
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

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

app.UseSession();
app.UseSystemWebAdapters();

app.MapControllers()
    .RequireSystemWebAdapterSession();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Catalog}/{action=Index}/{id?}")
    .RequireSystemWebAdapterSession();

app.Run();
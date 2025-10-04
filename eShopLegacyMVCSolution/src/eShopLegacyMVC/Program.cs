using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;
using eShopLegacyMVC.Models;
using eShopLegacyMVC.Models.Infrastructure;
using eShopLegacyMVC.Services;
using System.Data.Entity;

var builder = WebApplication.CreateBuilder(args);
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
app.UseSystemWebAdapters();

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

// Map attribute-routed controllers first
app.MapControllers()
    .RequireSystemWebAdapterSession();

// Map conventional MVC routes
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Catalog}/{action=Index}/{id?}")
    .RequireSystemWebAdapterSession();

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
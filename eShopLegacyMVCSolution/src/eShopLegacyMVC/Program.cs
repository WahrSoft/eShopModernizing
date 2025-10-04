using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;
using eShopLegacyMVC.Models;
using eShopLegacyMVC.Models.Infrastructure;
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

// Register EntityFramework DbContext
builder.Services.AddScoped<CatalogDBContext>(provider =>
    new CatalogDBContext($"name={builder.Configuration.GetConnectionString("CatalogDBContext")}"));

// Register initializer and its dependencies
builder.Services.AddScoped<CatalogItemHiLoGenerator>();
builder.Services.AddScoped<CatalogDBInitializer>();

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
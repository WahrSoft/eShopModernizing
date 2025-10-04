using Microsoft.EntityFrameworkCore;
using eShopModernized.Data;
using eShopModernized.Services;
using Azure.Identity;
using Microsoft.Extensions.Azure;
using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container

// Configure JSON serialization
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
    options.SerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
    options.SerializerOptions.Converters.Add(new JsonStringEnumConverter());
});

// Database Configuration
builder.Services.AddDbContext<CatalogDbContext>(options =>
{
    var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
    options.UseSqlServer(connectionString, sqlOptions =>
    {
        sqlOptions.EnableRetryOnFailure(
            maxRetryCount: 3,
            maxRetryDelay: TimeSpan.FromSeconds(5),
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
builder.Services.AddScoped<ICatalogService, CatalogService>();
builder.Services.AddSingleton<JsonSerializationService>();
builder.Services.AddScoped<IBlobStorageService, BlobStorageService>();

// Session State with Redis (for production)
if (!builder.Environment.IsDevelopment())
{
    builder.Services.AddStackExchangeRedisCache(options =>
    {
        options.Configuration = builder.Configuration.GetConnectionString("Redis");
        options.InstanceName = "eShopModernized";
    });
}
else
{
    // Use in-memory cache for development
    builder.Services.AddMemoryCache();
}

builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromMinutes(30);
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
    options.Cookie.SameSite = SameSiteMode.Strict;
    options.Cookie.SecurePolicy = CookieSecurePolicy.SameAsRequest;
});

// Azure Services Configuration
builder.Services.AddAzureClients(clientBuilder =>
{
    // Use Managed Identity for Azure services
    clientBuilder.UseCredential(new DefaultAzureCredential());
    
    // Add Application Insights if configured
    var aiConnectionString = builder.Configuration.GetConnectionString("ApplicationInsights");
    if (!string.IsNullOrEmpty(aiConnectionString))
    {
        clientBuilder.AddApplicationInsightsConfiguration(options =>
        {
            options.ConnectionString = aiConnectionString;
        });
    }
});

// Application Insights
if (!string.IsNullOrEmpty(builder.Configuration["ApplicationInsights:InstrumentationKey"]))
{
    builder.Services.AddApplicationInsightsTelemetry(options =>
    {
        options.InstrumentationKey = builder.Configuration["ApplicationInsights:InstrumentationKey"];
        options.EnableAdaptiveSampling = true;
        options.EnableQuickPulseMetricStream = true;
    });
}

// Health Checks
builder.Services.AddHealthChecks()
    .AddDbContext<CatalogDbContext>(name: "database")
    .AddSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection")!,
        name: "sqlserver");

// Add Redis health check for production
if (!builder.Environment.IsDevelopment())
{
    builder.Services.AddHealthChecks()
        .AddRedis(builder.Configuration.GetConnectionString("Redis")!, name: "redis");
}

// API Controllers
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
        options.JsonSerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
        options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
    });

// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { 
        Title = "eShop Modernized API", 
        Version = "v1",
        Description = "Modernized eShop Catalog API built with .NET 8 and Azure PaaS services"
    });
    
    // Include XML comments if available
    var xmlFile = $"{System.Reflection.Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    if (File.Exists(xmlPath))
    {
        c.IncludeXmlComments(xmlPath);
    }
});

// CORS Configuration
builder.Services.AddCors(options =>
{
    options.AddPolicy("DefaultPolicy", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

// Security Headers
builder.Services.AddHsts(options =>
{
    options.Preload = true;
    options.IncludeSubDomains = true;
    options.MaxAge = TimeSpan.FromDays(365);
});

var app = builder.Build();

// Configure the HTTP request pipeline

// Security headers
app.UseHsts();
app.UseHttpsRedirection();

// Enable session
app.UseSession();

// CORS
app.UseCors("DefaultPolicy");

// API Documentation
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "eShop Modernized API v1");
        c.RoutePrefix = string.Empty; // Set Swagger UI at the app's root
    });
    
    app.UseDeveloperExceptionPage();
}

// Health Checks
app.MapHealthChecks("/health", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
{
    ResponseWriter = async (context, report) =>
    {
        context.Response.ContentType = "application/json";
        var response = System.Text.Json.JsonSerializer.Serialize(new
        {
            status = report.Status.ToString(),
            checks = report.Entries.Select(entry => new
            {
                name = entry.Key,
                status = entry.Value.Status.ToString(),
                exception = entry.Value.Exception?.Message,
                duration = entry.Value.Duration.ToString()
            })
        });
        await context.Response.WriteAsync(response);
    }
});

// API Controllers
app.MapControllers();

// Database Migration and Seeding
using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<CatalogDbContext>();
    
    if (app.Environment.IsDevelopment())
    {
        // Auto-migrate in development
        await context.Database.MigrateAsync();
    }
    else
    {
        // Check if database exists and is up to date in production
        var pendingMigrations = await context.Database.GetPendingMigrationsAsync();
        if (pendingMigrations.Any())
        {
            app.Logger.LogWarning("Database has pending migrations: {Migrations}", 
                string.Join(", ", pendingMigrations));
        }
    }
}

app.Logger.LogInformation("eShop Modernized API started successfully");

app.Run();
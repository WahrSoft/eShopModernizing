using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.EntityFrameworkCore;
using eShopLegacyMVC.Models;
using System.Threading;
using System.Threading.Tasks;
using System;

namespace eShopLegacyMVC.HealthChecks
{
    public class CatalogDbHealthCheck : IHealthCheck
    {
        private readonly CatalogDBContext _context;

        public CatalogDbHealthCheck(CatalogDBContext context)
        {
            _context = context;
        }

        public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
        {
            try
            {
                // Try to connect to the database and perform a simple query
                await _context.Database.CanConnectAsync(cancellationToken);
                
                // Check if we can query the catalog items table
                var count = await _context.CatalogItems.CountAsync(cancellationToken);
                
                return HealthCheckResult.Healthy($"Database is healthy. Contains {count} catalog items.");
            }
            catch (Exception ex)
            {
                return HealthCheckResult.Unhealthy($"Database is unhealthy: {ex.Message}", ex);
            }
        }
    }
}
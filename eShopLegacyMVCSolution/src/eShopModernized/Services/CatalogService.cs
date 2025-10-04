using Microsoft.EntityFrameworkCore;
using eShopModernized.Data;
using eShopModernized.Models;
using eShopModernized.ViewModels;

namespace eShopModernized.Services;

public class CatalogService : ICatalogService
{
    private readonly CatalogDbContext _context;
    private readonly ILogger<CatalogService> _logger;

    public CatalogService(CatalogDbContext context, ILogger<CatalogService> logger)
    {
        _context = context ?? throw new ArgumentNullException(nameof(context));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public async Task<PaginatedItemsViewModel<CatalogItem>> GetCatalogItemsPaginatedAsync(
        int pageSize, 
        int pageIndex, 
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Retrieving catalog items page {PageIndex} with size {PageSize}", pageIndex, pageSize);

        var totalItems = await _context.CatalogItems.LongCountAsync(cancellationToken);

        var itemsOnPage = await _context.CatalogItems
            .Include(c => c.CatalogBrand)
            .Include(c => c.CatalogType)
            .OrderBy(c => c.Id)
            .Skip(pageSize * pageIndex)
            .Take(pageSize)
            .AsNoTracking()
            .ToListAsync(cancellationToken);

        return new PaginatedItemsViewModel<CatalogItem>(
            pageIndex, pageSize, totalItems, itemsOnPage);
    }

    public async Task<CatalogItem?> FindCatalogItemAsync(int id, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Finding catalog item with ID {CatalogItemId}", id);

        return await _context.CatalogItems
            .Include(c => c.CatalogBrand)
            .Include(c => c.CatalogType)
            .AsNoTracking()
            .FirstOrDefaultAsync(ci => ci.Id == id, cancellationToken);
    }

    public async Task<IEnumerable<CatalogType>> GetCatalogTypesAsync(CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Retrieving all catalog types");

        return await _context.CatalogTypes
            .AsNoTracking()
            .OrderBy(ct => ct.Type)
            .ToListAsync(cancellationToken);
    }

    public async Task<IEnumerable<CatalogBrand>> GetCatalogBrandsAsync(CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Retrieving all catalog brands");

        return await _context.CatalogBrands
            .AsNoTracking()
            .OrderBy(cb => cb.Brand)
            .ToListAsync(cancellationToken);
    }

    public async Task<CatalogItem> CreateCatalogItemAsync(CatalogItem catalogItem, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(catalogItem);

        _logger.LogInformation("Creating new catalog item: {CatalogItemName}", catalogItem.Name);

        _context.CatalogItems.Add(catalogItem);
        await _context.SaveChangesAsync(cancellationToken);

        return catalogItem;
    }

    public async Task<CatalogItem> UpdateCatalogItemAsync(CatalogItem catalogItem, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(catalogItem);

        _logger.LogInformation("Updating catalog item with ID {CatalogItemId}", catalogItem.Id);

        _context.Entry(catalogItem).State = EntityState.Modified;
        await _context.SaveChangesAsync(cancellationToken);

        return catalogItem;
    }

    public async Task<bool> RemoveCatalogItemAsync(int id, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Removing catalog item with ID {CatalogItemId}", id);

        var catalogItem = await _context.CatalogItems.FindAsync(new object[] { id }, cancellationToken);
        if (catalogItem == null)
        {
            _logger.LogWarning("Catalog item with ID {CatalogItemId} not found for removal", id);
            return false;
        }

        _context.CatalogItems.Remove(catalogItem);
        await _context.SaveChangesAsync(cancellationToken);

        return true;
    }

    public async Task<IEnumerable<CatalogItem>> GetCatalogItemsByBrandAsync(int brandId, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Retrieving catalog items for brand ID {BrandId}", brandId);

        return await _context.CatalogItems
            .Include(c => c.CatalogBrand)
            .Include(c => c.CatalogType)
            .Where(c => c.CatalogBrandId == brandId)
            .AsNoTracking()
            .ToListAsync(cancellationToken);
    }

    public async Task<IEnumerable<CatalogItem>> GetCatalogItemsByTypeAsync(int typeId, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Retrieving catalog items for type ID {TypeId}", typeId);

        return await _context.CatalogItems
            .Include(c => c.CatalogBrand)
            .Include(c => c.CatalogType)
            .Where(c => c.CatalogTypeId == typeId)
            .AsNoTracking()
            .ToListAsync(cancellationToken);
    }
}
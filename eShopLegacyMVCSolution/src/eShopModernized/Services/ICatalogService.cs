using eShopModernized.Models;
using eShopModernized.ViewModels;

namespace eShopModernized.Services;

public interface ICatalogService
{
    Task<PaginatedItemsViewModel<CatalogItem>> GetCatalogItemsPaginatedAsync(int pageSize, int pageIndex, CancellationToken cancellationToken = default);
    Task<CatalogItem?> FindCatalogItemAsync(int id, CancellationToken cancellationToken = default);
    Task<IEnumerable<CatalogType>> GetCatalogTypesAsync(CancellationToken cancellationToken = default);
    Task<IEnumerable<CatalogBrand>> GetCatalogBrandsAsync(CancellationToken cancellationToken = default);
    Task<CatalogItem> CreateCatalogItemAsync(CatalogItem catalogItem, CancellationToken cancellationToken = default);
    Task<CatalogItem> UpdateCatalogItemAsync(CatalogItem catalogItem, CancellationToken cancellationToken = default);
    Task<bool> RemoveCatalogItemAsync(int id, CancellationToken cancellationToken = default);
    Task<IEnumerable<CatalogItem>> GetCatalogItemsByBrandAsync(int brandId, CancellationToken cancellationToken = default);
    Task<IEnumerable<CatalogItem>> GetCatalogItemsByTypeAsync(int typeId, CancellationToken cancellationToken = default);
}
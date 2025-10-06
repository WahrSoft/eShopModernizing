using System.Collections.Generic;
using eShopLegacyMVC.Models;
using System;
using eShopLegacyMVC.ViewModel;
using System.Threading.Tasks;

namespace eShopLegacyMVC.Services
{
    public interface ICatalogService : IDisposable
    {
        CatalogItem FindCatalogItem(int id);
        Task<CatalogItem> FindCatalogItemAsync(int id);
        
        CatalogBrand FindCatalogBrand(int id);
        Task<CatalogBrand> FindCatalogBrandAsync(int id);
        
        CatalogType FindCatalogType(int id);
        Task<CatalogType> FindCatalogTypeAsync(int id);
        
        IEnumerable<CatalogBrand> GetCatalogBrands();
        Task<IEnumerable<CatalogBrand>> GetCatalogBrandsAsync();
        
        PaginatedItemsViewModel<CatalogItem> GetCatalogItemsPaginated(int pageSize, int pageIndex);
        Task<PaginatedItemsViewModel<CatalogItem>> GetCatalogItemsPaginatedAsync(int pageSize, int pageIndex);
        
        IEnumerable<CatalogType> GetCatalogTypes();
        Task<IEnumerable<CatalogType>> GetCatalogTypesAsync();
        
        void CreateCatalogItem(CatalogItem catalogItem);
        Task CreateCatalogItemAsync(CatalogItem catalogItem);
        
        void UpdateCatalogItem(CatalogItem catalogItem);
        Task UpdateCatalogItemAsync(CatalogItem catalogItem);
        
        void RemoveCatalogItem(CatalogItem catalogItem);
        Task RemoveCatalogItemAsync(CatalogItem catalogItem);
    }
}
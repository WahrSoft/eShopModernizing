using System;
using System.Collections.Generic;
using System.Linq;
using eShopLegacyMVC.Models;
using eShopLegacyMVC.Models.Infrastructure;
using eShopLegacyMVC.ViewModel;
using System.Threading.Tasks;

namespace eShopLegacyMVC.Services
{
    public class CatalogServiceMock : ICatalogService
    {
        private List<CatalogItem> catalogItems;

        public CatalogServiceMock()
        {
            catalogItems = new List<CatalogItem>(PreconfiguredData.GetPreconfiguredCatalogItems());
        }

        public PaginatedItemsViewModel<CatalogItem> GetCatalogItemsPaginated(int pageSize = 10, int pageIndex = 0)
        {
            var items = ComposeCatalogItems(catalogItems);
            
            var itemsOnPage = items
                .OrderBy(c => c.Id)
                .Skip(pageSize * pageIndex)
                .Take(pageSize)
                .ToList();

            return new PaginatedItemsViewModel<CatalogItem>(
                pageIndex, pageSize, items.Count, itemsOnPage);
        }

        public async Task<PaginatedItemsViewModel<CatalogItem>> GetCatalogItemsPaginatedAsync(int pageSize = 10, int pageIndex = 0)
        {
            return await Task.FromResult(GetCatalogItemsPaginated(pageSize, pageIndex));
        }

        public CatalogItem FindCatalogItem(int id)
        {
            return catalogItems.FirstOrDefault(x => x.Id == id);
        }

        public async Task<CatalogItem> FindCatalogItemAsync(int id)
        {
            return await Task.FromResult(FindCatalogItem(id));
        }

        public CatalogBrand FindCatalogBrand(int id)
        {
            return PreconfiguredData.GetPreconfiguredCatalogBrands().FirstOrDefault(x => x.Id == id);
        }

        public async Task<CatalogBrand> FindCatalogBrandAsync(int id)
        {
            return await Task.FromResult(FindCatalogBrand(id));
        }

        public CatalogType FindCatalogType(int id)
        {
            return PreconfiguredData.GetPreconfiguredCatalogTypes().FirstOrDefault(x => x.Id == id);
        }

        public async Task<CatalogType> FindCatalogTypeAsync(int id)
        {
            return await Task.FromResult(FindCatalogType(id));
        }

        public IEnumerable<CatalogType> GetCatalogTypes()
        {
            return PreconfiguredData.GetPreconfiguredCatalogTypes();
        }

        public async Task<IEnumerable<CatalogType>> GetCatalogTypesAsync()
        {
            return await Task.FromResult(GetCatalogTypes());
        }

        public IEnumerable<CatalogBrand> GetCatalogBrands()
        {
            return PreconfiguredData.GetPreconfiguredCatalogBrands();
        }

        public async Task<IEnumerable<CatalogBrand>> GetCatalogBrandsAsync()
        {
            return await Task.FromResult(GetCatalogBrands());
        }

        public void CreateCatalogItem(CatalogItem catalogItem)
        {
            var maxId = catalogItems.Max(i => i.Id);
            catalogItem.Id = ++maxId;
            catalogItems.Add(catalogItem);
        }

        public async Task CreateCatalogItemAsync(CatalogItem catalogItem)
        {
            CreateCatalogItem(catalogItem);
            await Task.CompletedTask;
        }

        public void UpdateCatalogItem(CatalogItem modifiedItem)
        {
            var originalItem = FindCatalogItem(modifiedItem.Id);
            if (originalItem != null)
            {
                catalogItems[catalogItems.IndexOf(originalItem)] = modifiedItem;
            }
        }

        public async Task UpdateCatalogItemAsync(CatalogItem modifiedItem)
        {
            UpdateCatalogItem(modifiedItem);
            await Task.CompletedTask;
        }

        public void RemoveCatalogItem(CatalogItem catalogItem)
        {
            catalogItems.Remove(catalogItem);
        }

        public async Task RemoveCatalogItemAsync(CatalogItem catalogItem)
        {
            RemoveCatalogItem(catalogItem);
            await Task.CompletedTask;
        }

        public void Dispose()
        {
        }

        private List<CatalogItem> ComposeCatalogItems(List<CatalogItem> items)
        {
            var catalogTypes = PreconfiguredData.GetPreconfiguredCatalogTypes();
            var catalogBrands = PreconfiguredData.GetPreconfiguredCatalogBrands();
            items.ForEach(i => i.CatalogBrand = catalogBrands.First(b => b.Id == i.CatalogBrandId));
            items.ForEach(i => i.CatalogType = catalogTypes.First(b => b.Id == i.CatalogTypeId));

            return items;
        }
    }
}
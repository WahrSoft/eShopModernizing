using eShopLegacyMVC.Models;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore;
using System.Linq;
using eShopLegacyMVC.ViewModel;
using System.Threading.Tasks;

namespace eShopLegacyMVC.Services
{

    public class CatalogService : ICatalogService
    {
        private CatalogDBContext db;
        private CatalogItemHiLoGenerator indexGenerator;

        public CatalogService(CatalogDBContext db, CatalogItemHiLoGenerator indexGenerator)
        {
            this.db = db;
            this.indexGenerator = indexGenerator;
        }

        public PaginatedItemsViewModel<CatalogItem> GetCatalogItemsPaginated(int pageSize, int pageIndex)
        {
            var totalItems = db.CatalogItems.LongCount();

            var itemsOnPage = db.CatalogItems
                .Include(c => c.CatalogBrand)
                .Include(c => c.CatalogType)
                .OrderBy(c => c.Id)
                .Skip(pageSize * pageIndex)
                .Take(pageSize)
                .ToList();

            return new PaginatedItemsViewModel<CatalogItem>(
                pageIndex, pageSize, totalItems, itemsOnPage);
        }

        public async Task<PaginatedItemsViewModel<CatalogItem>> GetCatalogItemsPaginatedAsync(int pageSize, int pageIndex)
        {
            var totalItems = await db.CatalogItems.LongCountAsync();

            var itemsOnPage = await db.CatalogItems
                .Include(c => c.CatalogBrand)
                .Include(c => c.CatalogType)
                .OrderBy(c => c.Id)
                .Skip(pageSize * pageIndex)
                .Take(pageSize)
                .ToListAsync();

            return new PaginatedItemsViewModel<CatalogItem>(
                pageIndex, pageSize, totalItems, itemsOnPage);
        }

        public CatalogItem FindCatalogItem(int id)
        {
            return db.CatalogItems.Include(c => c.CatalogBrand).Include(c => c.CatalogType).FirstOrDefault(ci => ci.Id == id);
        }

        public async Task<CatalogItem> FindCatalogItemAsync(int id)
        {
            return await db.CatalogItems
                .Include(c => c.CatalogBrand)
                .Include(c => c.CatalogType)
                .FirstOrDefaultAsync(ci => ci.Id == id);
        }

        public CatalogBrand FindCatalogBrand(int id)
        {
            return db.CatalogBrands.FirstOrDefault(cb => cb.Id == id);
        }

        public async Task<CatalogBrand> FindCatalogBrandAsync(int id)
        {
            return await db.CatalogBrands.FirstOrDefaultAsync(cb => cb.Id == id);
        }

        public CatalogType FindCatalogType(int id)
        {
            return db.CatalogTypes.FirstOrDefault(ct => ct.Id == id);
        }

        public async Task<CatalogType> FindCatalogTypeAsync(int id)
        {
            return await db.CatalogTypes.FirstOrDefaultAsync(ct => ct.Id == id);
        }

        public IEnumerable<CatalogType> GetCatalogTypes()
        {
            return db.CatalogTypes;
        }

        public async Task<IEnumerable<CatalogType>> GetCatalogTypesAsync()
        {
            return await db.CatalogTypes.ToListAsync();
        }

        public IEnumerable<CatalogBrand> GetCatalogBrands()
        {
            return db.CatalogBrands;
        }

        public async Task<IEnumerable<CatalogBrand>> GetCatalogBrandsAsync()
        {
            return await db.CatalogBrands.ToListAsync();
        }

        public void CreateCatalogItem(CatalogItem catalogItem)
        {
            catalogItem.Id = indexGenerator.GetNextSequenceValue(db);
            db.CatalogItems.Add(catalogItem);
            db.SaveChanges();
        }

        public async Task CreateCatalogItemAsync(CatalogItem catalogItem)
        {
            catalogItem.Id = indexGenerator.GetNextSequenceValue(db);
            db.CatalogItems.Add(catalogItem);
            await db.SaveChangesAsync();
        }

        public void UpdateCatalogItem(CatalogItem catalogItem)
        {
            db.Entry(catalogItem).State = EntityState.Modified;
            db.SaveChanges();
        }

        public async Task UpdateCatalogItemAsync(CatalogItem catalogItem)
        {
            db.Entry(catalogItem).State = EntityState.Modified;
            await db.SaveChangesAsync();
        }

        public void RemoveCatalogItem(CatalogItem catalogItem)
        {
            db.CatalogItems.Remove(catalogItem);
            db.SaveChanges();
        }

        public async Task RemoveCatalogItemAsync(CatalogItem catalogItem)
        {
            db.CatalogItems.Remove(catalogItem);
            await db.SaveChangesAsync();
        }

        public void Dispose()
        {
            db.Dispose();
        }
    }
}
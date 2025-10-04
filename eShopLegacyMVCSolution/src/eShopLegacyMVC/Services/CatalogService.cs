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
        private readonly CatalogDBContext _db;
        private readonly CatalogItemHiLoGenerator _indexGenerator;

        public CatalogService(CatalogDBContext db, CatalogItemHiLoGenerator indexGenerator)
        {
            _db = db;
            _indexGenerator = indexGenerator;
        }

        public PaginatedItemsViewModel<CatalogItem> GetCatalogItemsPaginated(int pageSize, int pageIndex)
        {
            var totalItems = _db.CatalogItems.LongCount();

            var itemsOnPage = _db.CatalogItems
                .Include(c => c.CatalogBrand)
                .Include(c => c.CatalogType)
                .OrderBy(c => c.Id)
                .Skip(pageSize * pageIndex)
                .Take(pageSize)
                .ToList();

            return new PaginatedItemsViewModel<CatalogItem>(
                pageIndex, pageSize, totalItems, itemsOnPage);
        }

        public CatalogItem FindCatalogItem(int id)
        {
            return _db.CatalogItems
                .Include(c => c.CatalogBrand)
                .Include(c => c.CatalogType)
                .FirstOrDefault(ci => ci.Id == id);
        }

        public IEnumerable<CatalogType> GetCatalogTypes()
        {
            return _db.CatalogTypes.ToList();
        }

        public IEnumerable<CatalogBrand> GetCatalogBrands()
        {
            return _db.CatalogBrands.ToList();
        }

        public void CreateCatalogItem(CatalogItem catalogItem)
        {
            catalogItem.Id = _indexGenerator.GetNextSequenceValue(_db);
            _db.CatalogItems.Add(catalogItem);
            _db.SaveChanges();
        }

        public void UpdateCatalogItem(CatalogItem catalogItem)
        {
            _db.Entry(catalogItem).State = EntityState.Modified;
            _db.SaveChanges();
        }

        public void RemoveCatalogItem(CatalogItem catalogItem)
        {
            _db.CatalogItems.Remove(catalogItem);
            _db.SaveChanges();
        }

        public void Dispose()
        {
            _db.Dispose();
        }
    }
}
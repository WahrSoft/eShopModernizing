using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Options;
using eShopLegacyMVC.Models;
using eShopLegacyMVC.Services;
using eShopLegacyMVC.Configuration;
using log4net;
using Microsoft.AspNetCore.Http;

namespace eShopLegacyMVC.Controllers
{
    public class CatalogController : Controller
    {
        private static readonly ILog _log = LogManager.GetLogger(System.Reflection.MethodBase.GetCurrentMethod().DeclaringType);

        private ICatalogService service;
        private readonly IDistributedCache _distributedCache;
        private readonly CacheSettings _cacheSettings;

        public CatalogController(ICatalogService service, IDistributedCache distributedCache, IOptions<CacheSettings> cacheSettings)
        {
            this.service = service;
            _distributedCache = distributedCache;
            _cacheSettings = cacheSettings.Value;
        }

        // GET: Catalog/CacheStatus - Test endpoint to verify cache configuration
        public IActionResult CacheStatus()
        {
            var cacheInfo = new
            {
                CacheType = _cacheSettings.UseRedis ? "Redis" : "In-Memory",
                InstanceName = _cacheSettings.InstanceName,
                SessionTimeoutMinutes = _cacheSettings.SessionTimeoutMinutes,
                CacheImplementation = _distributedCache.GetType().Name,
                SessionId = HttpContext.Session.Id,
                MachineName = HttpContext.Session.GetString("MachineName"),
                SessionStartTime = HttpContext.Session.GetString("SessionStartTime")
            };

            return Json(cacheInfo);
        }

        // GET /[?pageSize=3&pageIndex=10]
        public async Task<IActionResult> Index(int pageSize = 10, int pageIndex = 0)
        {
            _log.Info($"Now loading... /Catalog/Index?pageSize={pageSize}&pageIndex={pageIndex}");
            var paginatedItems = await service.GetCatalogItemsPaginatedAsync(pageSize, pageIndex);
            ChangeUriPlaceholder(paginatedItems.Data);
            return View(paginatedItems);
        }

        // GET: Catalog/Details/5
        public async Task<IActionResult> Details(int? id)
        {
            _log.Info($"Now loading... /Catalog/Details?id={id}");
            if (id == null)
            {
                return BadRequest();
            }
            CatalogItem catalogItem = await service.FindCatalogItemAsync(id.Value);
            if (catalogItem == null)
            {
                return NotFound();
            }
            AddUriPlaceHolder(catalogItem);

            return View(catalogItem);
        }

        // GET: Catalog/Create
        public async Task<IActionResult> Create()
        {
            _log.Info($"Now loading... /Catalog/Create");
            ViewBag.CatalogBrandId = new SelectList(await service.GetCatalogBrandsAsync(), "Id", "Brand");
            ViewBag.CatalogTypeId = new SelectList(await service.GetCatalogTypesAsync(), "Id", "Type");
            return View(new CatalogItem());
        }

        // POST: Catalog/Create
        // To protect from overposting attacks, please enable the specific properties you want to bind to, for 
        // more details see https://go.microsoft.com/fwlink/?LinkId=317598.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create([Bind("Id,Name,Description,Price,PictureFileName,CatalogTypeId,CatalogBrandId,AvailableStock,RestockThreshold,MaxStockThreshold,OnReorder")] CatalogItem catalogItem)
        {
            _log.Info($"Now processing... /Catalog/Create?catalogItemName={catalogItem.Name}");
            if (ModelState.IsValid)
            {
                await service.CreateCatalogItemAsync(catalogItem);
                return RedirectToAction("Index");
            }

            ViewBag.CatalogBrandId = new SelectList(await service.GetCatalogBrandsAsync(), "Id", "Brand", catalogItem.CatalogBrandId);
            ViewBag.CatalogTypeId = new SelectList(await service.GetCatalogTypesAsync(), "Id", "Type", catalogItem.CatalogTypeId);
            return View(catalogItem);
        }

        // GET: Catalog/Edit/5
        public async Task<IActionResult> Edit(int? id)
        {
            _log.Info($"Now loading... /Catalog/Edit?id={id}");
            if (id == null)
            {
                return BadRequest();
            }
            CatalogItem catalogItem = await service.FindCatalogItemAsync(id.Value);
            if (catalogItem == null)
            {
                return NotFound();
            }
            AddUriPlaceHolder(catalogItem);
            ViewBag.CatalogBrandId = new SelectList(await service.GetCatalogBrandsAsync(), "Id", "Brand", catalogItem.CatalogBrandId);
            ViewBag.CatalogTypeId = new SelectList(await service.GetCatalogTypesAsync(), "Id", "Type", catalogItem.CatalogTypeId);
            return View(catalogItem);
        }

        // POST: Catalog/Edit/5
        // To protect from overposting attacks, please enable the specific properties you want to bind to, for 
        // more details see https://go.microsoft.com/fwlink/?LinkId=317598.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit([Bind("Id,Name,Description,Price,PictureFileName,CatalogTypeId,CatalogBrandId,AvailableStock,RestockThreshold,MaxStockThreshold,OnReorder")] CatalogItem catalogItem)
        {
            _log.Info($"Now processing... /Catalog/Edit?id={catalogItem.Id}");
            if (ModelState.IsValid)
            {
                await service.UpdateCatalogItemAsync(catalogItem);
                return RedirectToAction("Index");
            }
            ViewBag.CatalogBrandId = new SelectList(await service.GetCatalogBrandsAsync(), "Id", "Brand", catalogItem.CatalogBrandId);
            ViewBag.CatalogTypeId = new SelectList(await service.GetCatalogTypesAsync(), "Id", "Type", catalogItem.CatalogTypeId);
            return View(catalogItem);
        }

        // GET: Catalog/Delete/5
        public async Task<IActionResult> Delete(int? id)
        {
            _log.Info($"Now loading... /Catalog/Delete?id={id}");
            if (id == null)
            {
                return BadRequest();
            }
            CatalogItem catalogItem = await service.FindCatalogItemAsync(id.Value);
            if (catalogItem == null)
            {
                return NotFound();
            }
            AddUriPlaceHolder(catalogItem);

            return View(catalogItem);
        }

        // POST: Catalog/Delete/5
        [HttpPost, ActionName("Delete")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> DeleteConfirmed(int id)
        {
            _log.Info($"Now processing... /Catalog/DeleteConfirmed?id={id}");
            CatalogItem catalogItem = await service.FindCatalogItemAsync(id);
            await service.RemoveCatalogItemAsync(catalogItem);
            return RedirectToAction("Index");
        }

        protected override void Dispose(bool disposing)
        {
            _log.Debug($"Now disposing");
            if (disposing)
            {
                service.Dispose();
            }
            base.Dispose(disposing);
        }

        private void ChangeUriPlaceholder(IEnumerable<CatalogItem> items)
        {
            foreach (var catalogItem in items)
            {
                AddUriPlaceHolder(catalogItem);
            }
        }

        private void AddUriPlaceHolder(CatalogItem item)
        {
            item.PictureUri = Url.RouteUrl(PicController.GetPicRouteName, new { catalogItemId = item.Id }, Request.Scheme);            
        }
    }
}

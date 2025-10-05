using eShopLegacy.Utilities;
using eShopLegacyMVC.Services;
using System;
using System.Linq;
using Microsoft.AspNetCore.Mvc;

namespace eShopLegacyMVC.Controllers.WebApi
{
    [Route("api/[controller]")]
    [ApiController]
    public class FilesController : ControllerBase
    {
        private ICatalogService _service;

        public FilesController(ICatalogService service)
        {
            _service = service;
        }

        // GET api/files
        [HttpGet]
        public IActionResult Get()
        {
            var brands = _service.GetCatalogBrands()
                .Select(b => new BrandDTO
                {
                    Id = b.Id,
                    Brand = b.Brand
                }).ToList();
            
            var serializer = new Serializing();
            var stream = serializer.SerializeBinary(brands);
            
            return File(stream, "application/octet-stream");
        }

        [Serializable]
        public class BrandDTO
        {
            public int Id { get; set; }
            public string Brand { get; set; }
        }
    }
}
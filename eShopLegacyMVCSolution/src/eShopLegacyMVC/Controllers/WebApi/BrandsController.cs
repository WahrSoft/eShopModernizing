using eShopLegacy.Utilities;
using eShopLegacyMVC.Services;
using System.Collections.Generic;
using System.Linq;
using Microsoft.AspNetCore.Mvc;
using System.Threading.Tasks;

namespace eShopLegacyMVC.Controllers.WebApi
{
    [Route("api/[controller]")]
    [ApiController]
    public class BrandsController : ControllerBase
    {
        private ICatalogService _service;

        public BrandsController(ICatalogService service)
        {
            _service = service;
        }

        // GET api/brands
        [HttpGet]
        public async Task<IEnumerable<Models.CatalogBrand>> Get()
        {
            var brands = await _service.GetCatalogBrandsAsync();
            return brands;
        }

        // GET api/brands/5
        [HttpGet("{id}")]
        public async Task<IActionResult> Get(int id)
        {
            var brand = await _service.FindCatalogBrandAsync(id);
            if (brand == null) return NotFound();

            return Ok(brand);
        }

        // DELETE api/brands/5
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var brandToDelete = await _service.FindCatalogBrandAsync(id);
            if (brandToDelete == null)
            {
                return NotFound();
            }

            // demo only - don't actually delete
            return Ok();
        }
    }
}
using Microsoft.AspNetCore.Mvc;

namespace eShopLegacyMVC.Controllers.Api
{
    [Route("api")]
    [ApiController]
    public class CatalogController2 : ControllerBase
    {
        [HttpGet]
        public IActionResult Index()
        {
            return Ok(new { Message = "Hello World!" });
        }
    }
}

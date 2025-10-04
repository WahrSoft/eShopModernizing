using Microsoft.AspNetCore.Mvc;
using eShopModernized.Services;
using eShopModernized.Models;
using eShopModernized.ViewModels;

namespace eShopModernized.Controllers.Api;

[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class CatalogController : ControllerBase
{
    private readonly ICatalogService _catalogService;
    private readonly JsonSerializationService _jsonSerializer;
    private readonly ILogger<CatalogController> _logger;

    public CatalogController(
        ICatalogService catalogService,
        JsonSerializationService jsonSerializer,
        ILogger<CatalogController> logger)
    {
        _catalogService = catalogService ?? throw new ArgumentNullException(nameof(catalogService));
        _jsonSerializer = jsonSerializer ?? throw new ArgumentNullException(nameof(jsonSerializer));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    /// <summary>
    /// Gets a paginated list of catalog items
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<PaginatedItemsViewModel<CatalogItem>>> GetCatalogItems(
        [FromQuery] int pageSize = 10,
        [FromQuery] int pageIndex = 0,
        CancellationToken cancellationToken = default)
    {
        if (pageSize <= 0 || pageSize > 100)
        {
            return BadRequest("Page size must be between 1 and 100");
        }

        if (pageIndex < 0)
        {
            return BadRequest("Page index must be non-negative");
        }

        try
        {
            var result = await _catalogService.GetCatalogItemsPaginatedAsync(pageSize, pageIndex, cancellationToken);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving catalog items");
            return StatusCode(500, "An error occurred while retrieving catalog items");
        }
    }

    /// <summary>
    /// Gets a specific catalog item by ID
    /// </summary>
    [HttpGet("{id:int}")]
    public async Task<ActionResult<CatalogItem>> GetCatalogItem(int id, CancellationToken cancellationToken = default)
    {
        if (id <= 0)
        {
            return BadRequest("Invalid catalog item ID");
        }

        try
        {
            var item = await _catalogService.FindCatalogItemAsync(id, cancellationToken);
            
            if (item == null)
            {
                return NotFound($"Catalog item with ID {id} not found");
            }

            return Ok(item);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving catalog item {CatalogItemId}", id);
            return StatusCode(500, "An error occurred while retrieving the catalog item");
        }
    }

    /// <summary>
    /// Gets all catalog types
    /// </summary>
    [HttpGet("types")]
    public async Task<ActionResult<IEnumerable<CatalogType>>> GetCatalogTypes(CancellationToken cancellationToken = default)
    {
        try
        {
            var types = await _catalogService.GetCatalogTypesAsync(cancellationToken);
            return Ok(types);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving catalog types");
            return StatusCode(500, "An error occurred while retrieving catalog types");
        }
    }

    /// <summary>
    /// Gets all catalog brands
    /// </summary>
    [HttpGet("brands")]
    public async Task<ActionResult<IEnumerable<CatalogBrand>>> GetCatalogBrands(CancellationToken cancellationToken = default)
    {
        try
        {
            var brands = await _catalogService.GetCatalogBrandsAsync(cancellationToken);
            return Ok(brands);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving catalog brands");
            return StatusCode(500, "An error occurred while retrieving catalog brands");
        }
    }

    /// <summary>
    /// Gets catalog items by brand ID
    /// </summary>
    [HttpGet("brands/{brandId:int}/items")]
    public async Task<ActionResult<IEnumerable<CatalogItem>>> GetCatalogItemsByBrand(
        int brandId, 
        CancellationToken cancellationToken = default)
    {
        if (brandId <= 0)
        {
            return BadRequest("Invalid brand ID");
        }

        try
        {
            var items = await _catalogService.GetCatalogItemsByBrandAsync(brandId, cancellationToken);
            return Ok(items);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving catalog items for brand {BrandId}", brandId);
            return StatusCode(500, "An error occurred while retrieving catalog items");
        }
    }

    /// <summary>
    /// Gets catalog items by type ID
    /// </summary>
    [HttpGet("types/{typeId:int}/items")]
    public async Task<ActionResult<IEnumerable<CatalogItem>>> GetCatalogItemsByType(
        int typeId, 
        CancellationToken cancellationToken = default)
    {
        if (typeId <= 0)
        {
            return BadRequest("Invalid type ID");
        }

        try
        {
            var items = await _catalogService.GetCatalogItemsByTypeAsync(typeId, cancellationToken);
            return Ok(items);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving catalog items for type {TypeId}", typeId);
            return StatusCode(500, "An error occurred while retrieving catalog items");
        }
    }

    /// <summary>
    /// Creates a new catalog item
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<CatalogItem>> CreateCatalogItem(
        [FromBody] CatalogItem catalogItem, 
        CancellationToken cancellationToken = default)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var createdItem = await _catalogService.CreateCatalogItemAsync(catalogItem, cancellationToken);
            return CreatedAtAction(
                nameof(GetCatalogItem), 
                new { id = createdItem.Id }, 
                createdItem);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating catalog item");
            return StatusCode(500, "An error occurred while creating the catalog item");
        }
    }

    /// <summary>
    /// Updates an existing catalog item
    /// </summary>
    [HttpPut("{id:int}")]
    public async Task<ActionResult<CatalogItem>> UpdateCatalogItem(
        int id, 
        [FromBody] CatalogItem catalogItem, 
        CancellationToken cancellationToken = default)
    {
        if (id != catalogItem.Id)
        {
            return BadRequest("ID mismatch");
        }

        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var updatedItem = await _catalogService.UpdateCatalogItemAsync(catalogItem, cancellationToken);
            return Ok(updatedItem);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating catalog item {CatalogItemId}", id);
            return StatusCode(500, "An error occurred while updating the catalog item");
        }
    }

    /// <summary>
    /// Deletes a catalog item
    /// </summary>
    [HttpDelete("{id:int}")]
    public async Task<ActionResult> DeleteCatalogItem(int id, CancellationToken cancellationToken = default)
    {
        if (id <= 0)
        {
            return BadRequest("Invalid catalog item ID");
        }

        try
        {
            var deleted = await _catalogService.RemoveCatalogItemAsync(id, cancellationToken);
            
            if (!deleted)
            {
                return NotFound($"Catalog item with ID {id} not found");
            }

            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting catalog item {CatalogItemId}", id);
            return StatusCode(500, "An error occurred while deleting the catalog item");
        }
    }

    /// <summary>
    /// Legacy endpoint - returns brands as serialized stream (modernized from BinaryFormatter)
    /// </summary>
    [HttpGet("brands/serialized")]
    [Obsolete("Use /api/catalog/brands instead. This endpoint is maintained for backward compatibility.")]
    public async Task<IActionResult> GetBrandsSerializedLegacy(CancellationToken cancellationToken = default)
    {
        try
        {
            var brands = await _catalogService.GetCatalogBrandsAsync(cancellationToken);
            var brandDtos = brands.Select(b => new BrandDto { Id = b.Id, Brand = b.Brand }).ToList();
            
            // Use modern JSON serialization instead of BinaryFormatter
            var jsonStream = _jsonSerializer.SerializeToStream(brandDtos);
            
            return new FileStreamResult(jsonStream, "application/json")
            {
                FileDownloadName = "brands.json"
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving serialized brands");
            return StatusCode(500, "An error occurred while retrieving serialized brands");
        }
    }

    public class BrandDto
    {
        public int Id { get; set; }
        public string Brand { get; set; } = string.Empty;
    }
}
using System.ComponentModel.DataAnnotations;

namespace eShopModernized.Models;

public class CatalogBrand
{
    public int Id { get; set; }

    [Required]
    [StringLength(100)]
    public string Brand { get; set; } = string.Empty;

    // Navigation property
    public ICollection<CatalogItem> CatalogItems { get; set; } = new List<CatalogItem>();
}
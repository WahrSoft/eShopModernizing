using System.ComponentModel.DataAnnotations;

namespace eShopModernized.Models;

public class CatalogType
{
    public int Id { get; set; }

    [Required]
    [StringLength(100)]
    public string Type { get; set; } = string.Empty;

    // Navigation property
    public ICollection<CatalogItem> CatalogItems { get; set; } = new List<CatalogItem>();
}
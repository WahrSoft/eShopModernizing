using System.ComponentModel.DataAnnotations;

namespace eShopModernized.Models;

public class CatalogItem
{
    public int Id { get; set; }

    [Required]
    [StringLength(50)]
    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }

    [Required]
    public decimal Price { get; set; }

    [Required]
    public string PictureFileName { get; set; } = string.Empty;

    public string? PictureUri { get; set; }

    [Required]
    public int CatalogTypeId { get; set; }

    [Required]
    public int CatalogBrandId { get; set; }

    // Navigation properties
    public CatalogType CatalogType { get; set; } = null!;
    public CatalogBrand CatalogBrand { get; set; } = null!;

    public DateTime CreatedDate { get; set; } = DateTime.UtcNow;
    public DateTime? ModifiedDate { get; set; }
}
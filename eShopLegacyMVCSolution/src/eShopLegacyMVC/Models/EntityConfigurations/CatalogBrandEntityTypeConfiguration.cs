using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace eShopLegacyMVC.Models.EntityConfigurations
{
    public class CatalogBrandEntityTypeConfiguration : IEntityTypeConfiguration<CatalogBrand>
    {
        public void Configure(EntityTypeBuilder<CatalogBrand> builder)
        {
            builder.ToTable("CatalogBrand");

            builder.HasKey(cb => cb.Id);

            builder.Property(cb => cb.Id)
                .IsRequired()
                .ValueGeneratedOnAdd()
                .UseIdentityColumn(6); // Start identity at 6, after highest seeded ID (5)

            builder.Property(cb => cb.Brand)
                .IsRequired()
                .HasMaxLength(100);

            // Seed data
            builder.HasData(
                new CatalogBrand { Id = 1, Brand = "Azure" },
                new CatalogBrand { Id = 2, Brand = ".NET" },
                new CatalogBrand { Id = 3, Brand = "Visual Studio" },
                new CatalogBrand { Id = 4, Brand = "SQL Server" },
                new CatalogBrand { Id = 5, Brand = "Other" }
            );
        }
    }
}
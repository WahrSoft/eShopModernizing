using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace eShopLegacyMVC.Models.EntityConfigurations
{
    public class CatalogTypeEntityTypeConfiguration : IEntityTypeConfiguration<CatalogType>
    {
        public void Configure(EntityTypeBuilder<CatalogType> builder)
        {
            builder.ToTable("CatalogType");

            builder.HasKey(ct => ct.Id);

            builder.Property(ct => ct.Id)
                .IsRequired()
                .ValueGeneratedOnAdd()
                .UseIdentityColumn(5); // Start identity at 5, after highest seeded ID (4)

            builder.Property(ct => ct.Type)
                .IsRequired()
                .HasMaxLength(100);

            // Seed data
            builder.HasData(
                new CatalogType { Id = 1, Type = "Mug" },
                new CatalogType { Id = 2, Type = "T-Shirt" },
                new CatalogType { Id = 3, Type = "Sheet" },
                new CatalogType { Id = 4, Type = "USB Memory Stick" }
            );
        }
    }
}
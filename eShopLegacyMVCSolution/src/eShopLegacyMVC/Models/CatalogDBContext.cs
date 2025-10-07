using eShopLegacyMVC.Models.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using System.ComponentModel.DataAnnotations.Schema;
using System.Reflection.Emit;

namespace eShopLegacyMVC.Models
{
    public class CatalogDBContext : DbContext
    {
        public CatalogDBContext(DbContextOptions<CatalogDBContext> options) : base(options)
        {
        }

        public DbSet<CatalogItem> CatalogItems { get; set; }

        public DbSet<CatalogBrand> CatalogBrands { get; set; }

        public DbSet<CatalogType> CatalogTypes { get; set; }

        protected override void OnModelCreating(ModelBuilder builder)
        {
            // Apply entity type configurations
            builder.ApplyConfiguration(new CatalogTypeEntityTypeConfiguration());
            builder.ApplyConfiguration(new CatalogBrandEntityTypeConfiguration());
            builder.ApplyConfiguration(new CatalogItemEntityTypeConfiguration());

            base.OnModelCreating(builder);
        }

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

        public class CatalogItemEntityTypeConfiguration : IEntityTypeConfiguration<CatalogItem>
        {
            public void Configure(EntityTypeBuilder<CatalogItem> builder)
            {
                builder.ToTable("Catalog");

                builder.HasKey(ci => ci.Id);

                builder.Property(ci => ci.Id)
                    .ValueGeneratedOnAdd()
                    .UseIdentityColumn(13);

                builder.Property(ci => ci.Name)
                    .IsRequired()
                    .HasMaxLength(50);

                builder.Property(ci => ci.Price)
                    .IsRequired()
                    .HasColumnType("decimal(18,2)");

                builder.Property(ci => ci.PictureFileName)
                    .IsRequired();

                builder.Ignore(ci => ci.PictureUri);

                // Foreign key relationships
                builder.HasOne(ci => ci.CatalogBrand)
                    .WithMany()
                    .HasForeignKey(ci => ci.CatalogBrandId)
                    .IsRequired();

                builder.HasOne(ci => ci.CatalogType)
                    .WithMany()
                    .HasForeignKey(ci => ci.CatalogTypeId)
                    .IsRequired();

                // Seed data
                builder.HasData(
                    new CatalogItem { Id = 1, CatalogTypeId = 2, CatalogBrandId = 2, AvailableStock = 100, Description = ".NET Bot Black Hoodie", Name = ".NET Bot Black Hoodie", Price = 19.5M, PictureFileName = "1.png" },
                    new CatalogItem { Id = 2, CatalogTypeId = 1, CatalogBrandId = 2, AvailableStock = 100, Description = ".NET Black & White Mug", Name = ".NET Black & White Mug", Price = 8.50M, PictureFileName = "2.png" },
                    new CatalogItem { Id = 3, CatalogTypeId = 2, CatalogBrandId = 5, AvailableStock = 100, Description = "Prism White T-Shirt", Name = "Prism White T-Shirt", Price = 12, PictureFileName = "3.png" },
                    new CatalogItem { Id = 4, CatalogTypeId = 2, CatalogBrandId = 2, AvailableStock = 100, Description = ".NET Foundation T-shirt", Name = ".NET Foundation T-shirt", Price = 12, PictureFileName = "4.png" },
                    new CatalogItem { Id = 5, CatalogTypeId = 3, CatalogBrandId = 5, AvailableStock = 100, Description = "Roslyn Red Sheet", Name = "Roslyn Red Sheet", Price = 8.5M, PictureFileName = "5.png" },
                    new CatalogItem { Id = 6, CatalogTypeId = 2, CatalogBrandId = 2, AvailableStock = 100, Description = ".NET Blue Hoodie", Name = ".NET Blue Hoodie", Price = 12, PictureFileName = "6.png" },
                    new CatalogItem { Id = 7, CatalogTypeId = 2, CatalogBrandId = 5, AvailableStock = 100, Description = "Roslyn Red T-Shirt", Name = "Roslyn Red T-Shirt", Price = 12, PictureFileName = "7.png" },
                    new CatalogItem { Id = 8, CatalogTypeId = 2, CatalogBrandId = 5, AvailableStock = 100, Description = "Kudu Purple Hoodie", Name = "Kudu Purple Hoodie", Price = 8.5M, PictureFileName = "8.png" },
                    new CatalogItem { Id = 9, CatalogTypeId = 1, CatalogBrandId = 5, AvailableStock = 100, Description = "Cup<T> White Mug", Name = "Cup<T> White Mug", Price = 12, PictureFileName = "9.png" },
                    new CatalogItem { Id = 10, CatalogTypeId = 3, CatalogBrandId = 2, AvailableStock = 100, Description = ".NET Foundation Sheet", Name = ".NET Foundation Sheet", Price = 12, PictureFileName = "10.png" },
                    new CatalogItem { Id = 11, CatalogTypeId = 3, CatalogBrandId = 2, AvailableStock = 100, Description = "Cup<T> Sheet", Name = "Cup<T> Sheet", Price = 8.5M, PictureFileName = "11.png" },
                    new CatalogItem { Id = 12, CatalogTypeId = 2, CatalogBrandId = 5, AvailableStock = 100, Description = "Prism White TShirt", Name = "Prism White TShirt", Price = 12, PictureFileName = "12.png" }
                );
            }
        }

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
}

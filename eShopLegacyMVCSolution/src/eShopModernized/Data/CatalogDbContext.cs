using Microsoft.EntityFrameworkCore;
using eShopModernized.Models;

namespace eShopModernized.Data;

public class CatalogDbContext : DbContext
{
    public CatalogDbContext(DbContextOptions<CatalogDbContext> options) : base(options)
    {
    }

    public DbSet<CatalogItem> CatalogItems => Set<CatalogItem>();
    public DbSet<CatalogBrand> CatalogBrands => Set<CatalogBrand>();
    public DbSet<CatalogType> CatalogTypes => Set<CatalogType>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Configure CatalogType
        modelBuilder.Entity<CatalogType>(entity =>
        {
            entity.ToTable("CatalogType");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Type)
                .IsRequired()
                .HasMaxLength(100);
            
            // Index for performance
            entity.HasIndex(e => e.Type);
        });

        // Configure CatalogBrand
        modelBuilder.Entity<CatalogBrand>(entity =>
        {
            entity.ToTable("CatalogBrand");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Brand)
                .IsRequired()
                .HasMaxLength(100);
            
            // Index for performance
            entity.HasIndex(e => e.Brand);
        });

        // Configure CatalogItem
        modelBuilder.Entity<CatalogItem>(entity =>
        {
            entity.ToTable("Catalog");
            entity.HasKey(e => e.Id);

            entity.Property(e => e.Name)
                .IsRequired()
                .HasMaxLength(50);

            entity.Property(e => e.Price)
                .IsRequired()
                .HasColumnType("decimal(18,2)");

            entity.Property(e => e.PictureFileName)
                .IsRequired();

            // Ignore computed property
            entity.Ignore(e => e.PictureUri);

            // Configure relationships
            entity.HasOne(e => e.CatalogBrand)
                .WithMany(b => b.CatalogItems)
                .HasForeignKey(e => e.CatalogBrandId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.CatalogType)
                .WithMany(t => t.CatalogItems)
                .HasForeignKey(e => e.CatalogTypeId)
                .OnDelete(DeleteBehavior.Restrict);

            // Indexes for performance
            entity.HasIndex(e => e.CatalogBrandId);
            entity.HasIndex(e => e.CatalogTypeId);
            entity.HasIndex(e => e.Name);
        });

        // Seed data
        SeedData(modelBuilder);
    }

    private static void SeedData(ModelBuilder modelBuilder)
    {
        // Seed CatalogTypes
        modelBuilder.Entity<CatalogType>().HasData(
            new CatalogType { Id = 1, Type = "Mug" },
            new CatalogType { Id = 2, Type = "T-Shirt" },
            new CatalogType { Id = 3, Type = "Sheet" },
            new CatalogType { Id = 4, Type = "USB Memory Stick" }
        );

        // Seed CatalogBrands
        modelBuilder.Entity<CatalogBrand>().HasData(
            new CatalogBrand { Id = 1, Brand = "Azure" },
            new CatalogBrand { Id = 2, Brand = ".NET" },
            new CatalogBrand { Id = 3, Brand = "Visual Studio" },
            new CatalogBrand { Id = 4, Brand = "SQL Server" },
            new CatalogBrand { Id = 5, Brand = "Other" }
        );
    }

    public override int SaveChanges()
    {
        UpdateTimestamps();
        return base.SaveChanges();
    }

    public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        UpdateTimestamps();
        return await base.SaveChangesAsync(cancellationToken);
    }

    private void UpdateTimestamps()
    {
        var entries = ChangeTracker.Entries<CatalogItem>();

        foreach (var entry in entries)
        {
            switch (entry.State)
            {
                case EntityState.Added:
                    entry.Entity.CreatedDate = DateTime.UtcNow;
                    break;
                case EntityState.Modified:
                    entry.Entity.ModifiedDate = DateTime.UtcNow;
                    break;
            }
        }
    }
}
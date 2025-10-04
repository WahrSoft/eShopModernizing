using System;
using System.Collections.Generic;
using Microsoft.Extensions.Configuration;
using Microsoft.EntityFrameworkCore;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Logging;
using System.Threading.Tasks;

namespace eShopLegacyMVC.Models.Infrastructure
{
    public class CatalogDBInitializer
    {
        private readonly bool _useCustomizationData;
        private readonly IConfiguration _configuration;
        private readonly IWebHostEnvironment _environment;
        private readonly ILogger<CatalogDBInitializer> _logger;

        public CatalogDBInitializer(
            IConfiguration configuration, 
            IWebHostEnvironment environment,
            ILogger<CatalogDBInitializer> logger)
        {
            _configuration = configuration;
            _environment = environment;
            _logger = logger;
            _useCustomizationData = _configuration.GetValue<bool>("AppSettings:UseCustomizationData");
        }

        public async Task SeedAsync(CatalogDBContext context)
        {
            try
            {
                _logger.LogInformation("Starting database seeding...");

                // Ensure the database is created and migrations are applied
                await context.Database.EnsureCreatedAsync();

                // Only add custom data if UseCustomizationData is true and data doesn't exist
                if (_useCustomizationData)
                {
                    await SeedCustomDataAsync(context);
                }

                // Handle catalog item pictures
                await AddCatalogItemPicturesAsync();

                _logger.LogInformation("Database seeding completed successfully.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "An error occurred while seeding the database.");
                throw;
            }
        }

        private async Task SeedCustomDataAsync(CatalogDBContext context)
        {
            // Clear existing data if we're using custom data
            if (await context.CatalogItems.AnyAsync())
            {
                _logger.LogInformation("Custom data seeding: Clearing existing catalog data...");
                
                context.CatalogItems.RemoveRange(context.CatalogItems);
                context.CatalogBrands.RemoveRange(context.CatalogBrands);
                context.CatalogTypes.RemoveRange(context.CatalogTypes);
                
                await context.SaveChangesAsync();
            }

            // Add custom catalog types
            var customTypes = GetCatalogTypesFromFile();
            if (customTypes.Any())
            {
                await context.CatalogTypes.AddRangeAsync(customTypes);
                await context.SaveChangesAsync();
                _logger.LogInformation("Added {Count} custom catalog types.", customTypes.Count());
            }

            // Add custom catalog brands
            var customBrands = GetCatalogBrandsFromFile();
            if (customBrands.Any())
            {
                await context.CatalogBrands.AddRangeAsync(customBrands);
                await context.SaveChangesAsync();
                _logger.LogInformation("Added {Count} custom catalog brands.", customBrands.Count());
            }

            // Add custom catalog items
            var customItems = GetCatalogItemsFromFile(context);
            if (customItems.Any())
            {
                await context.CatalogItems.AddRangeAsync(customItems);
                await context.SaveChangesAsync();
                _logger.LogInformation("Added {Count} custom catalog items.", customItems.Count());
            }
        }

        private IEnumerable<CatalogType> GetCatalogTypesFromFile()
        {
            var contentRootPath = _environment.ContentRootPath;
            string csvFileCatalogTypes = Path.Combine(contentRootPath, "Setup", "CatalogTypes.csv");

            if (!File.Exists(csvFileCatalogTypes))
            {
                _logger.LogWarning("CatalogTypes.csv file not found at {FilePath}", csvFileCatalogTypes);
                return Enumerable.Empty<CatalogType>();
            }

            try
            {
                string[] requiredHeaders = { "catalogtype" };
                string[] csvheaders = GetHeaders(csvFileCatalogTypes, requiredHeaders);

                return File.ReadAllLines(csvFileCatalogTypes)
                            .Skip(1) // skip header row
                            .Select(x => CreateCatalogType(x))
                            .Where(x => x != null);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error reading CatalogTypes from file: {FilePath}", csvFileCatalogTypes);
                return Enumerable.Empty<CatalogType>();
            }
        }

        private static CatalogType CreateCatalogType(string type)
        {
            type = type.Trim('"').Trim();

            if (string.IsNullOrEmpty(type))
            {
                throw new ArgumentException("Catalog Type Name is empty");
            }

            return new CatalogType
            {
                Type = type,
            };
        }

        private IEnumerable<CatalogBrand> GetCatalogBrandsFromFile()
        {
            var contentRootPath = _environment.ContentRootPath;
            string csvFileCatalogBrands = Path.Combine(contentRootPath, "Setup", "CatalogBrands.csv");

            if (!File.Exists(csvFileCatalogBrands))
            {
                _logger.LogWarning("CatalogBrands.csv file not found at {FilePath}", csvFileCatalogBrands);
                return Enumerable.Empty<CatalogBrand>();
            }

            try
            {
                string[] requiredHeaders = { "catalogbrand" };
                string[] csvheaders = GetHeaders(csvFileCatalogBrands, requiredHeaders);

                return File.ReadAllLines(csvFileCatalogBrands)
                            .Skip(1) // skip header row
                            .Select(x => CreateCatalogBrand(x))
                            .Where(x => x != null);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error reading CatalogBrands from file: {FilePath}", csvFileCatalogBrands);
                return Enumerable.Empty<CatalogBrand>();
            }
        }

        private static CatalogBrand CreateCatalogBrand(string brand)
        {
            brand = brand.Trim('"').Trim();

            if (string.IsNullOrEmpty(brand))
            {
                throw new ArgumentException("Catalog Brand Name is empty");
            }

            return new CatalogBrand
            {
                Brand = brand,
            };
        }

        private IEnumerable<CatalogItem> GetCatalogItemsFromFile(CatalogDBContext context)
        {
            var contentRootPath = _environment.ContentRootPath;
            string csvFileCatalogItems = Path.Combine(contentRootPath, "Setup", "CatalogItems.csv");

            if (!File.Exists(csvFileCatalogItems))
            {
                _logger.LogWarning("CatalogItems.csv file not found at {FilePath}", csvFileCatalogItems);
                return Enumerable.Empty<CatalogItem>();
            }

            try
            {
                string[] requiredHeaders = { "catalogtypename", "catalogbrandname", "description", "name", "price", "pictureFileName" };
                string[] optionalheaders = { "availablestock", "restockthreshold", "maxstockthreshold", "onreorder" };
                string[] csvheaders = GetHeaders(csvFileCatalogItems, requiredHeaders, optionalheaders);

                var catalogTypeIdLookup = context.CatalogTypes.ToDictionary(ct => ct.Type, ct => ct.Id);
                var catalogBrandIdLookup = context.CatalogBrands.ToDictionary(ct => ct.Brand, ct => ct.Id);

                return File.ReadAllLines(csvFileCatalogItems)
                            .Skip(1) // skip header row
                            .Select(row => Regex.Split(row, ",(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)"))
                            .Select(column => CreateCatalogItem(column, csvheaders, catalogTypeIdLookup, catalogBrandIdLookup))
                            .Where(x => x != null);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error reading CatalogItems from file: {FilePath}", csvFileCatalogItems);
                return Enumerable.Empty<CatalogItem>();
            }
        }

        private static CatalogItem CreateCatalogItem(string[] column, string[] headers, Dictionary<string, int> catalogTypeIdLookup, Dictionary<string, int> catalogBrandIdLookup)
        {
            if (column.Length != headers.Length)
            {
                throw new ArgumentException($"Column count '{column.Length}' not the same as headers count'{headers.Length}'");
            }

            string catalogTypeName = column[Array.IndexOf(headers, "catalogtypename")].Trim('"').Trim();
            if (!catalogTypeIdLookup.ContainsKey(catalogTypeName))
            {
                throw new ArgumentException($"Type={catalogTypeName} does not exist in catalogTypes");
            }

            string catalogBrandName = column[Array.IndexOf(headers, "catalogbrandname")].Trim('"').Trim();
            if (!catalogBrandIdLookup.ContainsKey(catalogBrandName))
            {
                throw new ArgumentException($"Brand={catalogBrandName} does not exist in catalogBrands");
            }

            string priceString = column[Array.IndexOf(headers, "price")].Trim('"').Trim();
            if (!decimal.TryParse(priceString, NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out decimal price))
            {
                throw new ArgumentException($"Price={priceString} is not a valid decimal number");
            }

            var catalogItem = new CatalogItem()
            {
                CatalogTypeId = catalogTypeIdLookup[catalogTypeName],
                CatalogBrandId = catalogBrandIdLookup[catalogBrandName],
                Description = column[Array.IndexOf(headers, "description")].Trim('"').Trim(),
                Name = column[Array.IndexOf(headers, "name")].Trim('"').Trim(),
                Price = price,
                PictureFileName = column[Array.IndexOf(headers, "picturefilename")].Trim('"').Trim(),
            };

            // Handle optional fields
            SetOptionalIntProperty(column, headers, "availablestock", value => catalogItem.AvailableStock = value);
            SetOptionalIntProperty(column, headers, "restockthreshold", value => catalogItem.RestockThreshold = value);
            SetOptionalIntProperty(column, headers, "maxstockthreshold", value => catalogItem.MaxStockThreshold = value);
            SetOptionalBoolProperty(column, headers, "onreorder", value => catalogItem.OnReorder = value);

            return catalogItem;
        }

        private static void SetOptionalIntProperty(string[] column, string[] headers, string headerName, Action<int> setter)
        {
            int index = Array.IndexOf(headers, headerName);
            if (index != -1)
            {
                string valueString = column[index].Trim('"').Trim();
                if (!string.IsNullOrEmpty(valueString))
                {
                    if (int.TryParse(valueString, out int value))
                    {
                        setter(value);
                    }
                    else
                    {
                        throw new ArgumentException($"{headerName}={valueString} is not a valid integer");
                    }
                }
            }
        }

        private static void SetOptionalBoolProperty(string[] column, string[] headers, string headerName, Action<bool> setter)
        {
            int index = Array.IndexOf(headers, headerName);
            if (index != -1)
            {
                string valueString = column[index].Trim('"').Trim();
                if (!string.IsNullOrEmpty(valueString))
                {
                    if (bool.TryParse(valueString, out bool value))
                    {
                        setter(value);
                    }
                    else
                    {
                        throw new ArgumentException($"{headerName}={valueString} is not a valid boolean");
                    }
                }
            }
        }

        private static string[] GetHeaders(string csvfile, string[] requiredHeaders, string[] optionalHeaders = null)
        {
            string[] csvheaders = File.ReadLines(csvfile).First().ToLowerInvariant().Split(',');

            if (csvheaders.Length < requiredHeaders.Length)
            {
                throw new ArgumentException($"Required header count '{requiredHeaders.Length}' is bigger than csv header count '{csvheaders.Length}'");
            }

            if (optionalHeaders != null)
            {
                if (csvheaders.Length > (requiredHeaders.Length + optionalHeaders.Length))
                {
                    throw new ArgumentException($"CSV header count '{csvheaders.Length}' is larger than required '{requiredHeaders.Length}' and optional '{optionalHeaders.Length}' headers count");
                }
            }

            foreach (var requiredHeader in requiredHeaders)
            {
                if (!csvheaders.Contains(requiredHeader.ToLowerInvariant()))
                {
                    throw new ArgumentException($"CSV does not contain required header '{requiredHeader}'");
                }
            }

            return csvheaders;
        }

        private Task AddCatalogItemPicturesAsync()
        {
            if (!_useCustomizationData)
            {
                return Task.CompletedTask;
            }

            var contentRootPath = _environment.ContentRootPath;
            DirectoryInfo picturePath = new DirectoryInfo(Path.Combine(contentRootPath, "wwwroot", "Pics"));
            
            try
            {
                // Create directory if it doesn't exist
                if (!picturePath.Exists)
                {
                    picturePath.Create();
                }
                
                // Clear existing pictures
                foreach (FileInfo file in picturePath.GetFiles())
                {
                    file.Delete();
                }
                
                string zipFileCatalogItemPictures = Path.Combine(contentRootPath, "Setup", "CatalogItems.zip");
                if (File.Exists(zipFileCatalogItemPictures))
                {
                    ZipFile.ExtractToDirectory(zipFileCatalogItemPictures, picturePath.ToString());
                    _logger.LogInformation("Extracted catalog item pictures from {ZipFile}", zipFileCatalogItemPictures);
                }
                else
                {
                    _logger.LogWarning("Catalog items zip file not found: {ZipFile}", zipFileCatalogItemPictures);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing catalog item pictures");
                // Don't throw, as this is not critical for database functionality
            }

            return Task.CompletedTask;
        }
    }
}
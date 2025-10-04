using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Azure.Identity;

namespace eShopModernized.Services;

public interface IBlobStorageService
{
    Task<string> UploadFileAsync(string fileName, Stream fileStream, string contentType, CancellationToken cancellationToken = default);
    Task<Stream?> DownloadFileAsync(string fileName, CancellationToken cancellationToken = default);
    Task<bool> DeleteFileAsync(string fileName, CancellationToken cancellationToken = default);
    Task<bool> FileExistsAsync(string fileName, CancellationToken cancellationToken = default);
    Task<IEnumerable<string>> ListFilesAsync(string prefix = "", CancellationToken cancellationToken = default);
    string GetFileUrl(string fileName);
}

public class BlobStorageService : IBlobStorageService
{
    private readonly BlobServiceClient _blobServiceClient;
    private readonly BlobContainerClient _containerClient;
    private readonly ILogger<BlobStorageService> _logger;
    private readonly string _containerName;
    private readonly string _baseUrl;

    public BlobStorageService(
        IConfiguration configuration,
        ILogger<BlobStorageService> logger)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));

        var accountName = configuration["Azure:Storage:AccountName"] 
            ?? throw new InvalidOperationException("Azure Storage account name not configured");
        
        _containerName = configuration["Azure:Storage:ContainerName"] 
            ?? throw new InvalidOperationException("Azure Storage container name not configured");

        _baseUrl = $"https://{accountName}.blob.core.windows.net/{_containerName}";

        // Use Azure Managed Identity for authentication (best practice)
        var blobUri = new Uri($"https://{accountName}.blob.core.windows.net");
        _blobServiceClient = new BlobServiceClient(blobUri, new DefaultAzureCredential());
        _containerClient = _blobServiceClient.GetBlobContainerClient(_containerName);
    }

    public async Task<string> UploadFileAsync(
        string fileName, 
        Stream fileStream, 
        string contentType, 
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(fileName);
        ArgumentNullException.ThrowIfNull(fileStream);

        try
        {
            _logger.LogInformation("Uploading file {FileName} to blob storage", fileName);

            // Ensure container exists
            await _containerClient.CreateIfNotExistsAsync(PublicAccessType.Blob, cancellationToken: cancellationToken);

            var blobClient = _containerClient.GetBlobClient(fileName);

            var uploadOptions = new BlobUploadOptions
            {
                HttpHeaders = new BlobHttpHeaders
                {
                    ContentType = contentType
                },
                Metadata = new Dictionary<string, string>
                {
                    ["UploadedAt"] = DateTimeOffset.UtcNow.ToString("O"),
                    ["OriginalFileName"] = fileName
                }
            };

            fileStream.Position = 0;
            await blobClient.UploadAsync(fileStream, uploadOptions, cancellationToken);

            var fileUrl = GetFileUrl(fileName);
            _logger.LogInformation("Successfully uploaded file {FileName} to {FileUrl}", fileName, fileUrl);

            return fileUrl;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to upload file {FileName} to blob storage", fileName);
            throw;
        }
    }

    public async Task<Stream?> DownloadFileAsync(string fileName, CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(fileName);

        try
        {
            _logger.LogInformation("Downloading file {FileName} from blob storage", fileName);

            var blobClient = _containerClient.GetBlobClient(fileName);

            if (!await blobClient.ExistsAsync(cancellationToken))
            {
                _logger.LogWarning("File {FileName} not found in blob storage", fileName);
                return null;
            }

            var response = await blobClient.DownloadStreamingAsync(cancellationToken: cancellationToken);
            return response.Value.Content;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to download file {FileName} from blob storage", fileName);
            throw;
        }
    }

    public async Task<bool> DeleteFileAsync(string fileName, CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(fileName);

        try
        {
            _logger.LogInformation("Deleting file {FileName} from blob storage", fileName);

            var blobClient = _containerClient.GetBlobClient(fileName);
            var response = await blobClient.DeleteIfExistsAsync(cancellationToken: cancellationToken);

            if (response.Value)
            {
                _logger.LogInformation("Successfully deleted file {FileName}", fileName);
            }
            else
            {
                _logger.LogWarning("File {FileName} not found for deletion", fileName);
            }

            return response.Value;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to delete file {FileName} from blob storage", fileName);
            throw;
        }
    }

    public async Task<bool> FileExistsAsync(string fileName, CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(fileName);

        try
        {
            var blobClient = _containerClient.GetBlobClient(fileName);
            var response = await blobClient.ExistsAsync(cancellationToken);
            return response.Value;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to check existence of file {FileName}", fileName);
            return false;
        }
    }

    public async Task<IEnumerable<string>> ListFilesAsync(string prefix = "", CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Listing files with prefix {Prefix} from blob storage", prefix);

            var blobs = new List<string>();

            await foreach (var blobItem in _containerClient.GetBlobsAsync(prefix: prefix, cancellationToken: cancellationToken))
            {
                blobs.Add(blobItem.Name);
            }

            return blobs;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to list files with prefix {Prefix}", prefix);
            throw;
        }
    }

    public string GetFileUrl(string fileName)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(fileName);
        return $"{_baseUrl}/{fileName}";
    }
}
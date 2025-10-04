using System.Text.Json;
using System.Text.Json.Serialization;

namespace eShopModernized.Services;

/// <summary>
/// Modern replacement for BinaryFormatter using System.Text.Json
/// Provides secure, cross-platform serialization
/// </summary>
public class JsonSerializationService
{
    private readonly JsonSerializerOptions _options;

    public JsonSerializationService()
    {
        _options = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            PropertyNameCaseInsensitive = true,
            WriteIndented = false,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
            Converters = { new JsonStringEnumConverter() }
        };
    }

    /// <summary>
    /// Serializes an object to JSON string
    /// </summary>
    public string SerializeToJson<T>(T input) where T : class
    {
        ArgumentNullException.ThrowIfNull(input);
        return JsonSerializer.Serialize(input, _options);
    }

    /// <summary>
    /// Serializes an object to UTF-8 byte stream for HTTP responses
    /// </summary>
    public Stream SerializeToStream<T>(T input) where T : class
    {
        ArgumentNullException.ThrowIfNull(input);
        
        var stream = new MemoryStream();
        JsonSerializer.Serialize(stream, input, _options);
        stream.Position = 0;
        return stream;
    }

    /// <summary>
    /// Deserializes JSON string to object
    /// </summary>
    public T? DeserializeFromJson<T>(string json) where T : class
    {
        if (string.IsNullOrWhiteSpace(json))
            return null;

        return JsonSerializer.Deserialize<T>(json, _options);
    }

    /// <summary>
    /// Deserializes stream to object
    /// </summary>
    public async Task<T?> DeserializeFromStreamAsync<T>(Stream stream) where T : class
    {
        ArgumentNullException.ThrowIfNull(stream);
        
        stream.Position = 0;
        return await JsonSerializer.DeserializeAsync<T>(stream, _options);
    }

    /// <summary>
    /// Serializes to byte array for caching scenarios
    /// </summary>
    public byte[] SerializeToBytes<T>(T input) where T : class
    {
        ArgumentNullException.ThrowIfNull(input);
        return JsonSerializer.SerializeToUtf8Bytes(input, _options);
    }

    /// <summary>
    /// Deserializes from byte array
    /// </summary>
    public T? DeserializeFromBytes<T>(byte[] bytes) where T : class
    {
        if (bytes == null || bytes.Length == 0)
            return null;

        return JsonSerializer.Deserialize<T>(bytes, _options);
    }
}
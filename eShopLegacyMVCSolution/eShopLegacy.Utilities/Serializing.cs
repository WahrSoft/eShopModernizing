using System.IO;
using System.Text.Json;
using System.Text;

namespace eShopLegacy.Utilities
{
    public class Serializing
    {
        public Stream SerializeBinary(object input)
        {
            var json = JsonSerializer.Serialize(input);
            var bytes = Encoding.UTF8.GetBytes(json);
            var stream = new MemoryStream(bytes);
            stream.Seek(0, SeekOrigin.Begin);
            return stream;
        }

        public T DeserializeBinary<T>(Stream stream)
        {
            stream.Seek(0, SeekOrigin.Begin);
            using var reader = new StreamReader(stream);
            var json = reader.ReadToEnd();
            return JsonSerializer.Deserialize<T>(json);
        }

        // Backward compatibility method
        public object DeserializeBinary(Stream stream)
        {
            stream.Seek(0, SeekOrigin.Begin);
            using var reader = new StreamReader(stream);
            var json = reader.ReadToEnd();
            return JsonSerializer.Deserialize<object>(json);
        }
    }
}

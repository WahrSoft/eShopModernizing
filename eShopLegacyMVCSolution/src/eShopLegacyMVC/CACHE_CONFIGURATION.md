# Cache Configuration

This application supports both in-memory and Redis distributed caching for session storage.

## Configuration

### Local Development (In-Memory Cache)
```json
{
  "CacheSettings": {
    "UseRedis": false,
    "InstanceName": "eShopLegacyMVC",
    "SessionTimeoutMinutes": 30
  }
}
```

### Production/Azure (Redis Cache)
```json
{
  "ConnectionStrings": {
    "Redis": "your-redis-server:6380,password=your-password,ssl=True"
  },
  "CacheSettings": {
    "UseRedis": true,
    "InstanceName": "eShopLegacyMVC-Prod",
    "SessionTimeoutMinutes": 60
  }
}
```

## Environment-Specific Configuration Files

- `appsettings.json` - Base configuration (uses in-memory cache)
- `appsettings.Development.json` - Development overrides
- `appsettings.Production.json` - Production configuration (uses Redis)
- `appsettings.Azure.json` - Azure-specific configuration

## Azure Redis Cache Setup

When deploying to Azure, you can use Azure Cache for Redis:

1. Create an Azure Cache for Redis instance
2. Get the connection string from the Azure portal
3. Update the `Redis` connection string in your production configuration
4. Set `CacheSettings:UseRedis` to `true`

### Example Azure Redis Connection String
```
your-cache-name.redis.cache.windows.net:6380,password=your-access-key,ssl=True,abortConnect=False
```

## Environment Variables

You can also configure cache settings using environment variables:

- `CacheSettings__UseRedis` - Set to `true` or `false`
- `CacheSettings__InstanceName` - Redis instance name
- `CacheSettings__SessionTimeoutMinutes` - Session timeout in minutes
- `ConnectionStrings__Redis` - Redis connection string

## Fallback Behavior

If Redis is enabled but the connection string is missing or invalid, the application will automatically fall back to in-memory caching and log a warning.
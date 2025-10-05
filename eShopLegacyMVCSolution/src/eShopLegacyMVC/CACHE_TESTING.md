# Cache Configuration Test

This script demonstrates how to test the cache configuration.

## Test Locally (In-Memory Cache)

1. Ensure `appsettings.json` has `"UseRedis": false`
2. Start the application: `dotnet run`
3. Navigate to: `http://localhost:[port]/Catalog/CacheStatus`
4. Expected response should show:
   ```json
   {
     "cacheType": "In-Memory",
     "instanceName": "eShopLegacyMVC",
     "sessionTimeoutMinutes": 30,
     "cacheImplementation": "MemoryDistributedCache"
   }
   ```

## Test with Redis

### Option 1: Local Redis (Docker)
```bash
# Start Redis container
docker run --name redis-test -p 6379:6379 -d redis:latest

# Update appsettings.Development.json
{
  "CacheSettings": {
    "UseRedis": true
  },
  "ConnectionStrings": {
    "Redis": "localhost:6379"
  }
}

# Start application
dotnet run --environment Development
```

### Option 2: Environment Variables
```bash
# Set environment variables
set CacheSettings__UseRedis=true
set ConnectionStrings__Redis=localhost:6379

# Start application
dotnet run
```

## Verify Cache is Working

1. Visit `/Catalog/CacheStatus` - note the session information
2. Close browser and reopen (for in-memory, session will be lost)
3. For Redis, session should persist across browser restarts
4. Check application logs for cache configuration messages

## Production Deployment

For production, ensure:
- `appsettings.Production.json` has `"UseRedis": true`
- Redis connection string is properly configured
- Redis server is accessible from the application
- SSL is enabled for Redis in production environments
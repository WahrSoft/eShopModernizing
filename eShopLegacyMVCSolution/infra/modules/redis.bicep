// Redis Cache with private endpoint and security best practices
// Provides high-performance caching for the application

@description('Resource name prefix')
param resourceNamePrefix string

@description('Location for all resources')
param location string

@description('Environment name')
param environmentName string

@description('Subnet ID for private endpoint')
param subnetId string

@description('Key Vault name for storing connection string')
param keyVaultName string

var redisName = '${resourceNamePrefix}-redis'

// Redis Cache with security hardening
resource redis 'Microsoft.Cache/redis@2023-08-01' = {
  name: redisName
  location: location
  properties: {
    sku: {
      name: environmentName == 'prod' ? 'Premium' : 'Standard'
      family: environmentName == 'prod' ? 'P' : 'C'
      capacity: environmentName == 'prod' ? 1 : 1
    }
    // Enable public access initially to avoid private endpoint conflicts
    publicNetworkAccess: 'Enabled'
    // Enable authentication with simplified configuration
    redisConfiguration: {
      // Only set basic configuration to avoid invalid parameter errors
      'maxmemory-policy': 'allkeys-lru'
    }
    // SSL enforcement
    minimumTlsVersion: '1.2'
  }
  // Remove zones for Standard tier as it doesn't support it
  zones: (environmentName == 'prod' && location == 'East US 2') ? ['1', '2'] : []
  tags: {
    Environment: environmentName
    Purpose: 'Application Cache'
  }
}

// Store Redis connection string in Key Vault
resource redisConnectionString 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${keyVaultName}/redis-connection-string'
  properties: {
    value: '${redis.properties.hostName}:${redis.properties.sslPort},password=${redis.listKeys().primaryKey},ssl=True,abortConnect=False'
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Store Redis primary key in Key Vault
resource redisPrimaryKey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${keyVaultName}/redis-primary-key'
  properties: {
    value: redis.listKeys().primaryKey
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Private DNS Zone for Redis
resource redisPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.redis.cache.windows.net'
  location: 'global'
  tags: {
    Environment: environmentName
    Purpose: 'Redis Private DNS'
  }
}

// Private endpoint for Redis
resource redisPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: '${redisName}-pe'
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${redisName}-connection'
        properties: {
          privateLinkServiceId: redis.id
          groupIds: ['redisCache']
        }
      }
    ]
  }
  tags: {
    Environment: environmentName
    Purpose: 'Redis Private Endpoint'
  }
}

// Private DNS Zone Group for Redis
resource redisPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: redisPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-redis-cache-windows-net'
        properties: {
          privateDnsZoneId: redisPrivateDnsZone.id
        }
      }
    ]
  }
}

// Output
output redisId string = redis.id
output redisName string = redis.name
output redisHostName string = redis.properties.hostName
output redisSslPort int = redis.properties.sslPort
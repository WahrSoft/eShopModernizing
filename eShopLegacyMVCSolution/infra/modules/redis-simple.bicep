// Simplified Redis Cache module with basic configuration
// Use this version if the enterprise version fails due to compatibility issues

@description('Resource name prefix')
param resourceNamePrefix string

@description('Location for all resources')
param location string

@description('Environment name')
param environmentName string

@description('Key Vault name for storing connection string')
param keyVaultName string

var redisName = '${resourceNamePrefix}-redis'

// Redis Cache with basic configuration
resource redis 'Microsoft.Cache/redis@2023-08-01' = {
  name: redisName
  location: location
  properties: {
    sku: {
      name: 'Standard'
      family: 'C'
      capacity: environmentName == 'prod' ? 2 : 1
    }
    publicNetworkAccess: 'Enabled'
    // Minimal configuration to avoid parameter errors
    redisConfiguration: {}
    minimumTlsVersion: '1.2'
  }
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

// Output
output redisId string = redis.id
output redisName string = redis.name
output redisHostName string = redis.properties.hostName
output redisSslPort int = redis.properties.sslPort
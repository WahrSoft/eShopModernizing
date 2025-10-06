// Simplified Azure deployment for eShopLegacyMVC
// Use this template if the enterprise version fails due to compatibility issues

@description('Environment name (dev, test, prod)')
@allowed(['dev', 'test', 'prod'])
param environmentName string = 'dev'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Base name for all resources')
param baseName string = 'eshop'

@description('SQL Admin Username')
param sqlAdminUsername string = 'sqladmin'

@description('Current user object ID for Key Vault access')
param currentUserObjectId string

// Generate unique suffix
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 6)
var resourceNamePrefix = '${baseName}-${environmentName}-${uniqueSuffix}'

// Key Vault - use existing module
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault-deployment'
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    environmentName: environmentName
    subnetId: '' // No subnet for simple version
    currentUserObjectId: currentUserObjectId
  }
}

// SQL Server - use simplified module
module sqlServer 'modules/sql-simple.bicep' = {
  name: 'sql-deployment-simple'
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    environmentName: environmentName
    sqlAdminUsername: sqlAdminUsername
    keyVaultName: keyVault.outputs.keyVaultName
  }
}

// Redis Cache - use simplified module
module redis 'modules/redis-simple.bicep' = {
  name: 'redis-deployment-simple'
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    environmentName: environmentName
    keyVaultName: keyVault.outputs.keyVaultName
  }
}

// Application Insights
module appInsights 'modules/appinsights.bicep' = {
  name: 'appinsights-deployment'
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    environmentName: environmentName
  }
}

// App Service with basic configuration
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: '${resourceNamePrefix}-plan'
  location: location
  sku: {
    name: environmentName == 'prod' ? 'S1' : 'B1'
    tier: environmentName == 'prod' ? 'Standard' : 'Basic'
  }
  properties: {
    reserved: false
  }
  tags: {
    Environment: environmentName
    Purpose: 'App Service Plan'
  }
}

resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: '${resourceNamePrefix}-app'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: 'v8.0'
      alwaysOn: environmentName == 'prod'
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.outputs.instrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.outputs.connectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
      ]
      connectionStrings: [
        {
          name: 'CatalogDBContext'
          connectionString: '@Microsoft.KeyVault(VaultName=${keyVault.outputs.keyVaultName};SecretName=sql-connection-string)'
          type: 'SQLAzure'
        }
        {
          name: 'Redis'
          connectionString: '@Microsoft.KeyVault(VaultName=${keyVault.outputs.keyVaultName};SecretName=redis-connection-string)'
          type: 'Custom'
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
  tags: {
    Environment: environmentName
    Purpose: 'Web Application'
  }
}

// Grant web app access to Key Vault
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = {
  name: '${keyVault.outputs.keyVaultName}/add'
  properties: {
    accessPolicies: [
      {
        tenantId: webApp.identity.tenantId
        objectId: webApp.identity.principalId
        permissions: {
          secrets: ['get', 'list']
        }
      }
    ]
  }
}

// Outputs for reference
output webAppName string = webApp.name
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output keyVaultName string = keyVault.outputs.keyVaultName
output sqlServerName string = sqlServer.outputs.sqlServerName
output redisName string = redis.outputs.redisName
output resourceGroupName string = resourceGroup().name
// Enterprise-grade Azure deployment for eShopLegacyMVC
// This template deploys the complete infrastructure with security best practices

@description('Environment name (dev, test, prod)')
@allowed(['dev', 'test', 'prod'])
param environmentName string = 'dev'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Base name for all resources')
param baseName string = 'eshop'

@description('SQL Admin Username')
param sqlAdminUsername string = 'sqladmin'

@description('Current user object ID for SQL Entra Admin')
param currentUserObjectId string

@description('Current user UPN for SQL Entra Admin')
param currentUserPrincipalName string

// Generate unique suffix
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 5)
var resourceNamePrefix = '${baseName}-${environmentName}-${uniqueSuffix}'

// Network module
module network 'modules/network.bicep' = {
  name: 'network-deployment'
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    environmentName: environmentName
  }
}

// Key Vault module
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault-deployment'
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    environmentName: environmentName
    subnetId: network.outputs.keyVaultSubnetId
    currentUserObjectId: currentUserObjectId
  }
}

// SQL Server module
module sqlServer 'modules/sql.bicep' = {
  name: 'sql-deployment'
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    environmentName: environmentName
    sqlAdminUsername: sqlAdminUsername
    subnetId: network.outputs.sqlSubnetId
    keyVaultName: keyVault.outputs.keyVaultName
    currentUserObjectId: currentUserObjectId
    currentUserPrincipalName: currentUserPrincipalName
  }
}

// Redis Cache module
module redis 'modules/redis.bicep' = {
  name: 'redis-deployment'
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    environmentName: environmentName
    subnetId: network.outputs.redisSubnetId
    keyVaultName: keyVault.outputs.keyVaultName
  }
}

// Application Insights module
module appInsights 'modules/appinsights.bicep' = {
  name: 'appinsights-deployment'
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    environmentName: environmentName
  }
}

// App Service module
module appService 'modules/appservice.bicep' = {
  name: 'appservice-deployment'
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    environmentName: environmentName
    subnetId: network.outputs.appServiceSubnetId
    keyVaultName: keyVault.outputs.keyVaultName
    sqlServerName: sqlServer.outputs.sqlServerName
    sqlDatabaseName: sqlServer.outputs.sqlDatabaseName
    appInsightsConnectionString: appInsights.outputs.connectionString
  }
}

// Outputs for reference
output webAppName string = appService.outputs.webAppName
output webAppUrl string = appService.outputs.webAppUrl
output keyVaultName string = keyVault.outputs.keyVaultName
output sqlServerName string = sqlServer.outputs.sqlServerName
output redisName string = redis.outputs.redisName
output resourceGroupName string = resourceGroup().name
// =============================================================================
// Main Bicep template for eShop Legacy MVC Enterprise deployment
// =============================================================================

@description('The environment name for deployment (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environmentName string = 'dev'

@description('The Azure region where resources will be deployed')
param location string = resourceGroup().location

@description('The name prefix for all resources')
@minLength(3)
@maxLength(8)
param namePrefix string = 'eshop'

@description('The administrator username for the SQL server')
param sqlAdminUsername string = 'eshopadmin'

@description('The Object ID of the current user (for SQL Entra Admin assignment)')
param currentUserObjectId string

@description('The current user principal name (for SQL Entra Admin assignment)')
param currentUserPrincipalName string

@description('Enable Application Insights and monitoring')
param enableMonitoring bool = true

@description('The SKU for the App Service Plan')
@allowed(['B1', 'B2', 'B3', 'S1', 'S2', 'S3', 'P1v3', 'P2v3', 'P3v3'])
param appServicePlanSku string = 'B2'

@description('The pricing tier for the SQL Database')
@allowed(['Basic', 'Standard', 'Premium', 'GeneralPurpose', 'BusinessCritical'])
param sqlDatabaseTier string = 'Standard'

@description('The size/DTU for the SQL Database')
param sqlDatabaseSize string = 'S1'

// Variables for resource naming following Azure naming conventions
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 6)
var resourcePrefix = '${namePrefix}-${environmentName}'

// Virtual Network configuration
var vnetConfig = {
  addressPrefix: '10.0.0.0/16'
  subnets: {
    appService: {
      name: 'app-service-subnet'
      addressPrefix: '10.0.1.0/24'
    }
    privateEndpoints: {
      name: 'private-endpoints-subnet'
      addressPrefix: '10.0.2.0/24'
    }
    sql: {
      name: 'sql-subnet'
      addressPrefix: '10.0.3.0/24'
    }
  }
}

// Deploy the Virtual Network and subnets
module network 'modules/network.bicep' = {
  name: 'network-deployment'
  params: {
    location: location
    resourcePrefix: resourcePrefix
    uniqueSuffix: uniqueSuffix
    vnetConfig: vnetConfig
  }
}

// Deploy Key Vault for secrets management
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault-deployment'
  params: {
    location: location
    resourcePrefix: resourcePrefix
    uniqueSuffix: uniqueSuffix
    currentUserObjectId: currentUserObjectId
    vnetId: network.outputs.vnetId
    privateEndpointSubnetId: network.outputs.privateEndpointSubnetId
  }
}

// Deploy SQL Server and Database with private endpoint
module database 'modules/database.bicep' = {
  name: 'database-deployment'
  params: {
    location: location
    resourcePrefix: resourcePrefix
    uniqueSuffix: uniqueSuffix
    adminUsername: sqlAdminUsername
    databaseTier: sqlDatabaseTier
    databaseSize: sqlDatabaseSize
    currentUserObjectId: currentUserObjectId
    currentUserPrincipalName: currentUserPrincipalName
    keyVaultId: keyVault.outputs.keyVaultId
    vnetId: network.outputs.vnetId
    privateEndpointSubnetId: network.outputs.privateEndpointSubnetId
  }
}

// Deploy Application Insights (if monitoring is enabled)
module monitoring 'modules/monitoring.bicep' = if (enableMonitoring) {
  name: 'monitoring-deployment'
  params: {
    location: location
    resourcePrefix: resourcePrefix
    uniqueSuffix: uniqueSuffix
    keyVaultId: keyVault.outputs.keyVaultId
  }
}

// Deploy App Service with managed identity and VNet integration
module appService 'modules/appservice.bicep' = {
  name: 'appservice-deployment'
  params: {
    location: location
    resourcePrefix: resourcePrefix
    uniqueSuffix: uniqueSuffix
    appServicePlanSku: appServicePlanSku
    keyVaultId: keyVault.outputs.keyVaultId
    appServiceSubnetId: network.outputs.appServiceSubnetId
    applicationInsightsConnectionString: enableMonitoring ? monitoring.outputs.connectionString : ''
    applicationInsightsInstrumentationKey: enableMonitoring ? monitoring.outputs.instrumentationKey : ''
  }
  dependsOn: [
    database
  ]
}

// Grant App Service managed identity access to Key Vault
module keyVaultAccess 'modules/keyvault-access.bicep' = {
  name: 'keyvault-access-deployment'
  params: {
    keyVaultName: keyVault.outputs.keyVaultName
    appServicePrincipalId: appService.outputs.managedIdentityPrincipalId
  }
}

// Grant App Service managed identity access to SQL Database
module sqlAccess 'modules/sql-access.bicep' = {
  name: 'sql-access-deployment'
  params: {
    sqlServerName: database.outputs.sqlServerName
    databaseName: database.outputs.databaseName
    appServicePrincipalId: appService.outputs.managedIdentityPrincipalId
    appServiceName: appService.outputs.appServiceName
  }
}

// Outputs for reference and verification
output resourceGroupName string = resourceGroup().name
output appServiceUrl string = appService.outputs.appServiceUrl
output keyVaultName string = keyVault.outputs.keyVaultName
output sqlServerName string = database.outputs.sqlServerName
output databaseName string = database.outputs.databaseName
output vnetName string = network.outputs.vnetName
output applicationInsightsName string = enableMonitoring ? monitoring.outputs.applicationInsightsName : ''
output managedIdentityPrincipalId string = appService.outputs.managedIdentityPrincipalId
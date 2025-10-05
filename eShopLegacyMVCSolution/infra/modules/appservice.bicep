// =============================================================================
// App Service module - Web app with managed identity and VNet integration
// =============================================================================

@description('The Azure region for deployment')
param location string

@description('Resource prefix for naming')
param resourcePrefix string

@description('Unique suffix for resource names')
param uniqueSuffix string

@description('App Service Plan SKU')
param appServicePlanSku string

@description('Key Vault ID for configuration')
param keyVaultId string

@description('App Service subnet ID for VNet integration')
param appServiceSubnetId string

@description('Application Insights connection string')
param applicationInsightsConnectionString string

@description('Application Insights instrumentation key')
param applicationInsightsInstrumentationKey string

// Extract Key Vault name from ID
var keyVaultName = last(split(keyVaultId, '/'))

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${resourcePrefix}-plan-${uniqueSuffix}'
  location: location
  sku: {
    name: appServicePlanSku
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// App Service
resource appService 'Microsoft.Web/sites@2023-12-01' = {
  name: '${resourcePrefix}-app-${uniqueSuffix}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: appServiceSubnetId
    vnetRouteAllEnabled: true
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|8.0'
      alwaysOn: appServicePlanSku != 'F1' && appServicePlanSku != 'D1'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      httpLoggingEnabled: true
      detailedErrorLoggingEnabled: true
      requestTracingEnabled: true
      http20Enabled: true
      use32BitWorkerProcess: false
      webSocketsEnabled: false
      managedPipelineMode: 'Integrated'
      remoteDebuggingEnabled: false
      appSettings: [
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Production'
        }
        {
          name: 'ASPNETCORE_URLS'
          value: 'http://+:8080'
        }
        // Application Insights configuration using Key Vault references
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=app-insights-connection-string)'
        }
        {
          name: 'ApplicationInsights__InstrumentationKey'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=app-insights-instrumentation-key)'
        }
        // Feature flags and app settings
        {
          name: 'AppSettings__UseMockData'
          value: 'false'
        }
        {
          name: 'AppSettings__UseCustomizationData'
          value: 'false'
        }
        // Key Vault reference for connection strings
        {
          name: 'KeyVault__VaultUri'
          value: 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/'
        }
        // Logging configuration
        {
          name: 'Logging__LogLevel__Default'
          value: 'Information'
        }
        {
          name: 'Logging__LogLevel__Microsoft.AspNetCore'
          value: 'Warning'
        }
        {
          name: 'Logging__LogLevel__Microsoft.EntityFrameworkCore'
          value: 'Information'
        }
        {
          name: 'Logging__LogLevel__eShopLegacyMVC'
          value: 'Debug'
        }
        {
          name: 'AllowedHosts'
          value: '*'
        }
      ]
      connectionStrings: [
        {
          name: 'CatalogDBContext'
          connectionString: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=sql-connection-string)'
          type: 'SQLAzure'
        }
      ]
    }
  }
}

// VNet Integration (already configured in properties above, this is for explicit dependency)
resource vnetIntegration 'Microsoft.Web/sites/networkConfig@2023-12-01' = {
  parent: appService
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: appServiceSubnetId
    swiftSupported: true
  }
}

// Deployment slot for staging (optional but recommended for enterprise)
resource stagingSlot 'Microsoft.Web/sites/slots@2023-12-01' = {
  parent: appService
  name: 'staging'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|8.0'
      alwaysOn: appServicePlanSku != 'F1' && appServicePlanSku != 'D1'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      appSettings: [
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Staging'
        }
        {
          name: 'ASPNETCORE_URLS'
          value: 'http://+:8080'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=app-insights-connection-string)'
        }
        {
          name: 'ApplicationInsights__InstrumentationKey'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=app-insights-instrumentation-key)'
        }
        {
          name: 'AppSettings__UseMockData'
          value: 'true'
        }
        {
          name: 'KeyVault__VaultUri'
          value: 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/'
        }
      ]
      connectionStrings: [
        {
          name: 'CatalogDBContext'
          connectionString: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=sql-connection-string)'
          type: 'SQLAzure'
        }
      ]
    }
  }
}

// Outputs
output appServiceName string = appService.name
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'
output stagingUrl string = 'https://${stagingSlot.properties.defaultHostName}'
output managedIdentityPrincipalId string = appService.identity.principalId
output stagingManagedIdentityPrincipalId string = stagingSlot.identity.principalId
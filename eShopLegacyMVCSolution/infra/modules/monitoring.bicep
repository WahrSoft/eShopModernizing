// =============================================================================
// Monitoring module - Application Insights and Log Analytics
// =============================================================================

@description('The Azure region for deployment')
param location string

@description('Resource prefix for naming')
param resourcePrefix string

@description('Unique suffix for resource names')
param uniqueSuffix string

@description('Key Vault ID for storing secrets')
param keyVaultId string

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${resourcePrefix}-law-${uniqueSuffix}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: 1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${resourcePrefix}-ai-${uniqueSuffix}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Store Application Insights Connection String in Key Vault
resource appInsightsConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${last(split(keyVaultId, '/'))}/app-insights-connection-string'
  properties: {
    value: applicationInsights.properties.ConnectionString
    attributes: {
      enabled: true
    }
  }
}

// Store Application Insights Instrumentation Key in Key Vault
resource appInsightsInstrumentationKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${last(split(keyVaultId, '/'))}/app-insights-instrumentation-key'
  properties: {
    value: applicationInsights.properties.InstrumentationKey
    attributes: {
      enabled: true
    }
  }
}

// Outputs
output applicationInsightsName string = applicationInsights.name
output connectionString string = applicationInsights.properties.ConnectionString
output instrumentationKey string = applicationInsights.properties.InstrumentationKey
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
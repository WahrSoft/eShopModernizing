// Application Insights for monitoring and telemetry
// Provides comprehensive application performance monitoring

@description('Resource name prefix')
param resourceNamePrefix string

@description('Location for all resources')
param location string

@description('Environment name')
param environmentName string

var appInsightsName = '${resourceNamePrefix}-ai'
var logAnalyticsName = '${resourceNamePrefix}-logs'

// Log Analytics Workspace for Application Insights
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: environmentName == 'prod' ? 90 : 30
    features: {
      searchVersion: 1
    }
  }
  tags: {
    Environment: environmentName
    Purpose: 'Application Logs'
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    // Sampling configuration
    SamplingPercentage: environmentName == 'prod' ? 10 : 100
    // Retention configuration
    RetentionInDays: environmentName == 'prod' ? 90 : 30
    // Enable ingestion and query
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: {
    Environment: environmentName
    Purpose: 'Application Monitoring'
  }
}

// Output
output appInsightsId string = appInsights.id
output appInsightsName string = appInsights.name
output instrumentationKey string = appInsights.properties.InstrumentationKey
output connectionString string = appInsights.properties.ConnectionString
output logAnalyticsWorkspaceId string = logAnalytics.id
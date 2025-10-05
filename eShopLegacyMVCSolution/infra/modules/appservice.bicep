// App Service with managed identity and secure configuration
// Hosts the eShopLegacyMVC application with enterprise security

@description('Resource name prefix')
param resourceNamePrefix string

@description('Location for all resources')
param location string

@description('Environment name')
param environmentName string

@description('Subnet ID for VNet integration')
param subnetId string

@description('Key Vault name for retrieving secrets')
param keyVaultName string

@description('SQL Server name')
param sqlServerName string

@description('SQL Database name')
param sqlDatabaseName string

@description('Application Insights connection string')
param appInsightsConnectionString string

var appServicePlanName = '${resourceNamePrefix}-asp'
var webAppName = '${resourceNamePrefix}-app'

// App Service Plan with appropriate sizing
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: environmentName == 'prod' ? 'P1v3' : 'S1'
    tier: environmentName == 'prod' ? 'PremiumV3' : 'Standard'
    size: environmentName == 'prod' ? 'P1v3' : 'S1'
    family: environmentName == 'prod' ? 'Pv3' : 'S'
    capacity: environmentName == 'prod' ? 2 : 1
  }
  properties: {
    reserved: false // Windows
    zoneRedundant: environmentName == 'prod' ? true : false
  }
  tags: {
    Environment: environmentName
    Purpose: 'App Service Plan'
  }
}

// Web App with security hardening
resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: webAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    redundancyMode: environmentName == 'prod' ? 'ActiveActive' : 'None'
    siteConfig: {
      // .NET 8 configuration
      netFrameworkVersion: 'v8.0'
      // Startup command for .NET 8 application
      appCommandLine: 'dotnet eShopLegacyMVC.dll'
      defaultDocuments: [
        'Default.htm'
        'Default.html'
        'Default.asp'
        'index.htm'
        'index.html'
        'iisstart.htm'
        'default.aspx'
        'index.php'
      ]
      httpLoggingEnabled: true
      logsDirectorySizeLimit: 35
      detailedErrorLoggingEnabled: true
      publishingUsername: '$${webAppName}'
      scmType: 'None'
      use32BitWorkerProcess: false
      webSocketsEnabled: false
      alwaysOn: true
      managedPipelineMode: 'Integrated'
      virtualApplications: [
        {
          virtualPath: '/'
          physicalPath: 'site\\wwwroot'
          preloadEnabled: true
        }
      ]
      loadBalancing: 'LeastRequests'
      autoHealEnabled: false
      vnetRouteAllEnabled: true
      vnetPrivatePortsCount: 0
      localMySqlEnabled: false
      // Configure IP restrictions
      ipSecurityRestrictions: [
        {
          ipAddress: 'Any'
          action: 'Allow'
          priority: 2147483647
          name: 'Allow all'
          description: 'Allow all access'
        }
      ]
      scmIpSecurityRestrictions: [
        {
          ipAddress: 'Any'
          action: 'Allow'
          priority: 2147483647
          name: 'Allow all'
          description: 'Allow all access'
        }
      ]
      scmIpSecurityRestrictionsUseMain: false
      http20Enabled: false
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      ftpsState: 'FtpsOnly'
      preWarmedInstanceCount: 0
      functionAppScaleLimit: 0
      functionsRuntimeScaleMonitoringEnabled: false
      minimumElasticInstanceCount: 0
      azureStorageAccounts: {}
    }
    scmSiteAlsoStopped: false
    hostingEnvironmentProfile: null
    clientAffinityEnabled: true
    clientCertEnabled: false
    clientCertMode: 'Required'
    hostNamesDisabled: false
    containerSize: 0
    dailyMemoryTimeQuota: 0
    cloningInfo: null
    reserved: false
    isXenon: false
    hyperV: false
    vnetImagePullEnabled: false
    vnetContentShareEnabled: false
    storageAccountRequired: false
    keyVaultReferenceIdentity: 'SystemAssigned'
  }
  tags: {
    Environment: environmentName
    Purpose: 'eShop Legacy MVC Application'
  }
}

// VNet Integration for App Service
resource webAppVnetConnection 'Microsoft.Web/sites/virtualNetworkConnections@2023-01-01' = {
  parent: webApp
  name: 'vnet-integration'
  properties: {
    vnetResourceId: subnetId
    isSwift: true
  }
}

// Role assignment for Key Vault access
resource webAppKeyVaultRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(webApp.id, keyVaultName, 'Key Vault Secrets User')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// App Settings with Key Vault references and secure configuration
resource webAppAppSettings 'Microsoft.Web/sites/config@2023-01-01' = {
  parent: webApp
  name: 'appsettings'
  properties: {
    // .NET Configuration
    ASPNETCORE_ENVIRONMENT: environmentName == 'prod' ? 'Production' : (environmentName == 'test' ? 'Staging' : 'Development')
    WEBSITE_RUN_FROM_PACKAGE: '1'
    
    // Application Insights
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsConnectionString
    ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
    XDT_MicrosoftApplicationInsights_Mode: 'Recommended'
    
    // Connection Strings (using Key Vault references)
    ConnectionStrings__CatalogDBContext: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=sql-connection-string)'
    ConnectionStrings__Redis: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=redis-connection-string)'
    ConnectionStrings__ApplicationInsights: appInsightsConnectionString
    
    // Application Configuration
    UseMockData: 'false'
    UseCustomizationData: 'false'
    
    // Cache Settings
    CacheSettings__UseRedis: 'true'
    CacheSettings__InstanceName: 'eShopLegacyMVC-${environmentName}'
    CacheSettings__SessionTimeoutMinutes: environmentName == 'prod' ? '60' : '30'
    
    // Security Headers
    WEBSITE_HTTPLOGGING_RETENTION_DAYS: '7'
    
    // Performance Settings
    WEBSITE_DYNAMIC_CACHE: '0'
    WEBSITE_LOCAL_CACHE_OPTION: 'Always'
    WEBSITE_LOCAL_CACHE_SIZEINMB: '1000'
    
    // .NET 8 specific settings
    DOTNET_STARTUP_HOOKS: ''
    DOTNET_USE_POLLING_FILE_WATCHER: 'true'
    ASPNETCORE_FORWARDEDHEADERS_ENABLED: 'true'
  }
  dependsOn: [
    webAppKeyVaultRole
  ]
}

// Create SQL connection string in Key Vault
resource sqlConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${keyVaultName}/sql-connection-string'
  properties: {
    value: 'Server=${sqlServerName}${environment().suffixes.sqlServerHostname};Database=${sqlDatabaseName};Authentication=Active Directory Managed Identity;TrustServerCertificate=True;'
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// SQL Database role assignment for the web app
resource webAppSqlRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(webApp.id, sqlServerName, 'SQL DB Contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec') // SQL DB Contributor
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Health check endpoint and optimized web configuration
resource webAppConfig 'Microsoft.Web/sites/config@2023-01-01' = {
  parent: webApp
  name: 'web'
  properties: {
    numberOfWorkers: environmentName == 'prod' ? 2 : 1
    requestTracingEnabled: true
    requestTracingExpirationTime: '9999-12-31T23:59:00Z'
    remoteDebuggingEnabled: false
    remoteDebuggingVersion: 'VS2019'
    httpLoggingEnabled: true
    acrUseManagedIdentityCreds: false
    acrUserManagedIdentityID: ''
    logsDirectorySizeLimit: 35
    detailedErrorLoggingEnabled: true
    scmType: 'None'
    use32BitWorkerProcess: false
    webSocketsEnabled: false
    alwaysOn: true
    javaVersion: ''
    javaContainer: ''
    javaContainerVersion: ''
    // Startup command for .NET 8 application
    appCommandLine: 'dotnet eShopLegacyMVC.dll'
    managedPipelineMode: 'Integrated'
    virtualApplications: [
      {
        virtualPath: '/'
        physicalPath: 'site\\wwwroot'
        preloadEnabled: true
        virtualDirectories: null
      }
    ]
    winAuthAdminState: 0
    winAuthTenantState: 0
    customAppPoolIdentityAdminState: false
    customAppPoolIdentityTenantState: false
    runtimeADUser: ''
    runtimeADUserPassword: ''
    loadBalancing: 'LeastRequests'
    routingRules: []
    experiments: {
      rampUpRules: []
    }
    limits: null
    autoHealEnabled: false
    vnetName: ''
    vnetRouteAllEnabled: true
    vnetPrivatePortsCount: 0
    publicNetworkAccess: 'Enabled'
    cors: null
    push: null
    apiDefinition: null
    apiManagementConfig: null
    autoSwapSlotName: ''
    localMySqlEnabled: false
    managedServiceIdentityId: null
    xManagedServiceIdentityId: null
    keyVaultReferenceIdentity: 'SystemAssigned'
    ipSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 2147483647
        name: 'Allow all'
        description: 'Allow all access'
      }
    ]
    scmIpSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 2147483647
        name: 'Allow all'
        description: 'Allow all access'
      }
    ]
    scmIpSecurityRestrictionsUseMain: false
    http20Enabled: false
    minTlsVersion: '1.2'
    scmMinTlsVersion: '1.2'
    ftpsState: 'FtpsOnly'
    preWarmedInstanceCount: 0
    functionAppScaleLimit: 0
    healthCheckPath: '/health'
    functionsRuntimeScaleMonitoringEnabled: false
    websiteTimeZone: ''
    minimumElasticInstanceCount: 0
    azureStorageAccounts: {}
    http20ProxyFlag: 0
    sitePort: null
    antivirusScanEnabled: false
    storageType: 1
  }
  dependsOn: [
    webAppAppSettings
  ]
}

// Output
output webAppId string = webApp.id
output webAppName string = webApp.name
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output webAppPrincipalId string = webApp.identity.principalId
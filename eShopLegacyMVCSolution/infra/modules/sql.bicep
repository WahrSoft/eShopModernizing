// SQL Server with managed identity authentication and private endpoint
// Follows security best practices with Entra ID authentication

@description('Resource name prefix')
param resourceNamePrefix string

@description('Location for all resources')
param location string

@description('Environment name')
param environmentName string

@description('SQL Admin Username')
param sqlAdminUsername string

@description('Subnet ID for private endpoint')
param subnetId string

@description('Key Vault name for storing secrets')
param keyVaultName string

@description('Current user object ID for SQL Entra Admin')
param currentUserObjectId string

@description('Current user UPN for SQL Entra Admin')
param currentUserPrincipalName string

var sqlServerName = '${resourceNamePrefix}-sql'
var sqlDatabaseName = 'CatalogDb'

// Generate a secure password for SQL admin (stored in Key Vault)
resource sqlAdminPassword 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'generate-sql-password'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '11.0'
    retentionInterval: 'PT1H'
    scriptContent: '''
      $password = -join ((33..126) | Get-Random -Count 32 | ForEach-Object {[char]$_})
      $DeploymentScriptOutputs = @{}
      $DeploymentScriptOutputs['password'] = $password
    '''
  }
}

// SQL Server with security hardening
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    version: '12.0'
    // Enable public access for firewall rules, but limit access via firewall
    publicNetworkAccess: 'Enabled'
    // Configure Microsoft Entra ID administrators
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'User'
      login: 'andywahrenberger_hotmail.com#EXT#@wahrenberger.onmicrosoft.com'
      sid: '1bc68466-61e0-4b35-9f61-370282a0f277'
      tenantId: '63bd38f1-34c1-494b-b15d-55e02d51586b'
      azureADOnlyAuthentication: true
    }
  }
  tags: {
    Environment: environmentName
    Purpose: 'Application Database'
  }
}

// Firewall rule to allow Azure services (needed for App Service and managed identity)
resource sqlFirewallRule 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// SQL Database with optimized settings
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  sku: {
    name: environmentName == 'prod' ? 'S2' : 'S0'
    tier: 'Standard'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: environmentName == 'prod' ? 268435456000 : 2147483648 // 250GB for prod, 2GB for dev/test
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    // Remove zone redundancy to avoid compatibility issues
    zoneRedundant: false
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: environmentName == 'prod' ? 'Geo' : 'Local'
  }
  tags: {
    Environment: environmentName
    Purpose: 'Catalog Database'
  }
  dependsOn: [
    sqlFirewallRule
  ]
}

// Store SQL connection string in Key Vault for application use
resource sqlConnectionString 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${keyVaultName}/sql-connection-string'
  properties: {
    value: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDatabase.name};Persist Security Info=False;User ID=${sqlAdminUsername};Password=${sqlAdminPassword.properties.outputs.password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Store SQL admin password in Key Vault
resource sqlPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${keyVaultName}/sql-admin-password'
  properties: {
    value: sqlAdminPassword.properties.outputs.password
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Private DNS Zone for SQL
resource sqlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink${environment().suffixes.sqlServerHostname}'
  location: 'global'
  tags: {
    Environment: environmentName
    Purpose: 'SQL Private DNS'
  }
}

// Private endpoint for SQL Server
resource sqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: '${sqlServerName}-pe'
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${sqlServerName}-connection'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: ['sqlServer']
        }
      }
    ]
  }
  tags: {
    Environment: environmentName
    Purpose: 'SQL Private Endpoint'
  }
}

// Private DNS Zone Group for SQL
resource sqlPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: sqlPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-database-windows-net'
        properties: {
          privateDnsZoneId: sqlPrivateDnsZone.id
        }
      }
    ]
  }
}

// Output
output sqlServerId string = sqlServer.id
output sqlServerName string = sqlServer.name
output sqlDatabaseName string = sqlDatabase.name
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
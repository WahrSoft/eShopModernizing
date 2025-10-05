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
      $output = @{
        password = $password
      }
      Write-Output $output | ConvertTo-Json
    '''
  }
}

// SQL Server with security hardening
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword.properties.outputs.password
    version: '12.0'
    // Disable public access
    publicNetworkAccess: 'Disabled'
    // Enable Microsoft Entra-only authentication
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'User'
      login: currentUserPrincipalName
      sid: currentUserObjectId
      tenantId: tenant().tenantId
      azureADOnlyAuthentication: true
    }
  }
  tags: {
    Environment: environmentName
    Purpose: 'Application Database'
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
    zoneRedundant: environmentName == 'prod' ? true : false
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: environmentName == 'prod' ? 'Geo' : 'Local'
  }
  tags: {
    Environment: environmentName
    Purpose: 'Catalog Database'
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

// Firewall rule to allow Azure services (needed for managed identity)
resource sqlFirewallRule 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Output
output sqlServerId string = sqlServer.id
output sqlServerName string = sqlServer.name
output sqlDatabaseName string = sqlDatabase.name
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
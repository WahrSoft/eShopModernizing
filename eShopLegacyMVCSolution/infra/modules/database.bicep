// =============================================================================
// Database module - SQL Server and Database with Entra authentication
// =============================================================================

@description('The Azure region for deployment')
param location string

@description('Resource prefix for naming')
param resourcePrefix string

@description('Unique suffix for resource names')
param uniqueSuffix string

@description('SQL Server administrator username')
param adminUsername string

@description('Database pricing tier')
param databaseTier string

@description('Database size/DTU')
param databaseSize string

@description('Object ID of the current user for Entra Admin')
param currentUserObjectId string

@description('Current user principal name for Entra Admin')
param currentUserPrincipalName string

@description('Key Vault ID for storing secrets')
param keyVaultId string

@description('Virtual Network ID for private endpoint')
param vnetId string

@description('Private endpoint subnet ID')
param privateEndpointSubnetId string

// Generate a secure password for SQL admin (fallback)
var sqlAdminPassword = '${toUpper(substring(uniqueString(resourceGroup().id, 'sql'), 0, 8))}${toLower(substring(uniqueString(resourceGroup().id, 'admin'), 0, 8))}${substring(uniqueString(resourceGroup().id, 'password'), 0, 4)}!'

// SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: '${resourcePrefix}-sql-${uniqueSuffix}'
  location: location
  properties: {
    administratorLogin: adminUsername
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled' // Enterprise security: private endpoints only
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'User'
      login: currentUserPrincipalName
      sid: currentUserObjectId
      tenantId: subscription().tenantId
      azureADOnlyAuthentication: false // Allow both Entra ID and SQL authentication
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: 'eShopCatalogDB'
  location: location
  sku: {
    name: databaseSize
    tier: databaseTier
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: databaseTier == 'Basic' ? 2147483648 : 268435456000 // 2GB for Basic, 250GB for others
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: databaseTier == 'Premium' || databaseTier == 'BusinessCritical'
    readScale: databaseTier == 'Premium' || databaseTier == 'BusinessCritical' ? 'Enabled' : 'Disabled'
  }
}

// Private DNS Zone for SQL Server
resource privateSqlDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink${environment().suffixes.sqlServerHostname}'
  location: 'global'
}

// Link Private DNS Zone to VNet
resource sqlVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateSqlDnsZone
  name: '${resourcePrefix}-sql-vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// Private Endpoint for SQL Server
resource sqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-06-01' = {
  name: '${resourcePrefix}-sql-pe-${uniqueSuffix}'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'sqlConnection'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}

// DNS Zone Group for SQL Private Endpoint
resource sqlPrivateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-06-01' = {
  parent: sqlPrivateEndpoint
  name: 'sqlDnsGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sqlServer'
        properties: {
          privateDnsZoneId: privateSqlDnsZone.id
        }
      }
    ]
  }
}

// Store SQL admin password in Key Vault
resource sqlAdminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${last(split(keyVaultId, '/'))}/sql-admin-password'
  properties: {
    value: sqlAdminPassword
    attributes: {
      enabled: true
    }
  }
}

// Store SQL connection string in Key Vault (using managed identity)
resource sqlConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${last(split(keyVaultId, '/'))}/sql-connection-string'
  properties: {
    value: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Database=${sqlDatabase.name};Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
    attributes: {
      enabled: true
    }
  }
}

// Outputs
output sqlServerName string = sqlServer.name
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output databaseName string = sqlDatabase.name
output sqlServerId string = sqlServer.id
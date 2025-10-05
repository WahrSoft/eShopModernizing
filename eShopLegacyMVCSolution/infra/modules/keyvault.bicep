// Key Vault with private endpoint and security best practices
// Stores application secrets with proper access controls

@description('Resource name prefix')
param resourceNamePrefix string

@description('Location for all resources')
param location string

@description('Environment name')
param environmentName string

@description('Subnet ID for private endpoint')
param subnetId string

@description('Current user object ID for access')
param currentUserObjectId string

var keyVaultName = '${resourceNamePrefix}-kv'

// Key Vault with security hardening
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    // Disable public access - only private endpoint access
    publicNetworkAccess: 'Disabled'
    // Enable purge protection for production
    enablePurgeProtection: environmentName == 'prod' ? true : false
    // Enable soft delete (default 90 days)
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    // Enable RBAC for access management
    enableRbacAuthorization: true
    // Network access restrictions
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
  }
  tags: {
    Environment: environmentName
    Purpose: 'Application Secrets'
  }
}

// Role assignment for current user as Key Vault Administrator
resource keyVaultAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, currentUserObjectId, 'Key Vault Administrator')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483') // Key Vault Administrator
    principalId: currentUserObjectId
    principalType: 'User'
  }
}

// Private DNS Zone for Key Vault
resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: {
    Environment: environmentName
    Purpose: 'Key Vault Private DNS'
  }
}

// Private endpoint for Key Vault
resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: '${keyVaultName}-pe'
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${keyVaultName}-connection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: ['vault']
        }
      }
    ]
  }
  tags: {
    Environment: environmentName
    Purpose: 'Key Vault Private Endpoint'
  }
}

// Private DNS Zone Group
resource keyVaultPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: keyVaultPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-vaultcore-azure-net'
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZone.id
        }
      }
    ]
  }
}

// Output
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
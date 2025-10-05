// =============================================================================
// Key Vault Access module - RBAC assignments for App Service managed identity
// =============================================================================

@description('Key Vault name')
param keyVaultName string

@description('App Service managed identity principal ID')
param appServicePrincipalId string

// Reference existing Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// Grant App Service managed identity Key Vault Secrets User role
resource appServiceKeyVaultSecretsAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, appServicePrincipalId, '4633458b-17de-408a-b874-0445c86b69e6')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: appServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Grant App Service managed identity Key Vault Certificate User role (for SSL certificates if needed)
resource appServiceKeyVaultCertificateAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, appServicePrincipalId, 'db79e9a7-68ee-4b58-9aeb-b90e7c24fcba')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'db79e9a7-68ee-4b58-9aeb-b90e7c24fcba') // Key Vault Certificate User
    principalId: appServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Output
output keyVaultRoleAssignmentId string = appServiceKeyVaultSecretsAccess.id
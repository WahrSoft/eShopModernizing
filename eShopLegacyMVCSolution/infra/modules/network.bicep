// =============================================================================
// Network module - Virtual Network and Subnets configuration
// =============================================================================

@description('The Azure region for deployment')
param location string

@description('Resource prefix for naming')
param resourcePrefix string

@description('Unique suffix for resource names')
param uniqueSuffix string

@description('Virtual network configuration')
param vnetConfig object

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: '${resourcePrefix}-vnet-${uniqueSuffix}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetConfig.addressPrefix
      ]
    }
    subnets: [
      {
        name: vnetConfig.subnets.appService.name
        properties: {
          addressPrefix: vnetConfig.subnets.appService.addressPrefix
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
              locations: [
                location
              ]
            }
            {
              service: 'Microsoft.Sql'
              locations: [
                location
              ]
            }
          ]
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
              }
            }
          ]
        }
      }
      {
        name: vnetConfig.subnets.privateEndpoints.name
        properties: {
          addressPrefix: vnetConfig.subnets.privateEndpoints.addressPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: vnetConfig.subnets.sql.name
        properties: {
          addressPrefix: vnetConfig.subnets.sql.addressPrefix
          serviceEndpoints: [
            {
              service: 'Microsoft.Sql'
              locations: [
                location
              ]
            }
          ]
        }
      }
    ]
  }
}

// Network Security Group for App Service subnet
resource appServiceNsg 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: '${resourcePrefix}-appservice-nsg-${uniqueSuffix}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPS'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowHTTP'
        properties: {
          priority: 1010
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Network Security Group for Private Endpoints subnet
resource privateEndpointsNsg 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: '${resourcePrefix}-pe-nsg-${uniqueSuffix}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowVnetInbound'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Associate NSG with App Service subnet
resource appServiceSubnetNsgAssociation 'Microsoft.Network/virtualNetworks/subnets@2023-06-01' = {
  parent: vnet
  name: vnetConfig.subnets.appService.name
  properties: {
    addressPrefix: vnetConfig.subnets.appService.addressPrefix
    networkSecurityGroup: {
      id: appServiceNsg.id
    }
    serviceEndpoints: [
      {
        service: 'Microsoft.KeyVault'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.Sql'
        locations: [
          location
        ]
      }
    ]
    delegations: [
      {
        name: 'delegation'
        properties: {
          serviceName: 'Microsoft.Web/serverfarms'
        }
      }
    ]
  }
}

// Associate NSG with Private Endpoints subnet
resource privateEndpointsSubnetNsgAssociation 'Microsoft.Network/virtualNetworks/subnets@2023-06-01' = {
  parent: vnet
  name: vnetConfig.subnets.privateEndpoints.name
  properties: {
    addressPrefix: vnetConfig.subnets.privateEndpoints.addressPrefix
    networkSecurityGroup: {
      id: privateEndpointsNsg.id
    }
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    appServiceSubnetNsgAssociation
  ]
}

// Outputs
output vnetId string = vnet.id
output vnetName string = vnet.name
output appServiceSubnetId string = '${vnet.id}/subnets/${vnetConfig.subnets.appService.name}'
output privateEndpointSubnetId string = '${vnet.id}/subnets/${vnetConfig.subnets.privateEndpoints.name}'
output sqlSubnetId string = '${vnet.id}/subnets/${vnetConfig.subnets.sql.name}'
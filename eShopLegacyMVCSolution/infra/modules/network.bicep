// Network infrastructure with security best practices
// Creates VNet with private subnets and Network Security Groups

@description('Resource name prefix')
param resourceNamePrefix string

@description('Location for all resources')
param location string

@description('Environment name')
param environmentName string

// Network configuration
var vnetName = '${resourceNamePrefix}-vnet'
var vnetAddressPrefix = '10.0.0.0/16'

// Subnet configurations
var subnetConfigs = [
  {
    name: 'app-service-subnet'
    addressPrefix: '10.0.1.0/24'
    delegations: [
      {
        name: 'Microsoft.Web.serverFarms'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
    serviceEndpoints: [
      'Microsoft.KeyVault'
      'Microsoft.Sql'
      'Microsoft.Storage'
    ]
  }
  {
    name: 'sql-subnet'
    addressPrefix: '10.0.2.0/24'
    delegations: []
    serviceEndpoints: [
      'Microsoft.Sql'
    ]
  }
  {
    name: 'redis-subnet'
    addressPrefix: '10.0.3.0/24'
    delegations: []
    serviceEndpoints: []
  }
  {
    name: 'keyvault-subnet'
    addressPrefix: '10.0.4.0/24'
    delegations: []
    serviceEndpoints: [
      'Microsoft.KeyVault'
    ]
  }
  {
    name: 'private-endpoint-subnet'
    addressPrefix: '10.0.5.0/24'
    delegations: []
    serviceEndpoints: []
  }
]

// Network Security Groups
resource nsgAppService 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${resourceNamePrefix}-app-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPS'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1100
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
        }
      }
    ]
  }
  tags: {
    Environment: environmentName
    Purpose: 'App Service NSG'
  }
}

resource nsgSQL 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${resourceNamePrefix}-sql-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowAppServiceSQL'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: '10.0.1.0/24' // App Service subnet
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
        }
      }
    ]
  }
  tags: {
    Environment: environmentName
    Purpose: 'SQL NSG'
  }
}

resource nsgRedis 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${resourceNamePrefix}-redis-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowAppServiceRedis'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['6379', '6380']
          sourceAddressPrefix: '10.0.1.0/24' // App Service subnet
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
        }
      }
    ]
  }
  tags: {
    Environment: environmentName
    Purpose: 'Redis NSG'
  }
}

resource nsgKeyVault 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${resourceNamePrefix}-kv-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowAppServiceKeyVault'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '10.0.1.0/24' // App Service subnet
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
        }
      }
    ]
  }
  tags: {
    Environment: environmentName
    Purpose: 'Key Vault NSG'
  }
}

resource nsgPrivateEndpoint 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${resourceNamePrefix}-pe-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowVNetInBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
    ]
  }
  tags: {
    Environment: environmentName
    Purpose: 'Private Endpoint NSG'
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: subnetConfigs[0].name
        properties: {
          addressPrefix: subnetConfigs[0].addressPrefix
          delegations: subnetConfigs[0].delegations
          serviceEndpoints: [for endpoint in subnetConfigs[0].serviceEndpoints: {
            service: endpoint
          }]
          networkSecurityGroup: {
            id: nsgAppService.id
          }
        }
      }
      {
        name: subnetConfigs[1].name
        properties: {
          addressPrefix: subnetConfigs[1].addressPrefix
          serviceEndpoints: [for endpoint in subnetConfigs[1].serviceEndpoints: {
            service: endpoint
          }]
          networkSecurityGroup: {
            id: nsgSQL.id
          }
        }
      }
      {
        name: subnetConfigs[2].name
        properties: {
          addressPrefix: subnetConfigs[2].addressPrefix
          networkSecurityGroup: {
            id: nsgRedis.id
          }
        }
      }
      {
        name: subnetConfigs[3].name
        properties: {
          addressPrefix: subnetConfigs[3].addressPrefix
          serviceEndpoints: [for endpoint in subnetConfigs[3].serviceEndpoints: {
            service: endpoint
          }]
          networkSecurityGroup: {
            id: nsgKeyVault.id
          }
        }
      }
      {
        name: subnetConfigs[4].name
        properties: {
          addressPrefix: subnetConfigs[4].addressPrefix
          networkSecurityGroup: {
            id: nsgPrivateEndpoint.id
          }
        }
      }
    ]
  }
  tags: {
    Environment: environmentName
    Purpose: 'Main VNet'
  }
}

// Outputs
output vnetId string = vnet.id
output vnetName string = vnet.name
output appServiceSubnetId string = vnet.properties.subnets[0].id
output sqlSubnetId string = vnet.properties.subnets[1].id
output redisSubnetId string = vnet.properties.subnets[2].id
output keyVaultSubnetId string = vnet.properties.subnets[3].id
output privateEndpointSubnetId string = vnet.properties.subnets[4].id
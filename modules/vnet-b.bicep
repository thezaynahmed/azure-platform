// =============================================================================
// Virtual Network B Module
// Deploys VNet B with Windows and Linux application subnets
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Environment prefix')
param environment string

@description('Company/Organization prefix for naming')
param companyPrefix string

@description('Admin username for all VMs')
param adminUsername string

@description('Admin password for Windows VMs')
@secure()
param adminPassword string

@description('SSH public key for Linux VMs')
param sshPublicKey string

@description('VM size for all virtual machines')
param vmSize string

@description('Storage account ID for diagnostics')
param storageAccountId string

// =============================================================================
// Variables
// =============================================================================

var namingConvention = {
  vnet: 'vnet-${companyPrefix}-${environment}'
  vm: 'vm-${companyPrefix}'
  nic: 'nic-${companyPrefix}'
  nsg: 'nsg-${companyPrefix}-${environment}'
  pip: 'pip-${companyPrefix}'
}

var vnetBConfig = {
  name: '${namingConvention.vnet}-vnetb'
  addressSpace: '10.1.0.0/24'
  subnets: [
    {
      name: 'WindowsSubnet'
      addressPrefix: '10.1.0.0/27'
      vmCount: 3
      vmType: 'windows'
      vmRole: 'app'
    }
    {
      name: 'LinuxSubnet'
      addressPrefix: '10.1.0.32/27'
      vmCount: 3
      vmType: 'linux'
      vmRole: 'web'
    }
  ]
}

// =============================================================================
// Network Security Groups for VNet B subnets
// =============================================================================

resource nsgVnetB 'Microsoft.Network/networkSecurityGroups@2023-09-01' = [for subnet in vnetBConfig.subnets: {
  name: '${namingConvention.nsg}-${toLower(subnet.name)}'
  location: location
  properties: {
    securityRules: concat(
      subnet.vmType == 'windows' ? [
        {
          name: 'AllowRDP'
          properties: {
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '3389'
            sourceAddressPrefix: '*'
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 1000
            direction: 'Inbound'
          }
        }
        {
          name: 'AllowHTTPS'
          properties: {
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '443'
            sourceAddressPrefix: '*'
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 1001
            direction: 'Inbound'
          }
        }
        {
          name: 'AllowHTTP'
          properties: {
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '80'
            sourceAddressPrefix: '*'
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 1002
            direction: 'Inbound'
          }
        }
      ] : [
        {
          name: 'AllowSSH'
          properties: {
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '22'
            sourceAddressPrefix: '*'
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 1000
            direction: 'Inbound'
          }
        }
        {
          name: 'AllowHTTPS'
          properties: {
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '443'
            sourceAddressPrefix: '*'
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 1001
            direction: 'Inbound'
          }
        }
        {
          name: 'AllowHTTP'
          properties: {
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '80'
            sourceAddressPrefix: '*'
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 1002
            direction: 'Inbound'
          }
        }
      ],
      [
        {
          name: 'AllowVnetInbound'
          properties: {
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRange: '*'
            sourceAddressPrefix: 'VirtualNetwork'
            destinationAddressPrefix: 'VirtualNetwork'
            access: 'Allow'
            priority: 4000
            direction: 'Inbound'
          }
        }
      ]
    )
  }
  tags: {
    Environment: environment
    CompanyPrefix: companyPrefix
    VNet: 'VNetB'
  }
}]

// =============================================================================
// Virtual Network B with subnets
// =============================================================================

resource vnetB 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetBConfig.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnetBConfig.addressSpace]
    }
    subnets: [for (subnet, index) in vnetBConfig.subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        networkSecurityGroup: {
          id: nsgVnetB[index].id
        }
      }
    }]
  }
  tags: {
    Environment: environment
    CompanyPrefix: companyPrefix
    Purpose: 'Application and web infrastructure'
  }
  dependsOn: [
    nsgVnetB
  ]
}

// =============================================================================
// Virtual Machines for VNet B
// =============================================================================

module vnetBVMs 'vm.bicep' = [for (subnet, subnetIndex) in vnetBConfig.subnets: {
  name: 'vnetB-${subnet.name}-vms'
  params: {
    location: location
    vnetName: vnetB.name
    subnetName: subnet.name
    vmType: subnet.vmType
    vmCount: subnet.vmCount
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    sshPublicKey: sshPublicKey
    storageAccountId: storageAccountId
    enablePublicIPs: false // VNet B VMs use private IPs only
    namingPrefix: '${namingConvention.vm}-${subnet.vmRole}-${environment}-${location}-'
    nicNamingPrefix: '${namingConvention.nic}-${subnet.vmRole}-${environment}-${location}-'
    pipNamingPrefix: '${namingConvention.pip}-${subnet.vmRole}-${environment}-${location}-'
  }
}]

// =============================================================================
// Outputs
// =============================================================================

output vnetId string = vnetB.id
output vnetName string = vnetB.name
output vnetAddressSpace string = vnetBConfig.addressSpace
output subnetIds array = [for (subnet, index) in vnetBConfig.subnets: {
  name: subnet.name
  id: vnetB.properties.subnets[index].id
  addressPrefix: subnet.addressPrefix
}]
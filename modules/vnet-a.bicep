// =============================================================================
// Virtual Network A Module
// Deploys VNet A with Management, AD, and Automation subnets
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

@description('Admin public IP address for RDP access')
param adminPublicIPAddress string = ''

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

var vnetAConfig = {
  name: '${namingConvention.vnet}-vneta'
  addressSpace: '10.0.0.0/24'
  subnets: [
    {
      name: 'MGMTSubnet'
      addressPrefix: '10.0.0.0/27'
      vmCount: 1
      vmType: 'windows'
      vmRole: 'mgmt'
    }
    {
      name: 'ADSubnet'
      addressPrefix: '10.0.0.32/27'
      vmCount: 2
      vmType: 'windows'
      vmRole: 'adds'
    }
    {
      name: 'AutomationSubnet'
      addressPrefix: '10.0.0.64/27'
      vmCount: 1
      vmType: 'linux'
      vmRole: 'auto'
    }
  ]
}

// =============================================================================
// Network Security Groups for VNet A subnets
// =============================================================================

resource nsgVnetA 'Microsoft.Network/networkSecurityGroups@2023-09-01' = [for (subnet, subnetIndex) in vnetAConfig.subnets: {
  name: '${namingConvention.nsg}-${toLower(subnet.name)}'
  location: location
  properties: {
    securityRules: concat(
      subnet.vmType == 'windows' ? concat(
        // RDP rules based on subnet type
        subnet.name == 'MGMTSubnet' && adminPublicIPAddress != '' ? [
          {
            name: 'AllowRDPFromAdmin'
            properties: {
              protocol: 'Tcp'
              sourcePortRange: '*'
              destinationPortRange: '3389'
              sourceAddressPrefix: adminPublicIPAddress
              destinationAddressPrefix: '*'
              access: 'Allow'
              priority: 1000
              direction: 'Inbound'
            }
          }
        ] : subnet.name != 'MGMTSubnet' ? [
          {
            name: 'AllowRDPFromVNet'
            properties: {
              protocol: 'Tcp'
              sourcePortRange: '*'
              destinationPortRange: '3389'
              sourceAddressPrefix: 'VirtualNetwork'
              destinationAddressPrefix: '*'
              access: 'Allow'
              priority: 1000
              direction: 'Inbound'
            }
          }
        ] : [],
        // Common Windows rules
        [
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
        ]
      ) : [
        {
          name: 'AllowSSH'
          properties: {
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '22'
            sourceAddressPrefix: 'VirtualNetwork'
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 1000
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
    VNet: 'VNetA'
  }
}]

// =============================================================================
// Virtual Network A with subnets
// =============================================================================

resource vnetA 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetAConfig.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAConfig.addressSpace]
    }
    subnets: [for (subnet, index) in vnetAConfig.subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        networkSecurityGroup: {
          id: nsgVnetA[index].id
        }
      }
    }]
  }
  tags: {
    Environment: environment
    CompanyPrefix: companyPrefix
    Purpose: 'Management and AD infrastructure'
  }
  dependsOn: [
    nsgVnetA
  ]
}

// =============================================================================
// Virtual Machines for VNet A
// =============================================================================

module vnetAVMs 'vm.bicep' = [for (subnet, subnetIndex) in vnetAConfig.subnets: {
  name: 'vnetA-${subnet.name}-vms'
  params: {
    location: location
    vnetName: vnetA.name
    subnetName: subnet.name
    vmType: subnet.vmType
    vmCount: subnet.vmCount
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    sshPublicKey: sshPublicKey
    storageAccountId: storageAccountId
    enablePublicIPs: subnet.name == 'MGMTSubnet' && adminPublicIPAddress != ''
    namingPrefix: '${namingConvention.vm}-${subnet.vmRole}-${environment}-${location}-'
    nicNamingPrefix: '${namingConvention.nic}-${subnet.vmRole}-${environment}-${location}-'
    pipNamingPrefix: '${namingConvention.pip}-${subnet.vmRole}-${environment}-${location}-'
  }
}]

// =============================================================================
// Outputs
// =============================================================================

output vnetId string = vnetA.id
output vnetName string = vnetA.name
output vnetAddressSpace string = vnetAConfig.addressSpace
output subnetIds array = [for (subnet, index) in vnetAConfig.subnets: {
  name: subnet.name
  id: vnetA.properties.subnets[index].id
  addressPrefix: subnet.addressPrefix
}]
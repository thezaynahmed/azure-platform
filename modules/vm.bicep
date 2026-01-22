// =============================================================================
// Virtual Machine Module
// Creates Windows or Linux VMs with proper naming conventions
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Virtual Network name')
param vnetName string

@description('Subnet name')
param subnetName string

@description('VM type: windows or linux')
@allowed(['windows', 'linux'])
param vmType string

@description('Number of VMs to create')
param vmCount int

@description('VM size')
param vmSize string

@description('Admin username')
param adminUsername string

@description('Admin password for Windows VMs')
@secure()
param adminPassword string

@description('SSH public key for Linux VMs')
param sshPublicKey string

@description('Storage account ID for diagnostics')
param storageAccountId string

@description('Naming prefix for VMs')
param namingPrefix string

@description('Naming prefix for NICs')
param nicNamingPrefix string

@description('Naming prefix for Public IPs')
param pipNamingPrefix string

@description('Enable public IP addresses for VMs')
param enablePublicIPs bool = false

// =============================================================================
// Variables
// =============================================================================

var windowsImageReference = {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: '2025-datacenter-azure-edition'
  version: 'latest'
}

var linuxImageReference = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-jammy'
  sku: '22_04-lts-gen2'
  version: 'latest'
}

var imageReference = vmType == 'windows' ? windowsImageReference : linuxImageReference

// =============================================================================
// Get existing VNet and subnet
// =============================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  parent: vnet
  name: subnetName
}

// =============================================================================
// Public IP addresses (conditional)
// =============================================================================

resource publicIPs 'Microsoft.Network/publicIPAddresses@2023-09-01' = [for i in range(0, vmCount): if (enablePublicIPs) {
  name: '${pipNamingPrefix}${padLeft(i + 1, 3, '0')}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: '${toLower(namingPrefix)}${padLeft(i + 1, 3, '0')}-${uniqueString(resourceGroup().id)}'
    }
  }
}]

// =============================================================================
// Network Interfaces
// =============================================================================

resource networkInterfaces 'Microsoft.Network/networkInterfaces@2023-09-01' = [for i in range(0, vmCount): {
  name: '${nicNamingPrefix}${padLeft(i + 1, 3, '0')}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: union(
          {
            privateIPAllocationMethod: 'Dynamic'
            subnet: {
              id: subnet.id
            }
          },
          enablePublicIPs ? {
            publicIPAddress: {
              id: publicIPs[i].id
            }
          } : {}
        )
      }
    ]
    enableAcceleratedNetworking: true
  }
  dependsOn: enablePublicIPs ? [
    publicIPs
  ] : []
}]

// =============================================================================
// Virtual Machines
// =============================================================================

resource virtualMachines 'Microsoft.Compute/virtualMachines@2023-09-01' = [for i in range(0, vmCount): {
  name: '${namingPrefix}${padLeft(i + 1, 3, '0')}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: vmType == 'windows' ? {
      computerName: '${namingPrefix}${padLeft(i + 1, 3, '0')}'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
        }
      }
    } : {
      computerName: '${namingPrefix}${padLeft(i + 1, 3, '0')}'
      adminUsername: adminUsername
      disablePasswordAuthentication: true
      linuxConfiguration: {
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
        patchSettings: {
          patchMode: 'ImageDefault'
          assessmentMode: 'ImageDefault'
        }
      }
    }
    storageProfile: {
      imageReference: imageReference
      osDisk: {
        name: '${namingPrefix}${padLeft(i + 1, 3, '0')}-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        diskSizeGB: vmType == 'windows' ? 127 : 30
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaces[i].id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: reference(storageAccountId, '2023-01-01').primaryEndpoints.blob
      }
    }
  }
  dependsOn: [
    networkInterfaces
  ]
}]

// =============================================================================
// VM Extensions
// =============================================================================

// Windows VM Extensions
resource windowsVMExtensions 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for i in range(0, vmCount): if (vmType == 'windows') {
  parent: virtualMachines[i]
  name: 'AzureMonitorWindowsAgent'
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {}
  }
}]

// Linux VM Extensions
resource linuxVMExtensions 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for i in range(0, vmCount): if (vmType == 'linux') {
  parent: virtualMachines[i]
  name: 'AzureMonitorLinuxAgent'
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {}
  }
}]

// =============================================================================
// Outputs
// =============================================================================

output vmNames array = [for i in range(0, vmCount): virtualMachines[i].name]
output privateIPAddresses array = [for i in range(0, vmCount): networkInterfaces[i].properties.ipConfigurations[0].properties.privateIPAddress]
output publicIPAddresses array = enablePublicIPs ? [for i in range(0, vmCount): publicIPs[i].properties.ipAddress] : []
output fqdns array = enablePublicIPs ? [for i in range(0, vmCount): publicIPs[i].properties.dnsSettings.fqdn] : []
// =============================================================================
// Azure Multi-VNet Infrastructure with Separate Resource Groups
// This template orchestrates deployment across multiple resource groups
// and establishes VNet peering between networks
// =============================================================================

targetScope = 'subscription'

@description('Environment prefix (e.g., prod, dev, test)')
@allowed(['dev', 'test', 'prod'])
param environment string = 'prod'

@description('Location for all resources')
param location string = 'centralus'

@description('Company/Organization prefix for naming')
param companyPrefix string = 'tmb'

@description('Admin username for all VMs')
param adminUsername string

@description('Admin password for Windows VMs')
@secure()
param adminPassword string

@description('SSH public key for Linux VMs')
param sshPublicKey string

@description('VM size for all virtual machines')
param vmSize string = 'Standard_B2s'

@description('Admin public IP address for RDP access to management server')
param adminPublicIPAddress string = ''

// =============================================================================
// Variables for naming conventions
// =============================================================================

var namingConvention = {
  resourceGroup: 'rg-${companyPrefix}-${environment}'
  vnet: 'vnet-${companyPrefix}-${environment}'
  storage: 'st${companyPrefix}${environment}'
}

var resourceGroups = {
  shared: '${namingConvention.resourceGroup}-shared-${location}'
  vnetA: '${namingConvention.resourceGroup}-vneta-${location}'
  vnetB: '${namingConvention.resourceGroup}-vnetb-${location}'
}

// =============================================================================
// Resource Groups
// =============================================================================

resource sharedResourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroups.shared
  location: location
  tags: {
    Environment: environment
    CompanyPrefix: companyPrefix
    Purpose: 'Shared resources for multi-vnet infrastructure'
  }
}

resource vnetAResourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroups.vnetA
  location: location
  tags: {
    Environment: environment
    CompanyPrefix: companyPrefix
    Purpose: 'Virtual Network A - Management and AD infrastructure'
  }
}

resource vnetBResourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroups.vnetB
  location: location
  tags: {
    Environment: environment
    CompanyPrefix: companyPrefix
    Purpose: 'Virtual Network B - Application and web infrastructure'
  }
}

// =============================================================================
// Shared Resources (Storage Account for diagnostics)
// =============================================================================

module sharedResources 'modules/shared.bicep' = {
  name: 'shared-resources'
  scope: sharedResourceGroup
  params: {
    location: location
    environment: environment
    companyPrefix: companyPrefix
  }
}

// =============================================================================
// Virtual Network A Infrastructure
// =============================================================================

module vnetAInfrastructure 'modules/vnet-a.bicep' = {
  name: 'vnet-a-infrastructure'
  scope: vnetAResourceGroup
  params: {
    location: location
    environment: environment
    companyPrefix: companyPrefix
    adminUsername: adminUsername
    adminPassword: adminPassword
    sshPublicKey: sshPublicKey
    vmSize: vmSize
    storageAccountId: sharedResources.outputs.storageAccountId
    adminPublicIPAddress: adminPublicIPAddress
  }
}

// =============================================================================
// Virtual Network B Infrastructure
// =============================================================================

module vnetBInfrastructure 'modules/vnet-b.bicep' = {
  name: 'vnet-b-infrastructure'
  scope: vnetBResourceGroup
  params: {
    location: location
    environment: environment
    companyPrefix: companyPrefix
    adminUsername: adminUsername
    adminPassword: adminPassword
    sshPublicKey: sshPublicKey
    vmSize: vmSize
    storageAccountId: sharedResources.outputs.storageAccountId
  }
}

// =============================================================================
// VNet Peering Configuration
// =============================================================================

module vnetPeering 'modules/vnet-peering.bicep' = {
  name: 'vnet-peering'
  scope: vnetAResourceGroup
  params: {
    vnetAName: vnetAInfrastructure.outputs.vnetName
    vnetAResourceGroupName: resourceGroups.vnetA
    vnetBId: vnetBInfrastructure.outputs.vnetId
    vnetBName: vnetBInfrastructure.outputs.vnetName
    vnetBResourceGroupName: resourceGroups.vnetB
  }
  dependsOn: [
    vnetAInfrastructure
    vnetBInfrastructure
  ]
}

// =============================================================================
// Outputs
// =============================================================================

output resourceGroups object = {
  shared: sharedResourceGroup.name
  vnetA: vnetAResourceGroup.name
  vnetB: vnetBResourceGroup.name
}

output vnetDetails object = {
  vnetA: {
    id: vnetAInfrastructure.outputs.vnetId
    name: vnetAInfrastructure.outputs.vnetName
    addressSpace: vnetAInfrastructure.outputs.vnetAddressSpace
  }
  vnetB: {
    id: vnetBInfrastructure.outputs.vnetId
    name: vnetBInfrastructure.outputs.vnetName
    addressSpace: vnetBInfrastructure.outputs.vnetAddressSpace
  }
}

output peeringStatus object = {
  vnetATovnetB: vnetPeering.outputs.peeringVnetATovnetB
  vnetBTovnetA: vnetPeering.outputs.peeringVnetBTovnetA
}

output storageAccount object = {
  name: sharedResources.outputs.storageAccountName
  resourceGroup: sharedResourceGroup.name
}
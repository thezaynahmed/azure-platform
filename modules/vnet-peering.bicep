// =============================================================================
// VNet Peering Module
// Establishes bidirectional peering between VNet A and VNet B
// =============================================================================

@description('VNet A name')
param vnetAName string

@description('VNet A resource group name')
param vnetAResourceGroupName string

@description('VNet B ID')
param vnetBId string

@description('VNet B name')
param vnetBName string

@description('VNet B resource group name')
param vnetBResourceGroupName string

// =============================================================================
// Get reference to VNet A (local to this module's scope)
// =============================================================================

resource vnetA 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: vnetAName
}

// =============================================================================
// VNet Peering: VNet A to VNet B
// =============================================================================

resource peeringVnetATovnetB 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: vnetA
  name: 'peer-${vnetAName}-to-${vnetBName}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: vnetBId
    }
  }
}

// =============================================================================
// VNet Peering: VNet B to VNet A (using module for cross-resource group deployment)
// =============================================================================

module peeringVnetBTovnetA 'vnet-peering-reverse.bicep' = {
  name: 'peering-vnetb-to-vneta'
  scope: resourceGroup(vnetBResourceGroupName)
  params: {
    localVnetName: vnetBName
    remoteVnetId: vnetA.id
    remoteVnetName: vnetAName
    peeringName: 'peer-${vnetBName}-to-${vnetAName}'
  }
}

// =============================================================================
// Outputs
// =============================================================================

output peeringVnetATovnetB object = {
  name: peeringVnetATovnetB.name
  id: peeringVnetATovnetB.id
  peeringState: peeringVnetATovnetB.properties.peeringState
}

output peeringVnetBTovnetA object = {
  name: peeringVnetBTovnetA.outputs.peeringName
  id: peeringVnetBTovnetA.outputs.peeringId
  peeringState: peeringVnetBTovnetA.outputs.peeringState
}
// =============================================================================
// VNet Peering Reverse Module
// Creates peering from VNet B back to VNet A (for cross-resource group deployment)
// =============================================================================

@description('Local VNet name (VNet B)')
param localVnetName string

@description('Remote VNet ID (VNet A)')
param remoteVnetId string

@description('Remote VNet name (VNet A)')
param remoteVnetName string

@description('Peering name')
param peeringName string

// =============================================================================
// Get reference to local VNet (VNet B)
// =============================================================================

resource localVnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: localVnetName
}

// =============================================================================
// VNet Peering: VNet B to VNet A
// =============================================================================

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: localVnet
  name: peeringName
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: remoteVnetId
    }
  }
}

// =============================================================================
// Outputs
// =============================================================================

output peeringName string = peering.name
output peeringId string = peering.id
output peeringState string = peering.properties.peeringState
// =============================================================================
// Shared Resources Module
// Contains resources shared across multiple VNets (storage account for diagnostics)
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Environment prefix')
param environment string

@description('Company/Organization prefix for naming')
param companyPrefix string

// =============================================================================
// Variables
// =============================================================================

var storageAccountName = 'st${companyPrefix}${environment}shared${uniqueString(resourceGroup().id)}'

// =============================================================================
// Storage Account for VM diagnostics
// =============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
  tags: {
    Environment: environment
    CompanyPrefix: companyPrefix
    Purpose: 'VM Boot Diagnostics'
  }
}

// =============================================================================
// Outputs
// =============================================================================

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output storageAccountBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
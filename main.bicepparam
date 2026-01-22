// =============================================================================
// Parameters file for Azure Multi-VNet Infrastructure deployment
// Update these values according to your environment and requirements
// =============================================================================

using 'main.bicep'

// Environment configuration
param environment = 'prod'
param location = 'centralus'
param companyPrefix = 'tmb'

// VM configuration
param adminUsername = 'azureadmin'

// Note: These sensitive parameters should be provided during deployment
// Example deployment command (subscription-level deployment):
// az deployment sub create \
//   --location centralus \
//   --template-file main.bicep \
//   --parameters main.bicepparam \
//   --parameters adminPassword='YourSecurePassword123!' \
//   --parameters sshPublicKey='ssh-rsa AAAAB3NzaC1yc2E...' \
//   --parameters adminPublicIPAddress='203.0.113.1'

param vmSize = 'Standard_B2s'

// Optional: Admin public IP for RDP access to management server
// If not provided, management server will only have private IP
// param adminPublicIPAddress = '203.0.113.1'

// For production deployments, consider using:
// - Standard_D2s_v3 for general purpose workloads
// - Standard_B4ms for burstable performance
// - Standard_D4s_v3 for domain controllers (AD VMs)

// This deployment will create the following resource groups:
// - rg-{companyPrefix}-{environment}-shared-{location}
// - rg-{companyPrefix}-{environment}-vneta-{location}
// - rg-{companyPrefix}-{environment}-vnetb-{location}
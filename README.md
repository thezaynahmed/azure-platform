# Azure Multi-VNet Infrastructure with Bicep

This repository contains Azure Bicep templates for deploying a multi-Virtual Network infrastructure across separate resource groups with VNet peering, following Azure naming conventions and best practices.

## Architecture Overview

The template deploys infrastructure across **3 separate resource groups**:

### Resource Groups
1. **Shared Resources** (`rg-{company}-{env}-shared-{location}`)
   - Storage account for VM boot diagnostics

2. **Virtual Network A** (`rg-{company}-{env}-vneta-{location}`)
   - Management and Active Directory infrastructure

3. **Virtual Network B** (`rg-{company}-{env}-vnetb-{location}`)
   - Application and web infrastructure

### Virtual Network A (`/24` - 10.0.0.0/24)
- **MGMTSubnet** (`/27` - 10.0.0.0/27)
  - 1x Windows Server 2025 VM for management
- **ADSubnet** (`/27` - 10.0.0.32/27)
  - 2x Windows Server 2025 VMs for Active Directory
- **AutomationSubnet** (`/27` - 10.0.0.64/27)
  - 1x Ubuntu Server 22.04 LTS VM for automation

### Virtual Network B (`/24` - 10.1.0.0/24)
- **WindowsSubnet** (`/27` - 10.1.0.0/27)
  - 3x Windows Server 2025 VMs for applications
- **LinuxSubnet** (`/27` - 10.1.0.32/27)
  - 3x Ubuntu Server 22.04 LTS VMs for web services

### VNet Peering
- **Bidirectional peering** between VNet A and VNet B
- Full connectivity between networks with traffic forwarding enabled
- No gateway transit (can be enabled if needed)

## Naming Convention

All resources follow Azure naming conventions with the format:
- VMs: `vm-{company}-{role}-{environment}-{location}-{instance}`
- NICs: `nic-{company}-{role}-{environment}-{location}-{instance}`
- Public IPs: `pip-{company}-{role}-{environment}-{location}-{instance}`

Example: `vm-tmb-adds-prod-centralus-001`

## Files Structure

```
.
├── main.bicep                    # Main orchestration template (subscription scope)
├── main.bicepparam               # Parameters file
├── modules/
│   ├── shared.bicep             # Shared resources (storage account)
│   ├── vnet-a.bicep             # VNet A infrastructure
│   ├── vnet-b.bicep             # VNet B infrastructure
│   ├── vnet-peering.bicep       # VNet peering configuration
│   ├── vnet-peering-reverse.bicep # Cross-RG peering helper
│   └── vm.bicep                 # VM deployment module
├── deploy.sh                     # Deployment script (subscription level)
├── .gitignore                    # Bicep-specific gitignore
└── README.md                     # This file
```

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and configured
- Azure subscription with **Contributor** or **Owner** permissions (for resource group creation)
- SSH key pair for Linux VMs

## Quick Start

### 1. Generate SSH Key Pair (if you don't have one)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/azure_key
```

### 2. Deploy using the script (creates all resource groups automatically)

```bash
./deploy.sh \
  --admin-password "YourSecurePassword123!" \
  --ssh-key "$(cat ~/.ssh/azure_key.pub)"
```

### 3. Deploy with custom parameters

```bash
./deploy.sh \
  --location "eastus" \
  --environment "dev" \
  --company-prefix "contoso" \
  --admin-username "azureadmin" \
  --admin-password "YourSecurePassword123!" \
  --ssh-key "$(cat ~/.ssh/azure_key.pub)" \
  --vm-size "Standard_D2s_v3"
```

## Manual Deployment

### Subscription-Level Deployment (Recommended)

This deployment automatically creates all required resource groups:

```bash
az deployment sub create \
  --location "centralus" \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters adminPassword='YourSecurePassword123!' \
  --parameters sshPublicKey='ssh-rsa AAAAB3NzaC1yc2E...'
```

### Resource Groups Created Automatically

- `rg-tmb-prod-shared-centralus` (shared storage)
- `rg-tmb-prod-vneta-centralus` (VNet A infrastructure)
- `rg-tmb-prod-vnetb-centralus` (VNet B infrastructure)

## Parameters

### Required Parameters
- `adminPassword`: Admin password for Windows VMs
- `sshPublicKey`: SSH public key for Linux VMs

### Optional Parameters
- `environment`: Environment (dev/test/prod) - Default: `prod`
- `location`: Azure region - Default: `centralus`
- `companyPrefix`: Company prefix for naming - Default: `tmb`
- `adminUsername`: Admin username - Default: `azureadmin`
- `vmSize`: VM size - Default: `Standard_B2s`

## Security Features

- **Network Security Groups (NSGs)** on each subnet with appropriate rules
- **VNet-to-VNet communication** allowed through peering
- **RDP access** (port 3389) for Windows VMs
- **SSH access** (port 22) for Linux VMs
- **HTTP/HTTPS access** (ports 80/443) for application VMs
- **Boot diagnostics** enabled on all VMs
- **Premium SSD storage** for OS disks
- **Azure Monitor agents** automatically installed
- **Resource group isolation** for better governance and access control

## VM Images

- **Windows**: Windows Server 2025 Datacenter Azure Edition
- **Linux**: Ubuntu Server 22.04 LTS (Gen2)

## Recommended VM Sizes

- **Development**: `Standard_B2s` (2 vCPU, 4 GB RAM)
- **Production**:
  - General workloads: `Standard_D2s_v3` (2 vCPU, 8 GB RAM)
  - Domain Controllers: `Standard_D4s_v3` (4 vCPU, 16 GB RAM)
  - High-performance: `Standard_F4s_v2` (4 vCPU, 8 GB RAM)

## Post-Deployment

After successful deployment:

1. **Connect to Windows VMs**: Use RDP with the FQDN from outputs
2. **Connect to Linux VMs**: Use SSH with the private key and FQDN
3. **Test VNet Connectivity**: Verify communication between VNet A and VNet B
4. **Configure Domain Controllers**: Set up AD DS on the ADSubnet VMs
5. **Network Security**: Review and adjust NSG rules as needed
6. **Monitoring**: Configure Azure Monitor and Log Analytics

## Network Connectivity

With VNet peering established:

- **VMs in VNet A can communicate with VMs in VNet B** using private IPs
- **No additional routing** required
- **Traffic stays within Azure backbone** (secure and fast)
- **NSG rules apply** - ensure proper security rules for cross-VNet communication

Example: A VM in ADSubnet (10.0.0.32/27) can directly reach a VM in WindowsSubnet (10.1.0.0/27).

## Cost Optimization

- Use `Standard_B` series VMs for variable workloads
- Stop VMs when not in use to save compute costs
- Consider Reserved Instances for production workloads
- Use Standard HDD for non-critical workloads
- **Resource group separation** allows for granular cost tracking and management

## Cleanup

To delete all resources, delete the resource groups:

```bash
# Delete all resource groups (adjust names based on your parameters)
az group delete --name "rg-tmb-prod-shared-centralus" --yes --no-wait
az group delete --name "rg-tmb-prod-vneta-centralus" --yes --no-wait
az group delete --name "rg-tmb-prod-vnetb-centralus" --yes --no-wait
```

Or use the deployment script cleanup (if available):

```bash
# Delete by environment/company prefix
az group delete --name "rg-${COMPANY_PREFIX}-${ENVIRONMENT}-*" --yes --no-wait
```

## Support

For issues or questions:
1. Check the [Azure Bicep documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
2. Review [Azure naming conventions](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
3. Validate templates using `az deployment group validate`# azure-platform

# GitHub Actions CI/CD for Azure Infrastructure

This directory contains GitHub Actions workflows for automating Azure infrastructure deployment using Bicep templates.

## 🚀 Workflows Overview

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| **Main Deployment** | `azure-infrastructure-deploy.yml` | Push to `main`, Manual | Deploy infrastructure to production |
| **PR Validation** | `pr-validation.yml` | Pull requests to `main` | Validate changes before merge |
| **Development** | `deploy-dev.yml` | Push to `develop`, Manual | Deploy to dev environment |
| **Production** | `deploy-prod.yml` | Manual only | Secure production deployment |
| **Cleanup** | `cleanup-resources.yml` | Manual only | Delete Azure resources |

## 🔧 Prerequisites

### 1. Azure Service Principal

Create a service principal with appropriate permissions:

```bash
# Create service principal
az ad sp create-for-rbac --name "github-actions-sp" --role "Owner" --scopes "/subscriptions/YOUR_SUBSCRIPTION_ID"
```

This will output:
```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

### 2. GitHub Repository Secrets

Add these secrets to your GitHub repository (`Settings > Secrets and variables > Actions`):

#### Required Secrets
```bash
AZURE_CREDENTIALS='{"clientId":"xxx","clientSecret":"xxx","subscriptionId":"xxx","tenantId":"xxx"}'
AZURE_SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
AZURE_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
AZURE_CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
AZURE_CLIENT_SECRET="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
AZURE_ADMIN_PASSWORD="YourSecurePassword123!"
SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... your-key-comment"
```

### 3. Environment Protection Rules (Recommended)

Set up environment protection rules for production:

1. Go to `Settings > Environments`
2. Create `production` environment
3. Add protection rules:
   - Required reviewers (1-2 people)
   - Wait timer (optional)
   - Restrict to main branch

## 📋 Workflow Details

### Main Deployment Workflow (`azure-infrastructure-deploy.yml`)

**Triggers:**
- Push to `main` branch (when Bicep files change)
- Manual dispatch with custom parameters

**Features:**
- ✅ Bicep template validation
- 🔍 What-If deployment analysis
- 🚀 Full infrastructure deployment
- 📊 Post-deployment verification
- 📈 Deployment reporting

**Manual Parameters:**
- `environment`: dev, test, prod
- `location`: Azure region
- `companyPrefix`: Naming prefix
- `vmSize`: VM size for all VMs
- `adminPublicIPAddress`: Admin public IP (optional)

### PR Validation Workflow (`pr-validation.yml`)

**Triggers:**
- Pull requests to `main` branch

**Features:**
- ✅ Bicep syntax validation
- 🔍 Best practices checking
- 🛡️ Security analysis
- 💰 Cost estimation
- 📋 What-If analysis
- 💬 Automated PR comments

**Special Features:**
- Add `[deploy-test]` in PR description to trigger test deployment
- Automatic PR commenting with validation results

### Development Deployment (`deploy-dev.yml`)

**Triggers:**
- Push to `develop` branch
- Manual dispatch

**Features:**
- 🔧 Cost-optimized VM sizes (Standard_B2s)
- 🚀 Quick deployment without approvals
- ⚡ Simplified verification

### Production Deployment (`deploy-prod.yml`)

**Triggers:**
- Manual dispatch only

**Features:**
- ⚠️ Requires typing "CONFIRM" to proceed
- 🛡️ Environment protection rules
- 📊 Comprehensive validation
- 🔍 Extended post-deployment verification
- 📈 Detailed reporting
- 💪 Production-grade VM sizes

### Cleanup Workflow (`cleanup-resources.yml`)

**Triggers:**
- Manual dispatch only

**Features:**
- 🗑️ Safe resource deletion
- 📋 Resource listing before deletion
- 💰 Cost savings estimation
- ⏳ Deletion monitoring
- 🛡️ Confirmation requirements

**Cleanup Types:**
- `specific-rg`: Delete expected resource groups
- `all-matching`: Delete all matching resource groups
- `list-only`: List resources without deleting

## 🎯 Usage Examples

### Deploy to Development

```yaml
# Automatic on push to develop branch
git push origin develop

# Manual deployment
# Go to Actions > Deploy to Development > Run workflow
```

### Deploy to Production

```yaml
# Go to Actions > Deploy to Production > Run workflow
# Fill in parameters:
# - companyPrefix: "tmb"
# - location: "centralus"
# - vmSize: "Standard_D2s_v3"
# - adminPublicIPAddress: "203.0.113.1"
# - confirm_production: "CONFIRM"
```

### Create Pull Request

```yaml
# Create PR with validation
git checkout -b feature/new-infrastructure
# Make changes to Bicep files
git add .
git commit -m "Add new infrastructure"
git push origin feature/new-infrastructure
# Create PR - validation will run automatically

# To trigger test deployment, include [deploy-test] in PR description
```

### Cleanup Resources

```yaml
# Go to Actions > Cleanup Azure Resources > Run workflow
# Fill in parameters:
# - environment: "dev"
# - companyPrefix: "tmb"
# - location: "centralus"
# - cleanup_type: "all-matching"
# - confirm_deletion: "DELETE"
```

## 🔒 Security Best Practices

### Service Principal Permissions

The service principal needs these permissions:
- **Owner** role on the subscription (for resource group creation)
- Or specific roles:
  - `Contributor` (deploy resources)
  - `User Access Administrator` (assign roles to managed identities)

### Secret Management

- ✅ Store all credentials as GitHub secrets
- ✅ Use environment protection for production
- ✅ Rotate service principal credentials regularly
- ✅ Use OIDC authentication when possible (alternative setup)

### Network Security

- ✅ Limit admin public IP to specific addresses
- ✅ Use NSG rules appropriately
- ✅ Consider private endpoints for storage

## 🐛 Troubleshooting

### Common Issues

#### Authentication Failed
```bash
Error: AADSTS7000215: Invalid client secret is provided
```
**Solution:** Verify `AZURE_CLIENT_SECRET` in GitHub secrets

#### Insufficient Permissions
```bash
Error: The client does not have authorization to perform action 'Microsoft.Resources/subscriptions/resourcegroups/write'
```
**Solution:** Ensure service principal has `Owner` or `Contributor` role

#### Template Validation Failed
```bash
Error: The template deployment failed because of policy violation
```
**Solution:** Check Azure Policy restrictions in your subscription

#### Resource Group Already Exists
```bash
Error: The resource group 'rg-tmb-prod-shared-centralus' already exists
```
**Solution:** This is expected - the template will update existing resources

### Debug Mode

Enable debug logging by adding this to workflow:

```yaml
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

### Manual Deployment for Testing

If workflows fail, test manually:

```bash
# Login to Azure
az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID

# Test deployment
az deployment sub create \
  --location "centralus" \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters adminPassword="YourPassword123!" \
  --parameters sshPublicKey="$(cat ~/.ssh/azure_key.pub)" \
  --what-if
```

## 📊 Monitoring & Notifications

### GitHub Actions Monitoring

- Check workflow runs in `Actions` tab
- Review deployment summaries in workflow outputs
- Monitor resource costs in Azure Cost Management

### Custom Notifications

Add your notification webhooks to these workflow sections:
- End of `azure-infrastructure-deploy.yml` (success/failure)
- End of `deploy-prod.yml` (production deployments)
- End of `cleanup-resources.yml` (resource cleanup)

Example webhook integration:
```yaml
- name: Send Slack notification
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## 🔄 Workflow Customization

### Adding New Environments

1. Create new workflow file (e.g., `deploy-staging.yml`)
2. Copy from `deploy-dev.yml`
3. Update environment name and parameters
4. Add environment protection rules if needed

### Custom VM Sizes

Update the `vmSize` choices in workflow files:
```yaml
vmSize:
  type: choice
  options:
    - Standard_B2s      # Basic, cost-effective
    - Standard_D2s_v3   # General purpose
    - Standard_F4s_v2   # Compute optimized
    - Standard_E4s_v3   # Memory optimized
```

### Additional Validation

Add custom validation steps to `pr-validation.yml`:
```yaml
- name: Custom validation
  run: |
    # Your custom validation logic
    echo "Running custom validation..."
```

## 📝 Changelog

### Version 1.0 (Current)
- ✅ Main deployment workflow
- ✅ PR validation with automated comments
- ✅ Environment-specific deployments
- ✅ Resource cleanup workflow
- ✅ Security best practices
- ✅ Cost estimation
- ✅ Comprehensive documentation

### Planned Features
- 🔄 OIDC authentication support
- 📊 Advanced cost analysis
- 🔔 Enhanced notification integrations
- 🏗️ Multi-subscription support
- 📈 Deployment metrics dashboard
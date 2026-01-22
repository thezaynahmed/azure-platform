# GitHub Actions Setup Guide

This guide will help you set up GitHub Actions for your Azure infrastructure deployment in 5 minutes.

## 🚀 Quick Setup Checklist

### Step 1: Create Azure Service Principal

Run this command in Azure CLI:

```bash
# Replace YOUR_SUBSCRIPTION_ID with your actual subscription ID
az ad sp create-for-rbac \
  --name "github-actions-sp" \
  --role "Owner" \
  --scopes "/subscriptions/YOUR_SUBSCRIPTION_ID"
```

**Save the output** - you'll need it in Step 2:
```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

### Step 2: Add GitHub Secrets

Go to your GitHub repository > **Settings** > **Secrets and variables** > **Actions** > **New repository secret**

Add these 6 secrets:

| Secret Name | Value |
|-------------|-------|
| `AZURE_CREDENTIALS` | `{"clientId":"xxx","clientSecret":"xxx","subscriptionId":"xxx","tenantId":"xxx"}` |
| `AZURE_SUBSCRIPTION_ID` | Your subscription ID |
| `AZURE_TENANT_ID` | Your tenant ID |
| `AZURE_CLIENT_ID` | Your client ID |
| `AZURE_CLIENT_SECRET` | Your client secret |
| `AZURE_ADMIN_PASSWORD` | `YourSecurePassword123!` (12+ characters) |
| `SSH_PUBLIC_KEY` | `ssh-rsa AAAAB3NzaC1yc2E...` (your public key) |

### Step 3: Generate SSH Key (if needed)

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -C "azure-github-actions"

# Copy public key content
cat ~/.ssh/id_rsa.pub
# Use this as the value for SSH_PUBLIC_KEY secret
```

### Step 4: Set Up Environment Protection (Optional but Recommended)

1. Go to **Settings** > **Environments**
2. Click **New environment** > Name it `production`
3. Add **Protection rules**:
   - ✅ **Required reviewers**: Add 1-2 team members
   - ✅ **Wait timer**: 5 minutes (optional)
   - ✅ **Deployment branches**: Only `main`

### Step 5: Test the Setup

1. **Create a Pull Request**:
   ```bash
   git checkout -b test/github-actions
   echo "# Test" >> README.md
   git add . && git commit -m "Test GitHub Actions"
   git push origin test/github-actions
   ```

2. **Create PR** on GitHub - validation will run automatically

3. **Deploy to Development**:
   - Go to **Actions** tab
   - Click **Deploy to Development**
   - Click **Run workflow**
   - Use default values and click **Run workflow**

## 🎯 First Deployment

### Quick Dev Deployment

After setup, deploy to development:

1. Go to **Actions** > **Deploy to Development** > **Run workflow**
2. Use these settings:
   - **companyPrefix**: `dev-test`
   - **location**: `centralus`
3. Click **Run workflow**

This will create:
- 3 Resource Groups
- 10 Virtual Machines
- 2 Virtual Networks with peering
- Network Security Groups
- Storage Account

Expected deployment time: **20-30 minutes**

### Production Deployment

For production (requires manual approval):

1. Go to **Actions** > **Deploy to Production** > **Run workflow**
2. Fill in parameters:
   - **companyPrefix**: `mycompany`
   - **location**: `centralus`
   - **vmSize**: `Standard_D2s_v3`
   - **adminPublicIPAddress**: `YOUR.PUBLIC.IP` (optional)
   - **confirm_production**: `CONFIRM`
3. Click **Run workflow**
4. **Approve** the deployment when prompted

## 🧹 Cleanup Resources

To avoid charges, cleanup test resources:

1. Go to **Actions** > **Cleanup Azure Resources** > **Run workflow**
2. Settings:
   - **environment**: `dev`
   - **companyPrefix**: `dev-test` (same as used in deployment)
   - **location**: `centralus`
   - **cleanup_type**: `all-matching`
   - **confirm_deletion**: `DELETE`
3. Click **Run workflow**

## 🔧 Troubleshooting

### Common Issues

**❌ Authentication Failed**
```
Error: AADSTS7000215: Invalid client secret
```
✅ **Solution**: Check `AZURE_CLIENT_SECRET` in GitHub secrets

**❌ Permission Denied**
```
Error: The client does not have authorization to perform action
```
✅ **Solution**: Ensure service principal has `Owner` role

**❌ SSH Key Format Error**
```
Error: Invalid SSH public key format
```
✅ **Solution**: SSH key should start with `ssh-rsa` or `ssh-ed25519`

**❌ Weak Password Error**
```
Error: Password does not meet complexity requirements
```
✅ **Solution**: Password needs 12+ chars, uppercase, lowercase, number, special char

### Test Manually

If GitHub Actions fail, test the deployment manually:

```bash
# Login to Azure
az login --service-principal \
  -u $AZURE_CLIENT_ID \
  -p $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID

# Test What-If deployment
az deployment sub what-if \
  --location "centralus" \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters adminPassword="YourPassword123!" \
  --parameters sshPublicKey="$(cat ~/.ssh/id_rsa.pub)"
```

## 📋 Next Steps

Once setup is complete:

1. ✅ Create a feature branch and test PR validation
2. ✅ Deploy to development environment
3. ✅ Review Azure resources in portal
4. ✅ Test production deployment workflow
5. ✅ Set up branch protection rules
6. ✅ Add team members as required reviewers
7. ✅ Customize VM sizes and parameters as needed

## 🎉 You're Ready!

Your GitHub Actions CI/CD pipeline is now configured for:

- ✅ **Automated validation** on pull requests
- ✅ **Multi-environment deployments** (dev, test, prod)
- ✅ **Infrastructure as Code** with Bicep
- ✅ **Secure secret management**
- ✅ **Cost optimization** with cleanup workflows
- ✅ **Production safeguards** with manual approvals

Happy deploying! 🚀
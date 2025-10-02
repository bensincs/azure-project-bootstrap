# Bootstrap Terraform Backend

Creates a shared Azure Storage backend for Terraform state and sets up GitHub Actions OIDC authentication.

## What This Creates

**Azure Resources:**
- Resource group: `rg-terraform-state`
- Storage account with random suffix (e.g., `sttfstate12345678`)
- Storage container: `tfstate`
- Managed identity: `id-github-actions-deploy` with:
  - Owner role on subscription
  - Storage Blob Data Contributor on state storage
  - Federated credentials for GitHub Actions (main branch + PRs)

**Generated Files:**
- Backend config files (`.hcl`) for each stack/environment
- Tfvars files (`.tfvars`) for each environment

**GitHub Secrets** (created automatically):
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

## Prerequisites

```bash
# 1. Azure CLI - logged in
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# 2. GitHub CLI - logged in
gh auth login
gh auth status
```

## How to Run

```bash
cd infra/bootstrap

# Initialize Terraform
terraform init

# Apply (creates everything)
terraform apply \
  -var="subscription_id=YOUR_SUBSCRIPTION_ID" \
  -var="github_repository=owner/repo-name"
```

**Example:**
```bash
terraform apply \
  -var="subscription_id=dd78ec54-2f00-41fc-8055-8c1f2ad66a1d" \
  -var="github_repository=bensincs/azure-project-bootstrap"
```

That's it! The bootstrap will:
1. Create the Azure backend infrastructure
2. Create the managed identity with all permissions
3. Set up federated credentials for GitHub Actions
4. Generate backend config files for your stacks
5. Automatically create GitHub secrets for OIDC auth

## Verify

```bash
# Check GitHub secrets were created
gh secret list

# Check Azure resources
az group show --name rg-terraform-state
```

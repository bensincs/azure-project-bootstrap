# Bootstrap Shared Terraform Backend

This bootstrap configuration creates a single shared Azure Storage Account backend for multiple Terraform stacks, with each stack using a unique state file key. It also creates a managed identity with federated credentials for secure GitHub Actions deployments.

## What This Creates

- **Resource Group**: `rg-terraform-state` - Shared resource group for all Terraform state
- **Storage Account**: Random suffix for uniqueness
- **Storage Container**: `tfstate` - Contains all state files
- **Managed Identity**: `id-github-actions-deploy` - For GitHub Actions authentication
- **Federated Credentials**: OIDC authentication for GitHub Actions (main branch + PRs)
- **RBAC Permissions**:
  - Storage Blob Data Contributor on the state storage account
  - Owner on the subscription for resource deployments
- **Backend Config Files**: Generated `.hcl` files for each stack/environment
- **Tfvars Files**: Generated `.tfvars` files for each environment

## Structure

```
bootstrap/
├── main.tf                    # Main configuration
├── README.md                  # This file
└── Generated files (gitignored):
    ├── terraform.tfstate
    └── terraform.tfstate.backup
```

## Usage

### 1. First Time Setup

Initialize and apply to create the shared backend and GitHub Actions identity:

```bash
cd infra/bootstrap
terraform init
terraform apply \
  -var="subscription_id=YOUR_SUBSCRIPTION_ID" \
  -var="github_repository=owner/repo-name"
```

**Example:**
```bash
terraform apply \
  -var="subscription_id=12345678-1234-1234-1234-123456789abc" \
  -var="github_repository=bensincs/azure-project-bootstrap"
```

This will create:
- One resource group: `rg-terraform-state`
- One storage account (with random suffix)
- One storage container: `tfstate`
- Managed identity for GitHub Actions with federated credentials
- Backend config files for each stack/environment (e.g., `../core/backends/backend-dev.hcl`)
- Tfvars files for each environment (e.g., `../core/vars/dev.tfvars`)

### 2. Configure GitHub Secrets

After applying, note the outputs and configure these GitHub repository secrets:

```bash
# Get the values from Terraform output
terraform output github_actions_identity
```

Then set these secrets in your GitHub repository (Settings → Secrets and variables → Actions):

- `AZURE_CLIENT_ID` - The client_id from the output
- `AZURE_TENANT_ID` - The tenant_id from the output
- `AZURE_SUBSCRIPTION_ID` - The subscription_id from the output

### 3. Use in GitHub Actions

Create a workflow file (e.g., `.github/workflows/deploy.yml`):

```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Terraform Init
        run: |
          cd infra/core
          terraform init -backend-config=backends/backend-dev.hcl

      - name: Terraform Plan
        run: |
          cd infra/core
          terraform plan -var-file=vars/dev.tfvars
```

### 4. Add More Stacks or Environments

To add additional stacks or environments, edit `main.tf` and add new entries to the `backends` local:

```hcl
locals {
  location            = "uaenorth"
  resource_group_name = "rg-terraform-state"

  # Define stacks and their environments
  backends = {
    "core/dev" = {
      state_key       = "core/dev.tfstate"
      backend_path    = "${path.module}/../core/backends/backend-dev.hcl"
      tfvars_path     = "${path.module}/../core/vars/dev.tfvars"
      environment     = "dev"
      location        = "uaenorth"
      subscription_id = var.subscription_id
    }
    # Add more environments
    "core/staging" = {
      state_key       = "core/staging.tfstate"
      backend_path    = "${path.module}/../core/backends/backend-staging.hcl"
      tfvars_path     = "${path.module}/../core/vars/staging.tfvars"
      environment     = "staging"
      location        = "uaenorth"
      subscription_id = var.subscription_id
    }
  }
}
```

Then run:

```bash
terraform apply \
  -var="subscription_id=YOUR_SUBSCRIPTION_ID" \
  -var="github_repository=owner/repo-name"
```

### 5. Use the Backend Config in Your Infrastructure Stacks

In your infrastructure directories (e.g., `core/`), initialize Terraform with the appropriate backend config:

```bash
cd infra/core
terraform init -backend-config=backends/backend-dev.hcl
terraform apply -var-file=vars/dev.tfvars
```

## Backend Configuration

Each generated backend config file (e.g., `backend-dev.hcl`) contains:

```hcl
resource_group_name  = "rg-terraform-state"
storage_account_name = "sttfstate<random>"
container_name       = "tfstate"
key                  = "core/dev.tfstate"   # Unique for each stack/environment
use_azuread_auth     = true
```

## GitHub Actions Identity

The managed identity created has:

- **Name**: `id-github-actions-deploy`
- **Permissions**:
  - Storage Blob Data Contributor (on state storage account)
  - Owner (on subscription)
- **Federated Credentials**:
  - Main branch: `repo:owner/repo:ref:refs/heads/main`
  - Pull requests: `repo:owner/repo:pull_request`
- **Authentication**: OIDC (no secrets required!)

## Features

- **Shared Infrastructure**: All stacks share the same storage account, resource group, and container
- **Isolated State Files**: Each stack has its own state file (different `key` value)
- **Azure AD Authentication**: Uses Azure AD instead of storage account keys
- **Secure GitHub Actions**: OIDC-based authentication with no secrets to rotate
- **Easy to Add Stacks**: Just add a new entry to `backends` local
- **Cost Efficient**: Only one storage account for all your stacks
- **Subscription-level Permissions**: Identity can deploy any Azure resource

## Outputs

After applying, you'll see output showing:

```
backend_configs = {
  "core/dev" = {
    "backend_path" = "../core/backends/backend-dev.hcl"
    "environment" = "dev"
    "state_key" = "core/dev.tfstate"
    "tfvars_path" = "../core/vars/dev.tfvars"
  }
}

container_name = "tfstate"

github_actions_identity = {
  "client_id" = "12345678-1234-1234-1234-123456789abc"
  "principal_id" = "87654321-4321-4321-4321-cba987654321"
  "subscription_id" = "your-subscription-id"
  "tenant_id" = "abcdefgh-ijkl-mnop-qrst-uvwxyz123456"
}

resource_group_name = "rg-terraform-state"
storage_account_name = "sttfstateh496o9r3"
```

## Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `subscription_id` | Azure subscription ID to deploy into | Yes | - |
| `github_repository` | GitHub repository in format `owner/repo` | No | `bensincs/azure-project-bootstrap` |

## Security Considerations

⚠️ **Important**: The managed identity has Owner permissions on the subscription. To secure your setup:

1. **Keep your repository private** or carefully control access
2. **Enable branch protection** on main branch
3. **Require PR reviews** before merging
4. **Use CODEOWNERS** file to control who can approve infrastructure changes
5. **Monitor Azure Activity Logs** for the identity's actions
6. **Consider using environments** in GitHub Actions with approval gates
7. **Rotate federated credentials** if repository access is compromised

## Cleanup

To destroy the shared backend:

```bash
cd infra/bootstrap
terraform destroy \
  -var="subscription_id=YOUR_SUBSCRIPTION_ID" \
  -var="github_repository=owner/repo-name"
```

**Warning**: This will delete all remote state storage for all stacks. Make sure to backup or destroy all dependent infrastructure stacks first.

## Troubleshooting

### Federated Credential Issues

If GitHub Actions fails to authenticate:

1. Verify the repository name is correct in the `github_repository` variable
2. Check that GitHub secrets are set correctly (client_id, tenant_id, subscription_id)
3. Ensure workflow has `permissions: id-token: write`
4. Verify the branch name matches (default is `main`)

### Storage Access Issues

If Terraform can't access state:

1. Ensure you're logged in with `az login`
2. Verify you have permissions on the storage account
3. Check that `use_azuread_auth = true` is in your backend config

### Permission Issues

If the identity can't create resources:

1. Verify the Owner role assignment was successful
2. Check Azure Activity Logs for denied operations
3. Allow up to 5 minutes for RBAC permissions to propagate

# Bootstrap Terraform Backend

Creates a shared Azure Storage backend for Terraform state and sets up GitHub Actions OIDC authentication.

## What This Creates

**Azure Resources:**
- Resource group: `rg-terraform-state`
- Storage account with random suffix (e.g., `sttfstate12345678`)
- Storage container: `tfstate`
- Service principal: `github-actions-deploy` with:
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
2. Create the service principal with all permissions
3. Set up federated credentials for GitHub Actions
4. Generate backend config files for your stacks
5. Automatically create GitHub secrets for OIDC auth

## Verify

```bash
# Check GitHub secrets were created
gh secret list

# Check Azure resources
az group show --name rg-terraform-state

# Check Key Vault and certificate
terraform output key_vault_name
az keyvault certificate show \
  --vault-name $(terraform output -raw key_vault_name) \
  --name app-gateway-ssl-cert
```

## SSL Certificate Management

### Default Certificate
The bootstrap creates a self-signed certificate for development. **Replace this with a real certificate for production**.

### Upload Your Own Certificate

```bash
# Get Key Vault name
KEY_VAULT_NAME=$(terraform output -raw key_vault_name)

# Upload your certificate
az keyvault certificate import \
  --vault-name $KEY_VAULT_NAME \
  --name app-gateway-ssl-cert \
  --file /path/to/certificate.pfx \
  --password "YourCertPassword"
```

See `../SSL-CERTIFICATE.md` for detailed certificate management instructions.

## Bootstrap Outputs

The bootstrap automatically updates `infra/core/vars/dev.tfvars` with:
- `key_vault_id` - Bootstrap Key Vault resource ID
- `key_vault_name` - Bootstrap Key Vault name
- `key_vault_uri` - Bootstrap Key Vault URI
- `app_gateway_ssl_certificate_id` - SSL certificate secret ID

These values are used by the core infrastructure to access certificates.

## Updating Bootstrap

If you need to make changes to the bootstrap:

```bash
cd infra/bootstrap
terraform apply \
  -var="subscription_id=YOUR_SUBSCRIPTION_ID" \
  -var="github_repository=owner/repo-name"
```

Changes to Key Vault or certificates will automatically update the tfvars file.

## Troubleshooting

### Certificate Issues
If Application Gateway can't access the certificate:
1. Verify the certificate exists in Bootstrap Key Vault
2. Check access policy for Application Gateway managed identity
3. Ensure certificate name is exactly `app-gateway-ssl-cert`

### State File Issues
If you need to move or recreate state storage:
1. Export existing state: `terraform state pull > backup.tfstate`
2. Update backend configuration
3. Re-initialize: `terraform init -reconfigure`
4. Import state if needed

# Bootstrap Shared Terraform Backend

This bootstrap configuration creates a single shared Azure Storage Account backend for multiple Terraform stacks, with each stack using a unique state file key.

## Structure

```
bootstrap/
├── main.tf                    # Main configuration
├── modules/
│   └── backend/              # Backend module (not used in shared approach)
```

## Usage

### 1. First Time Setup

Initialize and apply to create the shared backend:

```bash
cd bootstrap
terraform init
terraform apply -var="subscription_id=YOUR_SUBSCRIPTION_ID"
```

This will create:
- One resource group: `rg-terraform-state`
- One storage account (with random suffix)
- One storage container: `tfstate`
- Multiple backend config files: `backend-base.hcl`, `backend-mlworkspace.hcl`, etc.

### 2. Add More Stacks

To add additional stacks, edit `main.tf` and add new entries to the `state_keys` local:

```hcl
locals {
  location            = "uaenorth"
  resource_group_name = "rg-terraform-state"

  # Define state keys for different stacks
  state_keys = {
    base        = "base.tfstate"
    mlworkspace = "mlworkspace.tfstate"
    # Add more stacks here
    production  = "production.tfstate"
    staging     = "staging.tfstate"
  }
}
```

Then run:

```bash
terraform apply -var="subscription_id=YOUR_SUBSCRIPTION_ID"
```

### 3. Use the Backend Config in Your Infrastructure Stacks

In your infrastructure directories (e.g., `base/`, `mlworkspace/`), initialize Terraform with the appropriate backend config:

**For base stack:**
```bash
cd ../base
terraform init -backend-config=../backend-base.hcl
terraform apply
```

**For mlworkspace stack:**
```bash
cd ../mlworkspace
terraform init -backend-config=../backend-mlworkspace.hcl
terraform apply
```

## Backend Configuration

Each generated backend config file (e.g., `backend-base.hcl`) contains:

```hcl
resource_group_name  = "rg-terraform-state"
storage_account_name = "sttfstate<random>"
container_name       = "tfstate"
key                  = "base.tfstate"        # Unique for each stack
use_azuread_auth     = true
```

## Features

- **Shared Infrastructure**: All stacks share the same storage account, resource group, and container
- **Isolated State Files**: Each stack has its own state file (different `key` value)
- **Azure AD Authentication**: Uses Azure AD instead of storage account keys
- **Easy to Add Stacks**: Just add a new entry to `state_keys` local
- **Cost Efficient**: Only one storage account for all your stacks

## Outputs

After applying, you'll see output showing all backend configurations:

```
backend_configs = {
  "base" = {
    "config_path" = "../backend-base.hcl"
    "state_key" = "base.tfstate"
  }
  "mlworkspace" = {
    "config_path" = "../backend-mlworkspace.hcl"
    "state_key" = "mlworkspace.tfstate"
  }
}
container_name = "tfstate"
resource_group_name = "rg-terraform-state"
storage_account_name = "sttfstateh496o9r3"
```

## Cleanup

To destroy the shared backend:

```bash
cd bootstrap
terraform destroy -var="subscription_id=YOUR_SUBSCRIPTION_ID"
```

**Warning**: This will delete all remote state storage for all stacks. Make sure to backup or destroy all dependent infrastructure stacks first.

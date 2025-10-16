variable "subscription_id" {
  description = "The subscription ID to deploy resources into."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in the format 'owner/repo' for federated identity credentials."
  type        = string
  default     = "bensincs/azure-project-bootstrap"
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id     = var.subscription_id
  storage_use_azuread = true
}

provider "github" {
  owner = split("/", var.github_repository)[0]
  # Uses GITHUB_TOKEN environment variable automatically from gh CLI
}

locals {
  location            = "uaenorth"
  resource_group_name = "rg-terraform-state"

  # Parse repository owner and name
  github_owner = split("/", var.github_repository)[0]
  github_repo  = split("/", var.github_repository)[1]

  # Define stacks and their environments
  # Structure: stack/environment => configuration details
  backends = {
    # Base infrastructure stack
    "core/dev" = {
      state_key       = "core/dev.tfstate"
      backend_path    = "${path.module}/../core/backends/backend-dev.hcl"
      tfvars_path     = "${path.module}/../core/vars/dev.tfvars"
      environment     = "dev"
      location        = "uaenorth"
      subscription_id = var.subscription_id
    }
  }

  mcaps_tags = {
    SecurityControl = "Ignore"
    CostControl     = "Ignore"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_resource_group" "state" {
  name     = local.resource_group_name
  location = local.location
}

resource "azurerm_storage_account" "state" {
  name                            = "sttfstate${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.state.name
  location                        = azurerm_resource_group.state.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false

  tags = local.mcaps_tags
}

resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"
}

# Key Vault for SSL certificates and secrets
resource "azurerm_key_vault" "bootstrap" {
  name                       = "kv-bootstrap-${random_string.suffix.result}"
  resource_group_name        = azurerm_resource_group.state.name
  location                   = azurerm_resource_group.state.location
  tenant_id                  = data.azuread_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  # Enable for Application Gateway
  enabled_for_deployment          = true
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true

  public_network_access_enabled = true

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
  }

  tags = local.mcaps_tags
}

# Access policy for current user/service principal
resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.bootstrap.id
  tenant_id    = data.azuread_client_config.current.tenant_id
  object_id    = data.azuread_client_config.current.object_id

  certificate_permissions = [
    "Get",
    "List",
    "Create",
    "Import",
    "Update",
    "Delete",
    "Purge",
    "Recover",
  ]

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Purge",
    "Recover",
  ]

  key_permissions = [
    "Get",
    "List",
    "Create",
    "Delete",
    "Purge",
    "Recover",
  ]
}

# Access policy for GitHub Actions service principal
resource "azurerm_key_vault_access_policy" "github_actions" {
  key_vault_id = azurerm_key_vault.bootstrap.id
  tenant_id    = data.azuread_client_config.current.tenant_id
  object_id    = azuread_service_principal.github_actions.object_id

  certificate_permissions = [
    "Get",
    "List",
    "Import",
  ]

  secret_permissions = [
    "Get",
    "List",
    "Set",
  ]
}

# SSL certificate for Application Gateway
# Note: Upload your certificate manually after bootstrap is deployed
# Command: az keyvault certificate import --vault-name <vault-name> --name app-gateway-ssl-cert --file certificate.pfx --password <password>
resource "azurerm_key_vault_certificate" "app_gateway" {
  name         = "app-gateway-ssl-cert"
  key_vault_id = azurerm_key_vault.bootstrap.id

  # This will be replaced when you upload your actual certificate
  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"] # Server Authentication

      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]

      subject            = "CN=*.azurecontainerapps.io"
      validity_in_months = 12

      subject_alternative_names {
        dns_names = [
          "*.azurecontainerapps.io",
        ]
      }
    }
  }

  depends_on = [
    azurerm_key_vault_access_policy.current_user,
  ]
}

# Data source to get current tenant ID
data "azuread_client_config" "current" {}

# Azure AD Application for GitHub Actions
resource "azuread_application" "github_actions" {
  display_name = "github-actions-deploy"
}

# Service Principal for the application
resource "azuread_service_principal" "github_actions" {
  client_id = azuread_application.github_actions.client_id
}

# Grant the service principal access to manage Terraform state
resource "azurerm_role_assignment" "github_actions_storage" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# Grant the service principal Owner role on the subscription for deployments
resource "azurerm_role_assignment" "github_actions_owner" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Owner"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# Data source to get the Application Administrator directory role
data "azuread_directory_roles" "roles" {}

locals {
  app_admin_role = [
    for role in data.azuread_directory_roles.roles.roles :
    role if role.display_name == "Application Administrator"
  ][0]
}

# Grant the service principal Application Administrator role to create app registrations
resource "azuread_directory_role_assignment" "github_actions_app_admin" {
  role_id             = local.app_admin_role.object_id
  principal_object_id = azuread_service_principal.github_actions.object_id
}

# Federated identity credential for GitHub Actions on main branch
resource "azuread_application_federated_identity_credential" "github_actions_main" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-actions-main"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repository}:ref:refs/heads/main"
}

# Federated identity credential for GitHub Actions on pull requests
resource "azuread_application_federated_identity_credential" "github_actions_pr" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-actions-pr"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repository}:pull_request"
}

# Create GitHub repository secrets for OIDC authentication
resource "github_actions_secret" "azure_client_id" {
  repository      = local.github_repo
  secret_name     = "AZURE_CLIENT_ID"
  plaintext_value = azuread_application.github_actions.client_id
}

resource "github_actions_secret" "azure_tenant_id" {
  repository      = local.github_repo
  secret_name     = "AZURE_TENANT_ID"
  plaintext_value = data.azuread_client_config.current.tenant_id
}

resource "github_actions_secret" "azure_subscription_id" {
  repository      = local.github_repo
  secret_name     = "AZURE_SUBSCRIPTION_ID"
  plaintext_value = var.subscription_id
}

# Create a backend config file for each stack/environment with unique state key
resource "local_file" "backend_config" {
  for_each = local.backends

  content = <<-EOT
    resource_group_name  = "${azurerm_resource_group.state.name}"
    storage_account_name = "${azurerm_storage_account.state.name}"
    container_name       = "${azurerm_storage_container.state.name}"
    key                  = "${each.value.state_key}"
    use_azuread_auth     = true
  EOT

  filename = each.value.backend_path
}

# Create a tfvars file for each stack/environment
resource "local_file" "tfvars" {
  for_each = local.backends

  content = <<-EOT
    # Auto-generated tfvars for ${each.key}
    # Edit this file to customize your environment-specific variables

    environment     = "${each.value.environment}"
    location        = "${each.value.location}"
    subscription_id = "${each.value.subscription_id}"

    # Bootstrap Key Vault (for SSL certificates)
    key_vault_id                    = "${azurerm_key_vault.bootstrap.id}"
    key_vault_name                  = "${azurerm_key_vault.bootstrap.name}"
    key_vault_uri                   = "${azurerm_key_vault.bootstrap.vault_uri}"
    app_gateway_ssl_certificate_id  = "${azurerm_key_vault_certificate.app_gateway.secret_id}"

    # Add your custom variables below this line
    # Example:
    # resource_name_prefix = "${each.value.environment}"
    # tags = {
    #   Environment = "${each.value.environment}"
    #   ManagedBy   = "Terraform"
    # }
  EOT

  filename = each.value.tfvars_path

  lifecycle {
    ignore_changes = [content]
  }
}

# Outputs
output "resource_group_name" {
  description = "Shared resource group name"
  value       = azurerm_resource_group.state.name
}

output "storage_account_name" {
  description = "Shared storage account name"
  value       = azurerm_storage_account.state.name
}

output "container_name" {
  description = "Shared container name"
  value       = azurerm_storage_container.state.name
}

output "backend_configs" {
  description = "Generated backend config files for each stack and environment"
  value = {
    for key, file in local_file.backend_config : key => {
      backend_path = file.filename
      tfvars_path  = local_file.tfvars[key].filename
      state_key    = local.backends[key].state_key
      environment  = local.backends[key].environment
    }
  }
}

output "github_actions_identity" {
  description = "GitHub Actions service principal details for configuring OIDC authentication"
  value = {
    client_id       = azuread_application.github_actions.client_id
    tenant_id       = data.azuread_client_config.current.tenant_id
    subscription_id = var.subscription_id
    object_id       = azuread_service_principal.github_actions.object_id
  }
  sensitive = false
}

output "key_vault_name" {
  description = "Bootstrap Key Vault name for SSL certificates"
  value       = azurerm_key_vault.bootstrap.name
}

output "key_vault_id" {
  description = "Bootstrap Key Vault resource ID"
  value       = azurerm_key_vault.bootstrap.id
}

output "key_vault_uri" {
  description = "Bootstrap Key Vault URI"
  value       = azurerm_key_vault.bootstrap.vault_uri
}

output "app_gateway_ssl_certificate_id" {
  description = "Application Gateway SSL certificate secret ID"
  value       = azurerm_key_vault_certificate.app_gateway.secret_id
}

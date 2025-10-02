variable "subscription_id" {
  description = "The subscription ID to deploy resources into."
  type        = string
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id     = var.subscription_id
  storage_use_azuread = true
}

locals {
  location            = "uaenorth"
  resource_group_name = "rg-terraform-state"

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
}

resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
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

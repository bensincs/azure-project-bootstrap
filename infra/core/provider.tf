terraform {
  required_version = "~> 1.13.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
  }

  backend "azurerm" {
    # Backend configuration loaded from backend-{env}.hcl
    # Run: terraform init -backend-config=backends/backend-dev.hcl
  }
}

provider "azurerm" {
  features {}
  subscription_id     = var.subscription_id
  storage_use_azuread = true
}

provider "azuread" {
  # Uses the same authentication as azurerm provider
}

# Get current client for role assignments
data "azurerm_client_config" "current" {}

locals {
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Stack       = "core"
    }
  )
  mcaps_tags = {
    SecurityControl = "Ignore"
    CostControl     = "Ignore"
  }
}

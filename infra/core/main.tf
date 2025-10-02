terraform {
  required_version = "~> 1.13.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
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
}

# Random suffix for globally unique names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Resource Group
resource "azurerm_resource_group" "core" {
  name     = "rg-${var.resource_name_prefix}-${var.environment}"
  location = var.location
  tags     = local.common_tags
}

# Storage Account for Static Website
resource "azurerm_storage_account" "static_web" {
  name                     = "st${var.resource_name_prefix}web${var.environment}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.core.name
  location                 = azurerm_resource_group.core.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # Security settings
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = true # Required for static website
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"

  tags = local.common_tags
}

# Grant current user Storage Blob Data Contributor role on the storage account
resource "azurerm_role_assignment" "current_user_blob_contributor" {
  scope                = azurerm_storage_account.static_web.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Wait for RBAC permissions to propagate
resource "time_sleep" "wait_for_rbac" {
  depends_on = [azurerm_role_assignment.current_user_blob_contributor]

  create_duration = "60s"
}

# Enable static website on the storage account
resource "azurerm_storage_account_static_website" "core" {
  storage_account_id = azurerm_storage_account.static_web.id
  index_document     = "index.html"
  error_404_document = "404.html"

  depends_on = [time_sleep.wait_for_rbac]
}

# Container Registry (for storing Docker images)
resource "azurerm_container_registry" "core" {
  name                = "acr${var.resource_name_prefix}${var.environment}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = local.common_tags
}

# Log Analytics Workspace for Container Apps
resource "azurerm_log_analytics_workspace" "core" {
  name                = "law-${var.resource_name_prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.common_tags
}

# Container Apps Environment
resource "azurerm_container_app_environment" "core" {
  name                       = "cae-${var.resource_name_prefix}-${var.environment}"
  resource_group_name        = azurerm_resource_group.core.name
  location                   = azurerm_resource_group.core.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.core.id

  tags = local.common_tags
}

# Container App for Notification Service
resource "azurerm_container_app" "notification_service" {
  name                         = "ca-${var.resource_name_prefix}-notification-service-${var.environment}"
  resource_group_name          = azurerm_resource_group.core.name
  container_app_environment_id = azurerm_container_app_environment.core.id
  revision_mode                = "Single"

  registry {
    server               = azurerm_container_registry.core.login_server
    username             = azurerm_container_registry.core.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.core.admin_password
  }

  template {
    container {
      name   = "notification-service"
      # Start with a placeholder image - will be updated by deploy script
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "PORT"
        value = "3001"
      }
    }

    min_replicas = 1
    max_replicas = 1
  }

  ingress {
    external_enabled = true
    target_port      = 3001
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = local.common_tags

  # Ignore image changes so we can update via Azure CLI
  lifecycle {
    ignore_changes = [
      template[0].container[0].image,
      template[0].container[0].env,
    ]
  }
}

# Grant current user AcrPush role on the container registry
resource "azurerm_role_assignment" "current_user_acr_push" {
  scope                = azurerm_container_registry.core.id
  role_definition_name = "AcrPush"
  principal_id         = data.azurerm_client_config.current.object_id
}

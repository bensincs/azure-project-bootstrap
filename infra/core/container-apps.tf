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
      name = "notification-service"
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

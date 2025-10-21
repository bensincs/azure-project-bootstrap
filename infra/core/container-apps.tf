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
  name                               = "cae-${var.resource_name_prefix}-${var.environment}"
  resource_group_name                = azurerm_resource_group.core.name
  location                           = azurerm_resource_group.core.location
  log_analytics_workspace_id         = azurerm_log_analytics_workspace.core.id
  infrastructure_subnet_id           = azurerm_subnet.container_apps.id
  infrastructure_resource_group_name = "ME_cae-core-${var.environment}_rg-core-${var.environment}_${azurerm_resource_group.core.location}"
  internal_load_balancer_enabled     = true

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = local.common_tags
}

# Container App for API Service
resource "azurerm_container_app" "api_service" {
  name                         = "ca-${var.resource_name_prefix}-api-service-${var.environment}"
  resource_group_name          = azurerm_resource_group.core.name
  container_app_environment_id = azurerm_container_app_environment.core.id
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

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
      name = "api-service"
      # Start with a placeholder image - will be updated by deploy script
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.5
      memory = "1Gi"
    }

    min_replicas = 1
    max_replicas = 3
  }

  ingress {
    external_enabled = true
    target_port      = 8080
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

# Container App for UI Service
resource "azurerm_container_app" "ui_service" {
  name                         = "ca-${var.resource_name_prefix}-ui-service-${var.environment}"
  resource_group_name          = azurerm_resource_group.core.name
  container_app_environment_id = azurerm_container_app_environment.core.id
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

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
      name = "ui-service"
      # Start with a placeholder image - will be updated by deploy script
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }

    min_replicas = 1
    max_replicas = 3
  }

  ingress {
    external_enabled = true
    target_port      = 80
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

# Create a user-assigned managed identity for AI Chat Service
resource "azurerm_user_assigned_identity" "ai_chat" {
  name                = "id-${var.resource_name_prefix}-ai-chat-${var.environment}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location

  tags = local.common_tags
}


# Container App for AI Chat Service
resource "azurerm_container_app" "ai_chat_service" {
  name                         = "ca-${var.resource_name_prefix}-ai-chat-service-${var.environment}"
  resource_group_name          = azurerm_resource_group.core.name
  container_app_environment_id = azurerm_container_app_environment.core.id
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.ai_chat.id]
  }

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
      name = "ai-chat-service"
      # Start with a placeholder image - will be updated by deploy script
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.5
      memory = "1Gi"

      # Environment variables - will be overridden by deploy script with .env values
      env {
        name  = "AZURE_OPENAI_ENDPOINT"
        value = ""
      }
      env {
        name  = "AZURE_OPENAI_DEPLOYMENT_NAME"
        value = ""
      }
      env {
        name  = "AZURE_AD_TENANT_ID"
        value = data.azurerm_client_config.current.tenant_id
      }
      env {
        name  = "AZURE_AD_CLIENT_ID"
        value = azuread_application.main.client_id
      }
      # Managed Identity Client ID for DefaultAzureCredential
      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.ai_chat.client_id
      }
    }

    min_replicas = 1
    max_replicas = 5
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = local.common_tags

  # Ignore image and env changes so we can update via Azure CLI
  lifecycle {
    ignore_changes = [
      template[0].container[0].image,
      template[0].container[0].env,
    ]
  }
}

# Container App for WebRTC Signaling Service
resource "azurerm_container_app" "webrtc_signaling_service" {
  name                         = "ca-${var.resource_name_prefix}-webrtc-signaling-${var.environment}"
  resource_group_name          = azurerm_resource_group.core.name
  container_app_environment_id = azurerm_container_app_environment.core.id
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

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
      name = "webrtc-signaling-service"
      # Start with a placeholder image - will be updated by deploy script
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.5
      memory = "1Gi"

      # Environment variables - will be overridden by deploy script with .env values
      env {
        name  = "PORT"
        value = "3000"
      }
      env {
        name  = "NODE_ENV"
        value = "production"
      }
      env {
        name  = "AZURE_TENANT_ID"
        value = data.azurerm_client_config.current.tenant_id
      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = azuread_application.main.client_id
      }
      env {
        name  = "ALLOWED_ORIGINS"
        value = ""
      }
    }

    min_replicas = 1
    max_replicas = 5
  }

  ingress {
    external_enabled = true
    target_port      = 3000
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = local.common_tags

  # Ignore image and env changes so we can update via Azure CLI
  lifecycle {
    ignore_changes = [
      template[0].container[0].image,
      template[0].container[0].env,
    ]
  }
}

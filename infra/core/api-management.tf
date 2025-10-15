# Azure API Management for centralized JWT validation and API gateway

# API Management Service
resource "azurerm_api_management" "core" {
  name                = "apim-${var.resource_name_prefix}-${var.environment}-${random_string.suffix.result}"
  location            = azurerm_resource_group.core.location
  resource_group_name = azurerm_resource_group.core.name
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email

  # Use Developer tier for dev/test, change to Standard or Premium for production
  sku_name = var.apim_sku_name

  identity {
    type = "SystemAssigned"
  }

  # Virtual network integration - Internal mode (private IP only, accessible from VNet)
  virtual_network_type = "Internal"

  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim.id
  }

  tags = local.common_tags
}

# ==========================================
# API Management APIs - Import from OpenAPI
# ==========================================

# API Service - imports OpenAPI spec from .NET API
# Note: OpenAPI import happens after initial creation
# To update from OpenAPI spec, run: az apim api import --path api --specification-url <url>
resource "azurerm_api_management_api" "api_service" {
  name                = "api-service"
  resource_group_name = azurerm_resource_group.core.name
  api_management_name = azurerm_api_management.core.name
  revision            = "1"
  display_name        = "API Service"
  path                = "api"
  protocols           = ["https"]

  subscription_required = false
  
  # Placeholder - will be overridden by policy
  service_url = "https://example.com"

  # Start with empty API, import OpenAPI spec manually after deployment
  # import {
  #   content_format = "openapi+json-link"
  #   content_value  = "https://${azurerm_container_app.api_service.ingress[0].fqdn}/swagger/v1/swagger.json"
  # }

  lifecycle {
    ignore_changes = [
      import # Allow manual OpenAPI updates without Terraform overwriting
    ]
  }

  depends_on = [
    azurerm_container_app.api_service,
  ]
}

# Notification Service - imports OpenAPI spec from Node.js service
# Note: OpenAPI import happens after initial creation
# WebSocket protocol will be configured via policy, not at API level
resource "azurerm_api_management_api" "notification_service" {
  name                = "notification-service"
  resource_group_name = azurerm_resource_group.core.name
  api_management_name = azurerm_api_management.core.name
  revision            = "1"
  display_name        = "Notification Service"
  path                = "notify"
  protocols           = ["https"]

  subscription_required = false
  
  # Placeholder - will be overridden by policy
  service_url = "https://example.com"

  # Start with empty API, import OpenAPI spec manually after deployment
  # import {
  #   content_format = "openapi+json-link"
  #   content_value  = "https://${azurerm_container_app.notification_service.ingress[0].fqdn}/swagger.json"
  # }

  lifecycle {
    ignore_changes = [
      import # Allow manual OpenAPI updates without Terraform overwriting
    ]
  }

  depends_on = [
    azurerm_container_app.notification_service,
  ]
}

# UI Service - static SPA, no OpenAPI
# Empty path serves from root, operations defined separately
resource "azurerm_api_management_api" "ui_service" {
  name                = "ui-service"
  resource_group_name = azurerm_resource_group.core.name
  api_management_name = azurerm_api_management.core.name
  revision            = "1"
  display_name        = "UI Service"
  path                = ""
  protocols           = ["https"]
  
  subscription_required = false
  
  # Dummy service URL (will be overridden by policy)
  service_url = "https://example.com"

  depends_on = [
    azurerm_container_app.ui_service,
  ]
}

# Wildcard operation for UI SPA routing (no OpenAPI for static SPA)
resource "azurerm_api_management_api_operation" "ui_wildcard" {
  operation_id        = "ui-spa-route"
  api_name            = azurerm_api_management_api.ui_service.name
  api_management_name = azurerm_api_management.core.name
  resource_group_name = azurerm_resource_group.core.name
  display_name        = "SPA Routing"
  method              = "GET"
  url_template        = "/*"
  description         = "Handles all SPA routes for the UI"

  response {
    status_code = 200
  }
}

# ==========================================
# API Policies
# ==========================================
# Note: Policies are managed by each service's deploy.sh script
# This keeps policies synchronized with service deployments and avoids Terraform drift
# See services/*/deploy.sh for policy application logic

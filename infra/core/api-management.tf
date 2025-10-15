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

# API Management API for your backend services
resource "azurerm_api_management_api" "main" {
  name                = "main-api"
  resource_group_name = azurerm_resource_group.core.name
  api_management_name = azurerm_api_management.core.name
  revision            = "1"
  display_name        = "Main API"
  path                = ""
  protocols           = ["https"]

  subscription_required = false
  service_url           = "https://httpbin.org"

  depends_on = [
    azurerm_container_app.api_service,
    azurerm_container_app.ui_service,
    azurerm_container_app.notification_service,
  ]
}

# Add wildcard operations to catch all requests
resource "azurerm_api_management_api_operation" "wildcard_get" {
  operation_id        = "wildcard-get"
  api_name            = azurerm_api_management_api.main.name
  api_management_name = azurerm_api_management.core.name
  resource_group_name = azurerm_resource_group.core.name
  display_name        = "GET Wildcard"
  method              = "GET"
  url_template        = "/*"

  response {
    status_code = 200
  }
}

resource "azurerm_api_management_api_operation" "wildcard_post" {
  operation_id        = "wildcard-post"
  api_name            = azurerm_api_management_api.main.name
  api_management_name = azurerm_api_management.core.name
  resource_group_name = azurerm_resource_group.core.name
  display_name        = "POST Wildcard"
  method              = "POST"
  url_template        = "/*"

  response {
    status_code = 200
  }
}

resource "azurerm_api_management_api_operation" "wildcard_put" {
  operation_id        = "wildcard-put"
  api_name            = azurerm_api_management_api.main.name
  api_management_name = azurerm_api_management.core.name
  resource_group_name = azurerm_resource_group.core.name
  display_name        = "PUT Wildcard"
  method              = "PUT"
  url_template        = "/*"

  response {
    status_code = 200
  }
}

resource "azurerm_api_management_api_operation" "wildcard_delete" {
  operation_id        = "wildcard-delete"
  api_name            = azurerm_api_management_api.main.name
  api_management_name = azurerm_api_management.core.name
  resource_group_name = azurerm_resource_group.core.name
  display_name        = "DELETE Wildcard"
  method              = "DELETE"
  url_template        = "/*"

  response {
    status_code = 200
  }
}

resource "azurerm_api_management_api_operation" "wildcard_options" {
  operation_id        = "wildcard-options"
  api_name            = azurerm_api_management_api.main.name
  api_management_name = azurerm_api_management.core.name
  resource_group_name = azurerm_resource_group.core.name
  display_name        = "OPTIONS Wildcard"
  method              = "OPTIONS"
  url_template        = "/*"

  response {
    status_code = 200
  }
}

# API Management Policy - Routing to Container Apps
resource "azurerm_api_management_api_policy" "main" {
  api_name            = azurerm_api_management_api.main.name
  api_management_name = azurerm_api_management.core.name
  resource_group_name = azurerm_resource_group.core.name

  xml_content = templatefile("${path.module}/apim-policy-full.xml", {
    API_SERVICE_FQDN          = azurerm_container_app.api_service.ingress[0].fqdn
    NOTIFICATION_SERVICE_FQDN = azurerm_container_app.notification_service.ingress[0].fqdn
    UI_SERVICE_FQDN           = azurerm_container_app.ui_service.ingress[0].fqdn
    TENANT_ID                 = data.azuread_client_config.current.tenant_id
    CLIENT_ID                 = azuread_application.main.client_id
  })

  depends_on = [
    azurerm_api_management_api.main,
    azurerm_container_app.api_service,
    azurerm_container_app.ui_service,
    azurerm_container_app.notification_service,
  ]
}


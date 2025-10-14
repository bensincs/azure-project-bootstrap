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

  # APIM will route directly to Container Apps private endpoints
  service_url = "https://${azurerm_container_app.api_service.ingress[0].fqdn}"
}

# API Management Policy - Routing to Container Apps
resource "azurerm_api_management_api_policy" "main" {
  api_name            = azurerm_api_management_api.main.name
  api_management_name = azurerm_api_management.core.name
  resource_group_name = azurerm_resource_group.core.name

  xml_content = templatefile("${path.module}/apim-policy.xml", {
    API_SERVICE_FQDN          = azurerm_container_app.api_service.ingress[0].fqdn
    NOTIFICATION_SERVICE_FQDN = azurerm_container_app.notification_service.ingress[0].fqdn
    UI_SERVICE_FQDN           = azurerm_container_app.ui_service.ingress[0].fqdn
  })

  depends_on = [
    azurerm_api_management_api.main,
    azurerm_container_app.api_service,
    azurerm_container_app.ui_service,
    azurerm_container_app.notification_service,
  ]
}


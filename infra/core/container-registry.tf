# Container Registry (for storing Docker images)
resource "azurerm_container_registry" "core" {
  name                = "acr${var.resource_name_prefix}${var.environment}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = local.common_tags
}

# Grant current user AcrPush role on the container registry
resource "azurerm_role_assignment" "current_user_acr_push" {
  scope                = azurerm_container_registry.core.id
  role_definition_name = "AcrPush"
  principal_id         = data.azurerm_client_config.current.object_id
}

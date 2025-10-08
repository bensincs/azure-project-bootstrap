# Private Endpoints for Azure Resources

# Storage Account (Blob) Private Endpoint
resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-blob-${var.resource_name_prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-blob-${var.resource_name_prefix}-${var.environment}"
    private_connection_resource_id = azurerm_storage_account.core.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "pdzg-blob-${var.resource_name_prefix}-${var.environment}"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage_blob.id]
  }

  tags = local.common_tags

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.storage_blob
  ]
}

# Container Registry Private Endpoint
resource "azurerm_private_endpoint" "acr" {
  name                = "pe-acr-${var.resource_name_prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-acr-${var.resource_name_prefix}-${var.environment}"
    private_connection_resource_id = azurerm_container_registry.core.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "pdzg-acr-${var.resource_name_prefix}-${var.environment}"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr.id]
  }

  tags = local.common_tags

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.acr
  ]
}

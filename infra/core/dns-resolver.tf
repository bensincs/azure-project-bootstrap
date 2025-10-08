# Private DNS Resolver
resource "azurerm_private_dns_resolver" "core" {
  name                = "pdnsr-${var.resource_name_prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location
  virtual_network_id  = azurerm_virtual_network.core.id

  tags = local.common_tags
}

# Inbound Endpoint - Allows VPN clients to query Private DNS zones
resource "azurerm_private_dns_resolver_inbound_endpoint" "core" {
  name                    = "pdnsr-in-${var.resource_name_prefix}-${var.environment}"
  private_dns_resolver_id = azurerm_private_dns_resolver.core.id
  location                = azurerm_resource_group.core.location

  ip_configurations {
    subnet_id = azurerm_subnet.dns_resolver_inbound.id
  }

  tags = local.common_tags
}

# Private DNS Zones for Azure Services

# Container Apps Private DNS Zone (actual domain for internal load balancer)
resource "azurerm_private_dns_zone" "container_apps" {
  name                = azurerm_container_app_environment.core.default_domain
  resource_group_name = azurerm_resource_group.core.name

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "container_apps" {
  name                  = "pdnszvnl-containerapp-${var.environment}"
  resource_group_name   = azurerm_resource_group.core.name
  private_dns_zone_name = azurerm_private_dns_zone.container_apps.name
  virtual_network_id    = azurerm_virtual_network.core.id
  registration_enabled  = false

  tags = local.common_tags
}

# A record for Container Apps Environment (wildcard for all apps in the environment)
resource "azurerm_private_dns_a_record" "container_apps_wildcard" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.container_apps.name
  resource_group_name = azurerm_resource_group.core.name
  ttl                 = 300
  records             = [azurerm_container_app_environment.core.static_ip_address]

  tags = local.common_tags
}

# Storage Account (Blob) Private DNS Zone
resource "azurerm_private_dns_zone" "storage_blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.core.name

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_blob" {
  name                  = "pdnszvnl-blob-${var.environment}"
  resource_group_name   = azurerm_resource_group.core.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_blob.name
  virtual_network_id    = azurerm_virtual_network.core.id
  registration_enabled  = false

  tags = local.common_tags
}

# Container Registry Private DNS Zone
resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.core.name

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  name                  = "pdnszvnl-acr-${var.environment}"
  resource_group_name   = azurerm_resource_group.core.name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = azurerm_virtual_network.core.id
  registration_enabled  = false

  tags = local.common_tags
}

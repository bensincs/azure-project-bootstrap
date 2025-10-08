# Public IP for VPN Gateway
resource "azurerm_public_ip" "vpn_gateway" {
  name                = "pip-vpn-gateway-${var.environment}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.common_tags
}

# VPN Gateway
resource "azurerm_virtual_network_gateway" "vpn" {
  name                = "vgw-${var.resource_name_prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "VpnGw1" # Change to VpnGw2 or VpnGw3 for higher throughput

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  vpn_client_configuration {
    address_space = ["172.16.0.0/24"] # VPN client address pool

    vpn_client_protocols = ["OpenVPN"] # Only OpenVPN supports Azure AD auth

    vpn_auth_types = ["AAD"]

    aad_tenant   = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/"
    aad_audience = "41b23e61-6c1e-4545-b367-cd054e0ed4b4" # Azure VPN Client App ID (fixed)
    aad_issuer   = "https://sts.windows.net/${data.azurerm_client_config.current.tenant_id}/"
  }

  tags = local.common_tags
}

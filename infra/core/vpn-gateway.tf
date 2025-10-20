# Public IP for VPN Gateway
resource "azurerm_public_ip" "vpn_gateway" {
  count               = var.enable_vpn_gateway ? 1 : 0
  name                = "pip-vpn-gateway-${var.environment}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.common_tags
}

# VPN Gateway
resource "azurerm_virtual_network_gateway" "vpn" {
  count               = var.enable_vpn_gateway ? 1 : 0
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
    public_ip_address_id          = azurerm_public_ip.vpn_gateway[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  vpn_client_configuration {
    address_space        = var.vpn_client_address_space
    vpn_client_protocols = ["OpenVPN"] # Only OpenVPN supports Azure AD auth

    # Configure auth types based on whether certificate auth is enabled
    vpn_auth_types = var.enable_vpn_certificate_auth ? ["Certificate", "AAD"] : ["AAD"]

    # AAD configuration
    aad_tenant   = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/"
    aad_audience = "41b23e61-6c1e-4545-b367-cd054e0ed4b4" # Azure VPN Client App ID (fixed)
    aad_issuer   = "https://sts.windows.net/${data.azurerm_client_config.current.tenant_id}/"

    # Certificate-based authentication configuration
    dynamic "root_certificate" {
      for_each = var.enable_vpn_certificate_auth ? [1] : []
      content {
        name             = "vpn-root-cert"
        public_cert_data = replace(replace(tls_self_signed_cert.vpn_root_cert[0].cert_pem, "-----BEGIN CERTIFICATE-----\n", ""), "\n-----END CERTIFICATE-----\n", "")
      }
    }
  }

  tags = local.common_tags

  # This allows for longer time for the gateway operations to complete
  timeouts {
    create = "120m"
    update = "120m"
    delete = "180m"
  }
}

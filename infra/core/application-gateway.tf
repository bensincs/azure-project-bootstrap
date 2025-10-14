# Application Gateway for routing to private Container Apps
# APIM connects to App Gateway via private IP, App Gateway routes to private Container Apps

# User-assigned identity for Application Gateway to access Key Vault
resource "azurerm_user_assigned_identity" "app_gateway" {
  name                = "id-appgw-${var.resource_name_prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location

  tags = local.common_tags
}

# Public IP for Application Gateway (required for v2 SKU)
resource "azurerm_public_ip" "app_gateway" {
  name                = "pip-appgw-${var.environment}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.common_tags
}

# Application Gateway
resource "azurerm_application_gateway" "core" {
  name                = "appgw-${var.resource_name_prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  # System-assigned managed identity to access Key Vault
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app_gateway.id]
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.app_gateway.id
  }

  # SSL certificate from Key Vault
  ssl_certificate {
    name                = "apim-ssl-cert"
    key_vault_secret_id = azurerm_key_vault_certificate.app_gateway.secret_id
  }

  # Frontend ports
  frontend_port {
    name = "https-port"
    port = 443
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  # Public frontend IP (required for v2 SKU)
  frontend_ip_configuration {
    name                 = "public-frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.app_gateway.id
  }

  # Private frontend IP (for APIM to connect)
  frontend_ip_configuration {
    name                          = "private-frontend-ip-config"
    subnet_id                     = azurerm_subnet.app_gateway.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.5.10" # Must be within app_gateway subnet range (10.0.5.0/24)
  }

  # Backend pools - pointing to APIM
  backend_address_pool {
    name         = "apim-backend-pool"
    ip_addresses = [azurerm_api_management.core.private_ip_addresses[0]]
  }

  # Backend HTTP settings for APIM
  backend_http_settings {
    name                  = "apim-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 60
    probe_name            = "apim-health-probe"
    host_name             = replace(azurerm_api_management.core.gateway_url, "https://", "")
  }

  # Health probe for APIM
  probe {
    name                = "apim-health-probe"
    protocol            = "Https"
    path                = "/status-0123456789abcdef"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    host                = replace(azurerm_api_management.core.gateway_url, "https://", "")
    match {
      status_code = ["200-399"]
    }
  }

  # HTTPS Listener on public frontend
  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "public-frontend-ip-config"
    frontend_port_name             = "https-port"
    protocol                       = "Https"
    ssl_certificate_name           = "apim-ssl-cert"
  }

  # HTTP to HTTPS redirect listener
  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "public-frontend-ip-config"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  # Redirect configuration (HTTP to HTTPS)
  redirect_configuration {
    name                 = "http-to-https"
    redirect_type        = "Permanent"
    target_listener_name = "https-listener"
    include_path         = true
    include_query_string = true
  }

  # HTTP to HTTPS redirect rule
  request_routing_rule {
    name                        = "http-redirect-rule"
    rule_type                   = "Basic"
    http_listener_name          = "http-listener"
    redirect_configuration_name = "http-to-https"
    priority                    = 50
  }

  # HTTPS routing rule - all traffic to APIM
  request_routing_rule {
    name                       = "apim-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "https-listener"
    backend_address_pool_name  = "apim-backend-pool"
    backend_http_settings_name = "apim-http-settings"
    priority                   = 100
  }

  tags = local.common_tags

  depends_on = [
    azurerm_api_management.core,
    azurerm_key_vault_certificate.app_gateway,
  ]
}

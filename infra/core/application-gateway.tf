# Application Gateway for routing directly to private Container Apps
# Routes public traffic to Container Apps without APIM

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

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app_gateway.id]
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.app_gateway.id
  }

  # SSL certificate from Bootstrap Key Vault
  ssl_certificate {
    name                = "app-gateway-ssl-cert"
    key_vault_secret_id = var.app_gateway_ssl_certificate_id
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

  # Public frontend IP
  frontend_ip_configuration {
    name                 = "public-frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.app_gateway.id
  }

  # Backend pools - pointing to Container Apps
  backend_address_pool {
    name  = "api-backend-pool"
    fqdns = [azurerm_container_app.api_service.ingress[0].fqdn]
  }

  backend_address_pool {
    name  = "ui-backend-pool"
    fqdns = [azurerm_container_app.ui_service.ingress[0].fqdn]
  }

  backend_address_pool {
    name  = "ai-chat-backend-pool"
    fqdns = [azurerm_container_app.ai_chat_service.ingress[0].fqdn]
  }

  # Backend HTTP settings for API Service
  backend_http_settings {
    name                  = "api-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 60
    probe_name            = "api-health-probe"
    host_name             = azurerm_container_app.api_service.ingress[0].fqdn
  }

  # Backend HTTP settings for UI Service
  backend_http_settings {
    name                  = "ui-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 60
    probe_name            = "ui-health-probe"
    host_name             = azurerm_container_app.ui_service.ingress[0].fqdn
  }

  # Backend HTTP settings for AI Chat Service
  backend_http_settings {
    name                  = "ai-chat-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 120 # Increased timeout for streaming
    probe_name            = "ai-chat-health-probe"
    host_name             = azurerm_container_app.ai_chat_service.ingress[0].fqdn
  }

  # Health probes
  probe {
    name                                      = "api-health-probe"
    protocol                                  = "Https"
    path                                      = "/api/health"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    match {
      status_code = ["200-399"]
    }
  }

  probe {
    name                                      = "ui-health-probe"
    protocol                                  = "Https"
    path                                      = "/health"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    match {
      status_code = ["200-399"]
    }
  }

  probe {
    name                                      = "ai-chat-health-probe"
    protocol                                  = "Https"
    path                                      = "/ai-chat/health"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    match {
      status_code = ["200-399"]
    }
  }

  # HTTPS Listener
  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "public-frontend-ip-config"
    frontend_port_name             = "https-port"
    protocol                       = "Https"
    ssl_certificate_name           = "app-gateway-ssl-cert"
  }

  # HTTP Listener
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

  # Path-based routing rule for HTTPS traffic
  request_routing_rule {
    name               = "https-routing-rule"
    rule_type          = "PathBasedRouting"
    http_listener_name = "https-listener"
    url_path_map_name  = "path-routing"
    priority           = 100
  }

  # URL path map for routing
  url_path_map {
    name                               = "path-routing"
    default_backend_address_pool_name  = "ui-backend-pool"
    default_backend_http_settings_name = "ui-http-settings"

    path_rule {
      name                       = "api-rule"
      paths                      = ["/api/*"]
      backend_address_pool_name  = "api-backend-pool"
      backend_http_settings_name = "api-http-settings"
    }

    path_rule {
      name                       = "ai-chat-rule"
      paths                      = ["/ai-chat/*"]
      backend_address_pool_name  = "ai-chat-backend-pool"
      backend_http_settings_name = "ai-chat-http-settings"
    }
  }

  tags = local.common_tags

  depends_on = [
    azurerm_container_app.api_service,
    azurerm_container_app.ui_service,
    azurerm_container_app.ai_chat_service,
    azurerm_key_vault_access_policy.app_gateway
  ]
}

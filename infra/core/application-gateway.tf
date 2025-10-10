# Application Gateway for internal routing to private Container Apps
# APIM handles SSL/TLS termination and JWT validation

# Network Security Group for Application Gateway
resource "azurerm_network_security_group" "app_gateway" {
  name                = "vnet-${var.resource_name_prefix}-snet-appgw-${var.environment}-nsg-${var.location}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location

  tags = local.common_tags
}

# NSG Rule: Allow inbound from VNet on port 80 (APIM traffic)
resource "azurerm_network_security_rule" "app_gateway_http" {
  name                        = "AllowVNetHTTPInbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.app_gateway.name
}

# Associate NSG with App Gateway subnet
resource "azurerm_subnet_network_security_group_association" "app_gateway" {
  subnet_id                 = azurerm_subnet.app_gateway.id
  network_security_group_id = azurerm_network_security_group.app_gateway.id
}

# Application Gateway (internal, HTTP-only)
resource "azurerm_application_gateway" "core" {
  name                = "appgw-${var.resource_name_prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.app_gateway.id
  }

  # Frontend configuration (private IP only)
  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_ip_configuration {
    name                          = "frontend-ip-config"
    subnet_id                     = azurerm_subnet.app_gateway.id
    private_ip_address_allocation = "Dynamic"
  }

  # Backend pools
  backend_address_pool {
    name  = "ui-backend-pool"
    fqdns = [azurerm_container_app.ui_service.ingress[0].fqdn]
  }

  backend_address_pool {
    name  = "api-backend-pool"
    fqdns = [azurerm_container_app.api_service.ingress[0].fqdn]
  }

  backend_address_pool {
    name  = "notification-backend-pool"
    fqdns = [azurerm_container_app.notification_service.ingress[0].fqdn]
  }

  # Backend HTTP settings
  backend_http_settings {
    name                                = "ui-http-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 60
    pick_host_name_from_backend_address = true
    probe_name                          = "ui-health-probe"
  }

  backend_http_settings {
    name                                = "api-http-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 60
    pick_host_name_from_backend_address = true
    probe_name                          = "api-health-probe"
  }

  backend_http_settings {
    name                                = "notification-http-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 60
    pick_host_name_from_backend_address = true
    probe_name                          = "notification-health-probe"
  }

  # Rewrite rule set for notification service path rewriting
  rewrite_rule_set {
    name = "notification-path-rewrite"

    rewrite_rule {
      name          = "rewrite-notify-to-api"
      rule_sequence = 100

      condition {
        variable    = "var_uri_path"
        pattern     = "^/notify/(.*)$"
        ignore_case = true
      }

      url {
        path         = "/api/{var_uri_path_1}"
        query_string = null
        reroute      = false
      }
    }
  }

  # Health probes
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
    name                                      = "notification-health-probe"
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

  # HTTP Listener (no SSL, internal only)
  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip-config"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  # HTTP routing rule with path-based routing
  request_routing_rule {
    name               = "http-routing-rule"
    rule_type          = "PathBasedRouting"
    http_listener_name = "http-listener"
    url_path_map_name  = "path-based-routing"
    priority           = 100
  }

  # URL path map for routing
  url_path_map {
    name                               = "path-based-routing"
    default_backend_address_pool_name  = "ui-backend-pool"
    default_backend_http_settings_name = "ui-http-settings"

    path_rule {
      name                       = "api-path-rule"
      paths                      = ["/api/*"]
      backend_address_pool_name  = "api-backend-pool"
      backend_http_settings_name = "api-http-settings"
    }

    path_rule {
      name                       = "notification-path-rule"
      paths                      = ["/notify/*"]
      backend_address_pool_name  = "notification-backend-pool"
      backend_http_settings_name = "notification-http-settings"
      rewrite_rule_set_name      = "notification-path-rewrite"
    }

    path_rule {
      name                       = "websocket-path-rule"
      paths                      = ["/ws"]
      backend_address_pool_name  = "notification-backend-pool"
      backend_http_settings_name = "notification-http-settings"
    }
  }

  tags = local.common_tags

  depends_on = [
    azurerm_container_app.ui_service,
    azurerm_container_app.api_service,
    azurerm_container_app.notification_service,
  ]
}

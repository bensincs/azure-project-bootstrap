# Azure Front Door Profile (Standard tier)
resource "azurerm_cdn_frontdoor_profile" "core" {
  name                = "afd-${var.resource_name_prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.core.name
  sku_name            = "Standard_AzureFrontDoor"

  tags = local.common_tags
}

# Front Door Endpoint
resource "azurerm_cdn_frontdoor_endpoint" "core" {
  name                     = "afd-${var.resource_name_prefix}-${var.environment}-${random_string.suffix.result}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.core.id

  tags = local.common_tags
}

# Origin Group for Static Website
resource "azurerm_cdn_frontdoor_origin_group" "static_web" {
  name                     = "static-web-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.core.id

  load_balancing {
    sample_size                        = 4
    successful_samples_required        = 3
    additional_latency_in_milliseconds = 50
  }

  health_probe {
    protocol            = "Https"
    interval_in_seconds = 100
    path                = "/"
    request_type        = "HEAD"
  }
}

# Origin for Static Website
resource "azurerm_cdn_frontdoor_origin" "static_web" {
  name                          = "static-web-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.static_web.id

  enabled                        = true
  host_name                      = azurerm_storage_account.static_web.primary_web_host
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = azurerm_storage_account.static_web.primary_web_host
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

# Origin Group for Notification Service API
resource "azurerm_cdn_frontdoor_origin_group" "notification_api" {
  name                     = "notification-api-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.core.id

  load_balancing {
    sample_size                        = 4
    successful_samples_required        = 3
    additional_latency_in_milliseconds = 50
  }

  health_probe {
    protocol            = "Https"
    interval_in_seconds = 100
    path                = "/health"
    request_type        = "GET"
  }
}

# Origin for Notification Service
resource "azurerm_cdn_frontdoor_origin" "notification_api" {
  name                          = "notification-api-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.notification_api.id

  enabled                        = true
  host_name                      = azurerm_container_app.notification_service.ingress[0].fqdn
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = azurerm_container_app.notification_service.ingress[0].fqdn
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

# Route for Static Website (default route)
resource "azurerm_cdn_frontdoor_route" "static_web" {
  name                          = "static-web-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.core.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.static_web.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.static_web.id]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "HttpsOnly"
  link_to_default_domain = true
  https_redirect_enabled = true

  cdn_frontdoor_custom_domain_ids = []
}

# Route for Notification Service API
resource "azurerm_cdn_frontdoor_route" "notification_api" {
  name                          = "notification-api-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.core.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.notification_api.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.notification_api.id]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/api/notifications/*", "/ws"]
  forwarding_protocol    = "HttpsOnly"
  link_to_default_domain = true
  https_redirect_enabled = true

  cdn_frontdoor_custom_domain_ids = []
}

# Origin Group for API Service
resource "azurerm_cdn_frontdoor_origin_group" "api_service" {
  name                     = "api-service-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.core.id

  load_balancing {
    sample_size                        = 4
    successful_samples_required        = 3
    additional_latency_in_milliseconds = 50
  }

  health_probe {
    protocol            = "Https"
    interval_in_seconds = 100
    path                = "/health"
    request_type        = "GET"
  }
}

# Origin for API Service
resource "azurerm_cdn_frontdoor_origin" "api_service" {
  name                          = "api-service-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.api_service.id

  enabled                        = true
  host_name                      = azurerm_container_app.api_service.ingress[0].fqdn
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = azurerm_container_app.api_service.ingress[0].fqdn
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

# Route for API Service
resource "azurerm_cdn_frontdoor_route" "api_service" {
  name                          = "api-service-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.core.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.api_service.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.api_service.id]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/api/*"]
  forwarding_protocol    = "HttpsOnly"
  link_to_default_domain = true
  https_redirect_enabled = true

  cdn_frontdoor_custom_domain_ids = []
}

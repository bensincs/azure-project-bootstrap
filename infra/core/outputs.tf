output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.core.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.core.id
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.core.name
}

output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.core.id
}

output "website_url" {
  description = "Full URL to access the website via Application Gateway"
  value       = "http://${azurerm_public_ip.app_gateway.ip_address}/"
}

output "container_registry_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.core.name
}

output "container_registry_login_server" {
  description = "Login server for the Azure Container Registry"
  value       = azurerm_container_registry.core.login_server
}

output "container_app_name" {
  description = "Name of the Container App"
  value       = azurerm_container_app.notification_service.name
}

output "notification_service_fqdn" {
  description = "FQDN of the Notification Service Container App"
  value       = azurerm_container_app.notification_service.latest_revision_fqdn
}

output "notification_api_url" {
  description = "URL for the notification API"
  value       = "https://${azurerm_container_app.notification_service.latest_revision_fqdn}"
}

output "notification_api_websocket_url" {
  description = "WebSocket URL for the notification API"
  value       = "wss://${azurerm_container_app.notification_service.latest_revision_fqdn}/ws"
}

# API Service Outputs
output "api_service_name" {
  description = "Name of the API Container App"
  value       = azurerm_container_app.api_service.name
}

output "api_service_url" {
  description = "Direct URL for the API service"
  value       = "https://${azurerm_container_app.api_service.latest_revision_fqdn}"
}

output "api_service_fqdn" {
  description = "FQDN of the API Container App"
  value       = azurerm_container_app.api_service.latest_revision_fqdn
}

# Application Gateway Outputs
output "app_gateway_public_ip" {
  description = "Public IP address of the Application Gateway"
  value       = azurerm_public_ip.app_gateway.ip_address
}

output "app_gateway_url" {
  description = "Full URL to access the application via Application Gateway"
  value       = "http://${azurerm_public_ip.app_gateway.ip_address}"
}

output "app_gateway_name" {
  description = "Name of the Application Gateway"
  value       = azurerm_application_gateway.core.name
}

# Azure Front Door Outputs (commented out - replaced with Application Gateway)
# output "frontdoor_endpoint_hostname" {
#   description = "Azure Front Door endpoint hostname"
#   value       = azurerm_cdn_frontdoor_endpoint.core.host_name
# }

# output "frontdoor_endpoint_url" {
#   description = "Full URL to access the application via Azure Front Door"
#   value       = "https://${azurerm_cdn_frontdoor_endpoint.core.host_name}"
# }

# output "frontdoor_profile_name" {
#   description = "Name of the Azure Front Door profile"
#   value       = azurerm_cdn_frontdoor_profile.core.name
# }

# output "frontdoor_endpoint_name" {
#   description = "Name of the Azure Front Door endpoint"
#   value       = azurerm_cdn_frontdoor_endpoint.core.name
# }

# VPN Gateway Outputs
output "vpn_gateway_name" {
  description = "Name of the VPN Gateway"
  value       = azurerm_virtual_network_gateway.vpn.name
}

output "vpn_gateway_public_ip" {
  description = "Public IP address of the VPN Gateway"
  value       = azurerm_public_ip.vpn_gateway.ip_address
}

# Virtual Network Outputs
output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = azurerm_virtual_network.core.name
}

output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = azurerm_virtual_network.core.id
}

output "container_apps_subnet_id" {
  description = "ID of the Container Apps subnet"
  value       = azurerm_subnet.container_apps.id
}

# Private DNS Resolver Outputs
output "dns_resolver_name" {
  description = "Name of the Private DNS Resolver"
  value       = azurerm_private_dns_resolver.core.name
}

output "dns_resolver_inbound_endpoint_ip" {
  description = "IP address of the DNS Resolver inbound endpoint"
  value       = azurerm_private_dns_resolver_inbound_endpoint.core.ip_configurations[0].private_ip_address
}

# Private Endpoint Outputs
output "storage_private_endpoint_name" {
  description = "Name of the Storage Account private endpoint"
  value       = azurerm_private_endpoint.storage_blob.name
}

output "acr_private_endpoint_name" {
  description = "Name of the Container Registry private endpoint"
  value       = azurerm_private_endpoint.acr.name
}

# Private DNS Zone Outputs
output "private_dns_zone_container_apps" {
  description = "Name of the Container Apps private DNS zone"
  value       = azurerm_private_dns_zone.container_apps.name
}

output "private_dns_zone_storage" {
  description = "Name of the Storage private DNS zone"
  value       = azurerm_private_dns_zone.storage_blob.name
}

output "private_dns_zone_acr" {
  description = "Name of the Container Registry private DNS zone"
  value       = azurerm_private_dns_zone.acr.name
}

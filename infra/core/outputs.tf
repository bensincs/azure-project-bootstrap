output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.core.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.core.id
}

output "storage_account_name" {
  description = "Name of the storage account hosting the static website"
  value       = azurerm_storage_account.static_web.name
}

output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.static_web.id
}

output "primary_web_endpoint" {
  description = "Primary endpoint URL for the static website"
  value       = azurerm_storage_account.static_web.primary_web_endpoint
}

output "primary_web_host" {
  description = "Primary web host for the static website"
  value       = azurerm_storage_account.static_web.primary_web_host
}

output "website_url" {
  description = "Full URL to access the static website"
  value       = "https://${azurerm_storage_account.static_web.primary_web_host}/"
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

output "notification_api_url" {
  description = "URL for the notification API"
  value       = "https://${azurerm_container_app.notification_service.latest_revision_fqdn}"
}

output "notification_api_websocket_url" {
  description = "WebSocket URL for the notification API"
  value       = "wss://${azurerm_container_app.notification_service.latest_revision_fqdn}/ws"
}

# Azure Front Door Outputs
output "frontdoor_endpoint_hostname" {
  description = "Azure Front Door endpoint hostname"
  value       = azurerm_cdn_frontdoor_endpoint.core.host_name
}

output "frontdoor_endpoint_url" {
  description = "Full URL to access the application via Azure Front Door"
  value       = "https://${azurerm_cdn_frontdoor_endpoint.core.host_name}"
}

output "frontdoor_profile_name" {
  description = "Name of the Azure Front Door profile"
  value       = azurerm_cdn_frontdoor_profile.core.name
}

output "frontdoor_endpoint_name" {
  description = "Name of the Azure Front Door endpoint"
  value       = azurerm_cdn_frontdoor_endpoint.core.name
}

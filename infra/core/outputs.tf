output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.core.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.core.id
}

output "environment" {
  description = "Environment name (dev, stag, prod)"
  value       = var.environment
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.core.name
}

output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.core.id
}

output "app_gateway_public_ip" {
  description = "Public IP address of the Application Gateway (main entry point)"
  value       = azurerm_public_ip.app_gateway.ip_address
}

output "application_url" {
  description = "URL to access the application via Application Gateway"
  value       = "https://${azurerm_public_ip.app_gateway.ip_address}"
}

output "container_registry_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.core.name
}

output "container_registry_login_server" {
  description = "Login server for the Azure Container Registry"
  value       = azurerm_container_registry.core.login_server
}

# Bootstrap Key Vault (passed through from variables)
output "key_vault_name" {
  description = "Name of the Bootstrap Key Vault"
  value       = var.key_vault_name
}

output "key_vault_uri" {
  description = "URI of the Bootstrap Key Vault"
  value       = var.key_vault_uri
}

# API Service Outputs
output "api_service_name" {
  description = "Name of the API Container App"
  value       = azurerm_container_app.api_service.name
}

output "api_service_url" {
  description = "Direct URL for the API service"
  value       = "https://${azurerm_container_app.api_service.ingress[0].fqdn}"
}

output "api_service_fqdn" {
  description = "FQDN of the API Container App"
  value       = azurerm_container_app.api_service.ingress[0].fqdn
}

output "ui_service_name" {
  description = "Name of the UI Service Container App"
  value       = azurerm_container_app.ui_service.name
}

output "ui_service_fqdn" {
  description = "FQDN of the UI Service Container App"
  value       = azurerm_container_app.ui_service.ingress[0].fqdn
}

# Application Gateway Outputs
output "app_gateway_name" {
  description = "Name of the Application Gateway"
  value       = azurerm_application_gateway.core.name
}

# VPN Gateway Outputs
output "vpn_gateway_name" {
  description = "Name of the VPN Gateway"
  value       = var.enable_vpn_gateway ? azurerm_virtual_network_gateway.vpn[0].name : null
}

output "vpn_gateway_public_ip" {
  description = "Public IP address of the VPN Gateway"
  value       = var.enable_vpn_gateway ? azurerm_public_ip.vpn_gateway[0].ip_address : null
}

output "vpn_gateway_id" {
  description = "ID of the VPN Gateway"
  value       = var.enable_vpn_gateway ? azurerm_virtual_network_gateway.vpn[0].id : null
}

output "vpn_client_address_space" {
  description = "VPN client address space"
  value       = var.enable_vpn_gateway ? var.vpn_client_address_space : null
}

output "vpn_certificate_auth_enabled" {
  description = "Whether certificate-based authentication is enabled"
  value       = var.enable_vpn_certificate_auth
}

output "vpn_aad_tenant" {
  description = "Azure AD tenant URL for VPN authentication"
  value       = var.enable_vpn_gateway ? "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/" : null
}

output "vpn_aad_audience" {
  description = "Azure AD audience (app ID) for VPN authentication"
  value       = var.enable_vpn_gateway ? "41b23e61-6c1e-4545-b367-cd054e0ed4b4" : null
}

output "vpn_client_cert_secret_name" {
  description = "Name of the GitHub Actions client certificate secret in Key Vault"
  value       = var.enable_vpn_certificate_auth ? "github-actions-client-cert-pem-${var.environment}" : null
}

output "vpn_client_key_secret_name" {
  description = "Name of the GitHub Actions client private key secret in Key Vault"
  value       = var.enable_vpn_certificate_auth ? "github-actions-client-key-pem-${var.environment}" : null
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

# Azure AD App Registration Outputs
output "azure_ad_application_id" {
  description = "Client ID of the Azure AD App Registration"
  value       = azuread_application.main.client_id
}

output "azure_ad_tenant_id" {
  description = "Azure AD Tenant ID"
  value       = data.azuread_client_config.current.tenant_id
}

output "azure_ad_application_name" {
  description = "Display name of the Azure AD App Registration"
  value       = azuread_application.main.display_name
}

output "azure_ad_service_principal_id" {
  description = "Object ID of the Service Principal"
  value       = azuread_service_principal.main.object_id
}

# Convenient aliases for deploy scripts
output "tenant_id" {
  description = "Azure AD Tenant ID (alias for deploy scripts)"
  value       = data.azuread_client_config.current.tenant_id
}

output "client_id" {
  description = "Azure AD Client ID (alias for deploy scripts)"
  value       = azuread_application.main.client_id
}

# AI Chat Service Outputs
output "ai_chat_service_name" {
  description = "Name of the AI Chat Container App"
  value       = azurerm_container_app.ai_chat_service.name
}

output "ai_chat_service_url" {
  description = "Direct URL for the AI Chat service"
  value       = "https://${azurerm_container_app.ai_chat_service.ingress[0].fqdn}"
}

output "ai_chat_service_fqdn" {
  description = "FQDN of the AI Chat Container App"
  value       = azurerm_container_app.ai_chat_service.ingress[0].fqdn
}

# WebRTC Signaling Service Outputs
output "webrtc_signaling_service_name" {
  description = "Name of the WebRTC Signaling Container App"
  value       = azurerm_container_app.webrtc_signaling_service.name
}

output "webrtc_signaling_service_url" {
  description = "Direct URL for the WebRTC Signaling service"
  value       = "https://${azurerm_container_app.webrtc_signaling_service.ingress[0].fqdn}"
}

output "webrtc_signaling_service_fqdn" {
  description = "FQDN of the WebRTC Signaling Container App"
  value       = azurerm_container_app.webrtc_signaling_service.ingress[0].fqdn
}

# Azure Communication Services Outputs
output "communication_service_name" {
  description = "Name of the Azure Communication Service"
  value       = azurerm_communication_service.webrtc.name
}

output "communication_service_connection_string" {
  description = "Primary connection string for Azure Communication Service (contains TURN credentials)"
  value       = azurerm_communication_service.webrtc.primary_connection_string
  sensitive   = true
}

output "communication_service_endpoint" {
  description = "Endpoint URL for Azure Communication Service"
  value       = "https://${azurerm_communication_service.webrtc.name}.communication.azure.com"
}

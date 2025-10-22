# Azure Communication Services for WebRTC TURN/STUN servers
resource "azurerm_communication_service" "webrtc" {
  name                = "acs-${var.resource_name_prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  data_location       = "United States" # Options: United States, Europe, Asia Pacific, United Kingdom, Australia

  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Service     = "WebRTC"
  })
}

# Output the connection string (mark as sensitive)
output "communication_service_connection_string" {
  value     = azurerm_communication_service.webrtc.primary_connection_string
  sensitive = true
}

output "communication_service_endpoint" {
  value = azurerm_communication_service.webrtc.primary_key
}

# Azure Communication Services for WebRTC TURN/STUN servers
resource "azurerm_communication_service" "webrtc" {
  name                = "acs-${var.resource_name_prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.core.name
  data_location       = "United States" # Options: United States, Europe, Asia Pacific, United Kingdom, Australia

  tags = local.common_tags
}

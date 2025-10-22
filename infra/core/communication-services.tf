# Azure Communication Services for WebRTC TURN/STUN servers
# Name must be globally unique - using random_id to ensure uniqueness
resource "random_id" "acs_suffix" {
  byte_length = 4
}

resource "azurerm_communication_service" "webrtc" {
  name                = "acs-${var.resource_name_prefix}-${var.environment}-${random_id.acs_suffix.hex}"
  resource_group_name = azurerm_resource_group.core.name
  data_location       = "United States" # Options: United States, Europe, Asia Pacific, United Kingdom, Australia

  tags = local.common_tags
}

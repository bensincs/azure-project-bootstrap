# Access policy for Application Gateway to access Bootstrap Key Vault
# This grants the Application Gateway managed identity permission to read certificates

resource "azurerm_key_vault_access_policy" "app_gateway" {
  key_vault_id = var.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.app_gateway.principal_id

  certificate_permissions = [
    "Get",
    "List",
  ]

  secret_permissions = [
    "Get",
    "List",
  ]
}

# Storage Account (keeping for potential future use - logs, backups, etc.)
# Static website functionality removed - UI now served via Container Apps
resource "azurerm_storage_account" "core" {
  name                     = "st${var.resource_name_prefix}${var.environment}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.core.name
  location                 = azurerm_resource_group.core.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # Security settings
  shared_access_key_enabled     = false
  https_traffic_only_enabled    = true
  min_tls_version               = "TLS1_2"
  public_network_access_enabled = false # Private endpoint only

  tags = merge(local.common_tags, local.mcaps_tags)
}

# Grant current user Storage Blob Data Contributor role on the storage account
resource "azurerm_role_assignment" "current_user_blob_contributor" {
  scope                = azurerm_storage_account.core.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

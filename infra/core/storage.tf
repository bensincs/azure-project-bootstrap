# Storage Account for Static Website
resource "azurerm_storage_account" "static_web" {
  name                     = "st${var.resource_name_prefix}web${var.environment}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.core.name
  location                 = azurerm_resource_group.core.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # Security settings
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = true # Required for static website
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"

  tags = merge(local.common_tags, local.mcaps_tags)
}

# Grant current user Storage Blob Data Contributor role on the storage account
resource "azurerm_role_assignment" "current_user_blob_contributor" {
  scope                = azurerm_storage_account.static_web.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Wait for RBAC permissions to propagate
resource "time_sleep" "wait_for_rbac" {
  depends_on = [azurerm_role_assignment.current_user_blob_contributor]

  create_duration = "60s"
}

# Enable static website on the storage account
resource "azurerm_storage_account_static_website" "core" {
  storage_account_id = azurerm_storage_account.static_web.id
  index_document     = "index.html"
  error_404_document = "404.html"

  depends_on = [time_sleep.wait_for_rbac]
}

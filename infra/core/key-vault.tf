# Key Vault for SSL certificates and secrets

# Key Vault
resource "azurerm_key_vault" "core" {
  name                       = "kv-${var.resource_name_prefix}-${var.environment}-${random_string.suffix.result}"
  resource_group_name        = azurerm_resource_group.core.name
  location                   = azurerm_resource_group.core.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  # Enable for Application Gateway
  enabled_for_deployment          = true
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true

  # Allow public access during certificate creation, then restrict with network_acls
  public_network_access_enabled = true

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow" # Can be set to "Deny" after initial setup
  }

  tags = local.common_tags
}

# Access policy for current user/service principal
resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.core.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  certificate_permissions = [
    "Get",
    "List",
    "Create",
    "Import",
    "Update",
    "Delete",
    "Purge",
    "Recover",
  ]

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Purge",
    "Recover",
  ]

  key_permissions = [
    "Get",
    "List",
    "Create",
    "Delete",
    "Purge",
    "Recover",
  ]
}

# Managed Identity for Application Gateway to access Key Vault
resource "azurerm_user_assigned_identity" "app_gateway" {
  name                = "id-appgw-${var.resource_name_prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location

  tags = local.common_tags
}

# Access policy for Application Gateway managed identity
resource "azurerm_key_vault_access_policy" "app_gateway" {
  key_vault_id = azurerm_key_vault.core.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.app_gateway.principal_id

  secret_permissions = [
    "Get",
    "List",
  ]

  certificate_permissions = [
    "Get",
    "List",
  ]

  depends_on = [azurerm_key_vault_access_policy.current_user]
}

# Self-signed certificate for Application Gateway
resource "azurerm_key_vault_certificate" "app_gateway" {
  name         = "appgw-ssl-cert"
  key_vault_id = azurerm_key_vault.core.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"] # Server Authentication

      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]

      subject            = "CN=launch.crewdune.com"
      validity_in_months = 12

      subject_alternative_names {
        dns_names = [
          "launch.crewdune.com",
        ]
      }
    }
  }

  depends_on = [azurerm_key_vault_access_policy.current_user]
}

# Private DNS Zone for Key Vault
resource "azurerm_private_dns_zone" "key_vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.core.name

  tags = local.common_tags
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  name                  = "pdnszvnl-kv-${var.environment}"
  resource_group_name   = azurerm_resource_group.core.name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  virtual_network_id    = azurerm_virtual_network.core.id
  registration_enabled  = false

  tags = local.common_tags
}

# Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-kv-${var.resource_name_prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-kv-${var.resource_name_prefix}-${var.environment}"
    private_connection_resource_id = azurerm_key_vault.core.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.key_vault.id]
  }

  tags = local.common_tags

  depends_on = [azurerm_key_vault.core]
}

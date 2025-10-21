# Auto-generated tfvars for core/stag
# Edit this file to customize your environment-specific variables

environment     = "stag"
location        = "uaenorth"
subscription_id = "dd78ec54-2f00-41fc-8055-8c1f2ad66a1d"

# Bootstrap Key Vault (for SSL certificates)
key_vault_id                   = "/subscriptions/dd78ec54-2f00-41fc-8055-8c1f2ad66a1d/resourceGroups/rg-terraform-state/providers/Microsoft.KeyVault/vaults/kv-bootstrap-pivgidzg"
key_vault_name                 = "kv-bootstrap-pivgidzg"
key_vault_uri                  = "https://kv-bootstrap-pivgidzg.vault.azure.net/"
app_gateway_ssl_certificate_id = "https://kv-bootstrap-pivgidzg.vault.azure.net/secrets/app-gateway-ssl-cert"

# Add your custom variables below this line
# Example:
# resource_name_prefix = "stag"
# tags = {
#   Environment = "stag"
#   ManagedBy   = "Terraform"
# }

enable_vpn_gateway          = true
enable_vpn_certificate_auth = true # Set to true to enable certificate-based auth for VPN
custom_domain               = "launchpad.sincs.dev"

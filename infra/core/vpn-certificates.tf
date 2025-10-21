# =============================================================================
# VPN TLS Certificate Management
# =============================================================================
# This file contains all TLS certificate generation and management resources
# for VPN Gateway certificate-based authentication. Certificates are stored
# in the bootstrap Key Vault created during the bootstrap phase.

# =============================================================================
# Root CA Certificate
# =============================================================================

# Generate private key for VPN root certificate
resource "tls_private_key" "vpn_root_key" {
  count     = var.enable_vpn_certificate_auth ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate self-signed root certificate
resource "tls_self_signed_cert" "vpn_root_cert" {
  count           = var.enable_vpn_certificate_auth ? 1 : 0
  private_key_pem = tls_private_key.vpn_root_key[0].private_key_pem

  subject {
    common_name  = "VPN Root Certificate - ${var.environment}"
    organization = "${var.resource_name_prefix} Infrastructure"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "crl_signing",
    "data_encipherment",
    "key_agreement",
  ]

  is_ca_certificate = true
}

# =============================================================================
# GitHub Actions Client Certificate
# =============================================================================

# Generate private key for GitHub Actions client certificate
resource "tls_private_key" "github_actions_client_key" {
  count     = var.enable_vpn_certificate_auth ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate certificate request for GitHub Actions client
resource "tls_cert_request" "github_actions_client_csr" {
  count           = var.enable_vpn_certificate_auth ? 1 : 0
  private_key_pem = tls_private_key.github_actions_client_key[0].private_key_pem

  subject {
    common_name  = "GitHub Actions VPN Client - ${var.environment}"
    organization = "${var.resource_name_prefix} CI/CD"
  }

  dns_names = [
    "github-actions.vpn.local",
    "cicd.vpn.local"
  ]
}

# Sign the GitHub Actions client certificate with the root CA
resource "tls_locally_signed_cert" "github_actions_client_cert" {
  count              = var.enable_vpn_certificate_auth ? 1 : 0
  cert_request_pem   = tls_cert_request.github_actions_client_csr[0].cert_request_pem
  ca_private_key_pem = tls_private_key.vpn_root_key[0].private_key_pem
  ca_cert_pem        = tls_self_signed_cert.vpn_root_cert[0].cert_pem

  validity_period_hours = 4380 # 6 months

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
    "data_encipherment",
    "key_agreement",
  ]
}

# =============================================================================
# Key Vault Secret Storage (Bootstrap Key Vault)
# =============================================================================

# Store the root certificate in Key Vault as a secret
resource "azurerm_key_vault_secret" "vpn_root_cert_pem" {
  count        = var.enable_vpn_certificate_auth ? 1 : 0
  name         = "vpn-root-cert-pem-${var.environment}"
  value        = tls_self_signed_cert.vpn_root_cert[0].cert_pem
  key_vault_id = var.key_vault_id

  tags = local.common_tags
}

# Store the root private key in Key Vault as a secret
resource "azurerm_key_vault_secret" "vpn_root_key_pem" {
  count        = var.enable_vpn_certificate_auth ? 1 : 0
  name         = "vpn-root-key-pem-${var.environment}"
  value        = tls_private_key.vpn_root_key[0].private_key_pem
  key_vault_id = var.key_vault_id

  tags = local.common_tags
}

# Store root certificate in PKCS#12 format for compatibility
resource "azurerm_key_vault_secret" "vpn_root_cert_pfx" {
  count        = var.enable_vpn_certificate_auth ? 1 : 0
  name         = "vpn-root-cert-pfx-${var.environment}"
  value        = base64encode(tls_self_signed_cert.vpn_root_cert[0].cert_pem)
  key_vault_id = var.key_vault_id

  tags = local.common_tags
}

# Store GitHub Actions client certificate in Key Vault
resource "azurerm_key_vault_secret" "github_actions_client_cert_pem" {
  count        = var.enable_vpn_certificate_auth ? 1 : 0
  name         = "github-actions-client-cert-pem-${var.environment}"
  value        = tls_locally_signed_cert.github_actions_client_cert[0].cert_pem
  key_vault_id = var.key_vault_id

  tags = local.common_tags
}

# Store GitHub Actions client private key in Key Vault
resource "azurerm_key_vault_secret" "github_actions_client_key_pem" {
  count        = var.enable_vpn_certificate_auth ? 1 : 0
  name         = "github-actions-client-key-pem-${var.environment}"
  value        = tls_private_key.github_actions_client_key[0].private_key_pem
  key_vault_id = var.key_vault_id

  tags = local.common_tags
}

# Store GitHub Actions client certificate in PKCS#12 format
resource "azurerm_key_vault_secret" "github_actions_client_cert_pfx" {
  count        = var.enable_vpn_certificate_auth ? 1 : 0
  name         = "github-actions-client-cert-pfx-${var.environment}"
  value        = base64encode(tls_locally_signed_cert.github_actions_client_cert[0].cert_pem)
  key_vault_id = var.key_vault_id

  tags = local.common_tags
}

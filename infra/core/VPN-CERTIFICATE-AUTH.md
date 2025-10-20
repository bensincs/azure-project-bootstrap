# VPN Gateway Certificate-Based Authentication

This document describes how to enable and use certificate-based authentication for the VPN Gateway in addition to Azure AD authentication.

## Overview

The VPN Gateway supports two authentication methods:
- **Azure AD (AAD)**: Default authentication method using Azure Active Directory
- **Certificate-based**: Optional authentication using TLS certificates (can be enabled alongside AAD)

## Architecture

When certificate-based authentication is enabled, the following components are created:

1. **Root CA Certificate**: A self-signed root certificate authority used to sign client certificates
2. **GitHub Actions Client Certificate**: A client certificate for CI/CD pipeline access
3. **Key Vault Secrets**: All certificates and keys are securely stored in the bootstrap Key Vault

## Enabling Certificate-Based Authentication

### Step 1: Update Configuration

Edit `infra/core/vars/dev.tfvars` (or your environment-specific tfvars file):

```hcl
enable_vpn_gateway          = true
enable_vpn_certificate_auth = true  # Set to true
```

### Step 2: Apply Terraform

```bash
cd infra/core
terraform apply -var-file="vars/dev.tfvars"
```

This will:
- Generate a root CA certificate (valid for 1 year)
- Generate a GitHub Actions client certificate (valid for 6 months)
- Store all certificates and keys in the bootstrap Key Vault
- Configure the VPN Gateway to accept both Certificate and AAD authentication

### Step 3: Retrieve Certificates from Key Vault

After Terraform applies successfully, you can retrieve the certificates:

```bash
# Get the bootstrap Key Vault name
KV_NAME=$(terraform output -raw key_vault_name)

# Download root certificate (PEM format)
az keyvault secret show --vault-name $KV_NAME --name vpn-root-cert-pem --query value -o tsv > vpn-root-cert.pem

# Download GitHub Actions client certificate and key
az keyvault secret show --vault-name $KV_NAME --name github-actions-client-cert-pem --query value -o tsv > github-actions-client-cert.pem
az keyvault secret show --vault-name $KV_NAME --name github-actions-client-key-pem --query value -o tsv > github-actions-client-key.pem
```

## Certificates Stored in Key Vault

When certificate authentication is enabled, the following secrets are created in the bootstrap Key Vault:

| Secret Name | Description | Format |
|-------------|-------------|--------|
| `vpn-root-cert-pem` | Root CA certificate | PEM |
| `vpn-root-key-pem` | Root CA private key | PEM |
| `vpn-root-cert-pfx` | Root CA certificate | Base64-encoded |
| `github-actions-client-cert-pem` | GitHub Actions client certificate | PEM |
| `github-actions-client-key-pem` | GitHub Actions client private key | PEM |
| `github-actions-client-cert-pfx` | GitHub Actions client certificate | Base64-encoded |

## Using Certificates

### For GitHub Actions

Add the following secrets to your GitHub repository:

```bash
# Set GitHub repository secrets
gh secret set VPN_CLIENT_CERT --body "$(cat github-actions-client-cert.pem)"
gh secret set VPN_CLIENT_KEY --body "$(cat github-actions-client-key.pem)"
```

Then use them in your workflow:

```yaml
- name: Connect to VPN
  run: |
    echo "${{ secrets.VPN_CLIENT_CERT }}" > client.crt
    echo "${{ secrets.VPN_CLIENT_KEY }}" > client.key
    # Configure OpenVPN with these certificates
```

### For Local Development

1. Download the client certificate and key from Key Vault (see Step 3 above)
2. Import them into your VPN client (Azure VPN Client or OpenVPN)
3. Configure the VPN connection with:
   - Gateway URL: `azuregateway-<gateway-id>.vpn.azure.com`
   - Certificate: `github-actions-client-cert.pem`
   - Private Key: `github-actions-client-key.pem`

### Creating Additional Client Certificates

To create additional client certificates (e.g., for developers), you can:

1. Extend the `vpn-certificates.tf` file with additional `tls_private_key`, `tls_cert_request`, and `tls_locally_signed_cert` resources
2. Store them in Key Vault using `azurerm_key_vault_secret` resources
3. Apply Terraform to generate and store the new certificates

Example:

```hcl
# Generate private key for developer client certificate
resource "tls_private_key" "dev_client_key" {
  count     = var.enable_vpn_certificate_auth ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate certificate request
resource "tls_cert_request" "dev_client_csr" {
  count           = var.enable_vpn_certificate_auth ? 1 : 0
  private_key_pem = tls_private_key.dev_client_key[0].private_key_pem

  subject {
    common_name  = "Developer VPN Client - ${var.environment}"
    organization = "${var.resource_name_prefix} Development"
  }
}

# Sign the certificate
resource "tls_locally_signed_cert" "dev_client_cert" {
  count              = var.enable_vpn_certificate_auth ? 1 : 0
  cert_request_pem   = tls_cert_request.dev_client_csr[0].cert_request_pem
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

# Store in Key Vault
resource "azurerm_key_vault_secret" "dev_client_cert_pem" {
  count        = var.enable_vpn_certificate_auth ? 1 : 0
  name         = "dev-client-cert-pem"
  value        = tls_locally_signed_cert.dev_client_cert[0].cert_pem
  key_vault_id = var.key_vault_id
  tags         = local.common_tags
}

resource "azurerm_key_vault_secret" "dev_client_key_pem" {
  count        = var.enable_vpn_certificate_auth ? 1 : 0
  name         = "dev-client-key-pem"
  value        = tls_private_key.dev_client_key[0].private_key_pem
  key_vault_id = var.key_vault_id
  tags         = local.common_tags
}
```

## Certificate Rotation

Certificates have the following validity periods:
- **Root CA**: 1 year (8760 hours)
- **Client Certificates**: 6 months (4380 hours)

To rotate certificates:

1. Update the `validity_period_hours` in `vpn-certificates.tf` if needed
2. Run `terraform taint` on the certificate resources to force regeneration:
   ```bash
   terraform taint 'tls_self_signed_cert.vpn_root_cert[0]'
   terraform taint 'tls_locally_signed_cert.github_actions_client_cert[0]'
   ```
3. Apply Terraform to regenerate and update the certificates
4. Update any systems using the old certificates

## Security Considerations

- All private keys are stored securely in Azure Key Vault
- Access to Key Vault is controlled via RBAC and access policies
- Certificates are automatically tagged with environment information
- The root CA is self-signed and should only be used for internal VPN authentication
- Client certificates are short-lived (6 months) and should be rotated regularly

## Troubleshooting

### Certificate Not Working

1. Verify the certificate is stored in Key Vault:
   ```bash
   az keyvault secret list --vault-name $KV_NAME --query "[?contains(name, 'vpn')]"
   ```

2. Check the VPN Gateway configuration:
   ```bash
   az network vnet-gateway show --resource-group <rg-name> --name <vpn-gateway-name>
   ```

3. Verify the certificate format (remove BEGIN/END markers for Azure VPN Gateway)

### Certificate Expired

Follow the certificate rotation steps above to generate new certificates.

## Disabling Certificate-Based Authentication

To disable certificate-based authentication and revert to AAD-only:

1. Set `enable_vpn_certificate_auth = false` in your tfvars file
2. Apply Terraform: `terraform apply -var-file="vars/dev.tfvars"`
3. Optionally, remove the certificate secrets from Key Vault manually

## References

- [Azure VPN Gateway Documentation](https://docs.microsoft.com/azure/vpn-gateway/)
- [Configure certificate authentication](https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-howto-point-to-site-resource-manager-portal)
- [Terraform TLS Provider](https://registry.terraform.io/providers/hashicorp/tls/latest/docs)

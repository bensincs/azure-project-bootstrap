# Infrastructure Scripts

This directory contains helper scripts for managing your Azure infrastructure.

## VPN Connection Script

### `connect.sh`

Connects to the Azure VPN Gateway using certificate-based authentication via OpenVPN.

#### Prerequisites

1. **OpenVPN** installed:
   ```bash
   # macOS
   brew install openvpn
   
   # Ubuntu/Debian
   sudo apt-get install openvpn
   
   # RHEL/CentOS
   sudo yum install openvpn
   ```

2. **Azure CLI** logged in:
   ```bash
   az login
   ```

3. **Terraform** initialized and applied:
   ```bash
   cd infra/core
   terraform init
   terraform apply -var-file="vars/dev.tfvars"
   ```

4. **Certificate authentication enabled** in your tfvars:
   ```hcl
   enable_vpn_gateway          = true
   enable_vpn_certificate_auth = true
   ```

#### Usage

```bash
# Connect to VPN (uses current Terraform workspace)
./infra/scripts/connect.sh

# Download certificates only (don't connect)
./infra/scripts/connect.sh --download

# Use a different client certificate from Key Vault
./infra/scripts/connect.sh --client-cert dev-client
```

#### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-d, --download` | Download certificates only, don't connect | false |
| `-c, --client-cert NAME` | Client certificate name in Key Vault | github-actions |
| `-h, --help` | Show help message | - |

#### What it does

1. **Validates requirements** - Checks for Azure CLI, OpenVPN, and Terraform
2. **Retrieves VPN configuration** - Reads Terraform outputs for VPN Gateway details
3. **Downloads certificates** - Fetches root CA, client cert, and private key from Key Vault
4. **Generates VPN profile** - Downloads OpenVPN configuration from Azure
5. **Configures OpenVPN** - Injects certificates into the OpenVPN config
6. **Connects** - Starts OpenVPN connection (requires sudo)

#### Files Created

The script creates temporary files in `/tmp`:

- `/tmp/vpn-certs/` - Certificate directory
  - `ca.crt` - Root CA certificate
  - `client.crt` - Client certificate
  - `client.key` - Client private key (permissions: 600)
- `/tmp/vpn-profile/` - OpenVPN configuration directory
  - `OpenVPN/vpnconfig.ovpn` - OpenVPN configuration file

#### Disconnecting

To disconnect from the VPN:
- Press `Ctrl+C` if running in foreground
- Or use `sudo killall openvpn`

#### Cleanup

To remove downloaded certificates and profiles:

```bash
rm -rf /tmp/vpn-certs /tmp/vpn-profile /tmp/vpn-profile.zip
```

#### Troubleshooting

**Error: "VPN Gateway is not enabled"**
- Set `enable_vpn_gateway = true` in your tfvars and run `terraform apply`

**Error: "Certificate authentication is not enabled"**
- Set `enable_vpn_certificate_auth = true` in your tfvars and run `terraform apply`

**Error: "Terraform is not initialized"**
- Run `cd infra/core && terraform init`

**Error: "OpenVPN is not installed"**
- Install OpenVPN using the commands in the Prerequisites section

**Connection fails or times out**
- Check that the VPN Gateway is deployed: `az network vnet-gateway show --name <gateway-name> --resource-group <rg-name>`
- Verify your IP isn't blocked by any firewall rules
- Check the OpenVPN logs for detailed error messages

**Certificate errors**
- Verify certificates exist in Key Vault: `az keyvault secret list --vault-name <kv-name>`
- Ensure you have permission to read secrets from Key Vault
- Try regenerating certificates by running `terraform taint` and `terraform apply`

#### Security Notes

- Private keys are stored with `600` permissions (owner read/write only)
- Certificates are stored in `/tmp` and should be cleaned up after use
- The script requires sudo access to run OpenVPN
- All secrets are retrieved from Azure Key Vault with proper authentication

#### Examples

Connect to VPN with default settings:
```bash
./infra/scripts/connect.sh
```

Download certificates without connecting (useful for manual configuration):
```bash
./infra/scripts/connect.sh --download
```

Use a custom client certificate (e.g., for a specific developer):
```bash
./infra/scripts/connect.sh --client-cert developer-john
```

## Adding More Scripts

When adding new scripts to this directory:

1. Make them executable: `chmod +x script-name.sh`
2. Add a shebang: `#!/bin/bash`
3. Use `set -e` to exit on errors
4. Document the script in this README
5. Add helpful error messages and validation
6. Use the Terraform outputs for configuration where possible

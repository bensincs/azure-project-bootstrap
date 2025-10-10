# VPN Gateway Setup Guide - Azure Entra ID Authentication

> **Note**: VPN Gateway deployment is **disabled by default** to reduce costs and deployment time. Set `enable_vpn_gateway = true` in `vars/dev.tfvars` to enable it.

This guide explains how to connect to your Azure VPN Gateway using Azure Entra ID (Azure AD) authentication.

## Overview

The VPN Gateway provides secure remote access to private resources in the Azure Virtual Network, including:
- Container Apps (internal-only ingress)
- Storage Account (private endpoint)
- Container Registry (private endpoint)
- Private DNS Resolver

## Enabling VPN Gateway

To deploy the VPN Gateway, edit `vars/dev.tfvars` and set:

```hcl
enable_vpn_gateway = true
```

Then deploy:

```bash
terraform apply -var-file=vars/dev.tfvars
```

**⏱️ Note**: VPN Gateway provisioning takes 30-45 minutes and adds ~$150/month to your costs.

## Prerequisites

### 1. Azure VPN Client

Download and install the Azure VPN Client:
- **Windows**: [Microsoft Store](https://www.microsoft.com/store/productId/9NP355QT2SQB)
- **macOS**: [Mac App Store](https://apps.apple.com/app/azure-vpn-client/id1553936137)

### 2. Azure Account

You need Azure AD credentials with access to the subscription. **No certificates required** - authentication uses Azure Entra ID (Azure AD).

## VPN Configuration Details

- **Authentication**: Azure Entra ID (Azure AD)
- **Protocol**: OpenVPN (UDP 1194)
- **Client Address Pool**: 172.16.0.0/24
- **VNet Address Space**: 10.0.0.0/16
- **Gateway SKU**: VpnGw1 (can be upgraded to VpnGw2/VpnGw3)

## Setup Instructions

### Step 1: Deploy Infrastructure

Deploy the Terraform infrastructure which includes the VPN Gateway:

```bash
cd infra/core
terraform init -backend-config=backends/backend-dev.hcl
terraform plan -var-file=vars/dev.tfvars
terraform apply -var-file=vars/dev.tfvars
```

**⏱️ Note**: VPN Gateway provisioning takes 20-45 minutes.

### Step 2: Get VPN Configuration

After the gateway is deployed, download the VPN client configuration:

```bash
# Get the resource group and gateway name from Terraform outputs
RESOURCE_GROUP=$(cd infra/core && terraform output -raw resource_group_name)
VPN_GATEWAY_NAME=$(cd infra/core && terraform output -raw vpn_gateway_name)

# Generate and download VPN client configuration
az network vnet-gateway vpn-client generate \
  --resource-group $RESOURCE_GROUP \
  --name $VPN_GATEWAY_NAME \
  --authentication-method EAPTLS

# This returns a URL - download the zip file
```

The command will return a URL like:
```
https://....blob.core.windows.net/.../vpnclientconfiguration.zip
```

Download this file using your browser or:

```bash
# Download the zip file
curl -o vpn-config.zip "<URL_FROM_PREVIOUS_COMMAND>"

# Extract it
unzip vpn-config.zip
```

### Step 3: Import Configuration

The extracted zip file contains `AzureVPN/azurevpnconfig.xml`. Import this into the Azure VPN Client:

#### On macOS:
1. Open **Azure VPN Client**
2. Click the **+** button (bottom left)
3. Click **Import**
4. Select the `azurevpnconfig.xml` file from `AzureVPN/` folder
5. Click **Save**

#### On Windows:
1. Open **Azure VPN Client**
2. Click **+** → **Import**
3. Select the `azurevpnconfig.xml` file from `AzureVPN\` folder
4. Click **Save**

### Step 4: Connect

1. In the Azure VPN Client, click on your imported connection profile
2. Click **Connect**
3. You'll be redirected to sign in with your Azure AD credentials
4. After authentication, the VPN tunnel will be established
5. You'll receive an IP address from the 172.16.0.0/24 pool

### Step 5: Verify Connection

Check your VPN connection:

```bash
# Check your VPN IP (should be in 172.16.0.0/24 range)
ifconfig | grep "172.16"  # macOS/Linux
ipconfig | findstr "172.16"  # Windows
```

## Accessing Private Resources

Once connected to the VPN, you can access private resources:

### Container Apps (Internal)

```bash
# Get Container App internal FQDN
cd infra/core
API_FQDN=$(terraform output -raw api_service_fqdn)
NOTIFICATION_FQDN=$(terraform output -raw notification_service_fqdn)

# Access via internal FQDN
curl https://$API_FQDN/health
curl https://$API_FQDN/api/hello

curl https://$NOTIFICATION_FQDN/health
```

### Storage Account (Private Endpoint)

```bash
# List blobs in the static website container
STORAGE_ACCOUNT=$(cd infra/core && terraform output -raw storage_account_name)

az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name '$web' \
  --auth-mode login
```

### Container Registry (Private Endpoint)

```bash
# List repositories
ACR_NAME=$(cd infra/core && terraform output -raw container_registry_name)

az acr repository list --name $ACR_NAME

# Login and push/pull images
az acr login --name $ACR_NAME
```

### DNS Resolution

The Private DNS Resolver automatically resolves private endpoints:

```bash
# Test DNS resolution
nslookup $API_FQDN
nslookup $ACR_NAME.azurecr.io
nslookup $STORAGE_ACCOUNT.blob.core.windows.net
```

## Architecture

```
Internet
   │
   ├─── VPN Client (172.16.0.0/24)
   │       │
   │       └─── Azure AD Authentication
   │               │
   │               ▼
   │       VPN Gateway (10.0.3.0/27)
   │               │
   │               └─── Virtual Network (10.0.0.0/16)
   │                       │
   │                       ├─── Container Apps Subnet (10.0.0.0/23)
   │                       │       ├─── API Service (internal)
   │                       │       └─── Notification Service (internal)
   │                       │
   │                       ├─── Private Endpoints Subnet (10.0.2.0/24)
   │                       │       ├─── Storage Private Endpoint
   │                       │       └─── ACR Private Endpoint
   │                       │
   │                       └─── DNS Resolver Subnets (10.0.4.0/28, 10.0.4.16/28)
   │                               └─── Private DNS Resolver
   │
   └─── Front Door (Public)
           │
           └─── Private Link ──> Container Apps (internal)
```

## Troubleshooting

### Cannot Connect to VPN

**1. Check Gateway Status**
```bash
az network vnet-gateway show \
  --resource-group $RESOURCE_GROUP \
  --name $VPN_GATEWAY_NAME \
  --query provisioningState
```

Should return: `"Succeeded"`

**2. Verify Azure AD Configuration**
```bash
# Check VPN client configuration
az network vnet-gateway show \
  --resource-group $RESOURCE_GROUP \
  --name $VPN_GATEWAY_NAME \
  --query "vpnClientConfiguration"
```

Verify:
- `aadTenant` matches your tenant
- `aadAudience` is `41b23e61-6c1e-4545-b367-cd054e0ed4b4`
- `vpnAuthenticationTypes` includes `AAD`

**3. Check User Permissions**

Ensure your Azure AD account has access to the subscription:
```bash
az account show
```

### Cannot Access Private Resources

**1. Verify VPN IP Assignment**
```bash
# Should show an IP in 172.16.0.0/24 range
ifconfig | grep "172.16"  # macOS
ip addr | grep "172.16"   # Linux
ipconfig | findstr "172.16"  # Windows
```

**2. Test DNS Resolution**
```bash
# Should resolve to private IPs (10.0.x.x)
nslookup <container-app-name>.<region>.azurecontainerapps.io
```

**3. Check NSG Rules**
```bash
# Verify NSG allows traffic from VPN pool
az network nsg rule list \
  --resource-group $RESOURCE_GROUP \
  --nsg-name nsg-container-apps-dev \
  --output table
```

**4. Test Connectivity**
```bash
# Ping private IPs (if ICMP is allowed)
ping 10.0.0.4

# Test specific ports
nc -zv <internal-fqdn> 443  # macOS/Linux
Test-NetConnection -ComputerName <internal-fqdn> -Port 443  # Windows
```

### DNS Resolution Issues

**1. Check DNS Resolver Status**
```bash
az dns-resolver show \
  --resource-group $RESOURCE_GROUP \
  --name pdnsr-core-dev \
  --query provisioningState
```

**2. Verify Private DNS Zones**
```bash
# List private DNS zones
az network private-dns zone list \
  --resource-group $RESOURCE_GROUP \
  --output table

# Check VNet links
az network private-dns link vnet list \
  --resource-group $RESOURCE_GROUP \
  --zone-name <region>.azurecontainerapps.io \
  --output table
```

**3. Manual DNS Test**
```bash
# Get DNS resolver IP
RESOLVER_IP=$(cd infra/core && terraform output -raw dns_resolver_inbound_ip)

# Test DNS directly
nslookup <resource-fqdn> $RESOLVER_IP
```

## Security Features

### Azure AD Authentication

- **Single Sign-On**: Uses your existing Azure AD credentials
- **No Certificate Management**: No need to generate, distribute, or rotate certificates
- **Centralized Control**: Manage VPN access through Azure AD user/group assignments

### Conditional Access (Optional)

Add additional security requirements in Azure AD:

1. Go to **Azure Portal** → **Azure Active Directory** → **Security** → **Conditional Access**
2. Create a new policy
3. **Assignments**:
   - Users: Select specific users or groups
   - Cloud apps: Select "Azure VPN" (App ID: 41b23e61-6c1e-4545-b367-cd054e0ed4b4)
4. **Access controls**:
   - Require multi-factor authentication
   - Require compliant device
   - Require approved client app
   - Block from specific locations
5. **Enable policy**

### Network Isolation

- ✅ Container Apps: Internal ingress only, no public endpoints
- ✅ Storage Account: Public network access disabled
- ✅ Container Registry: Public network access disabled
- ✅ Private DNS: Internal name resolution only
- ✅ NSG Rules: Restrict traffic between subnets

## Cost Considerations

### Monthly Costs (Approximate)

- **VPN Gateway (VpnGw1)**: ~$140/month (730 hours)
- **Premium Container Registry**: ~$280/month (required for private endpoints)
- **Private DNS Resolver**: ~$29/month + $0.40 per million queries
- **Premium Front Door**: ~$330/month + data transfer
- **Outbound Data Transfer**: $0.087/GB (first 10TB)

### Cost Optimization Tips

1. **VPN Gateway**:
   - Use VpnGw1 for up to 650 Mbps throughput
   - Upgrade to VpnGw2/3 only if needed
   - Consider VpnGw1AZ for zone redundancy

2. **Container Registry**:
   - Premium tier required for private endpoints
   - Use geo-replication only if needed
   - Enable image retention policies to reduce storage

3. **Front Door**:
   - Premium tier required for Private Link
   - Use caching to reduce origin requests
   - Monitor usage and optimize routing

4. **Alternative**: Azure Bastion ($140/month) if you only need Azure portal/SSH/RDP access

## Additional Resources

- [Azure VPN Gateway Documentation](https://learn.microsoft.com/en-us/azure/vpn-gateway/)
- [Azure AD Authentication for VPN](https://learn.microsoft.com/en-us/azure/vpn-gateway/openvpn-azure-ad-tenant)
- [Azure VPN Client](https://learn.microsoft.com/en-us/azure/vpn-gateway/point-to-site-vpn-client-cert-windows)
- [Private DNS Resolver](https://learn.microsoft.com/en-us/azure/dns/dns-private-resolver-overview)
- [Container Apps VNet Integration](https://learn.microsoft.com/en-us/azure/container-apps/vnet-custom)
- [Front Door Private Link](https://learn.microsoft.com/en-us/azure/frontdoor/private-link)

## Next Steps

After setting up VPN access:

1. **Deploy Services**: Update Container Apps via private ACR
2. **Test End-to-End**: Verify Front Door → Private Link → Container Apps flow
3. **Configure Monitoring**: Set up Application Insights and Log Analytics
4. **Set Up CI/CD**: Update GitHub Actions to deploy via VPN or self-hosted runners
5. **Enable Conditional Access**: Add MFA and device compliance requirements
6. **Document Access Procedures**: Create runbook for team members

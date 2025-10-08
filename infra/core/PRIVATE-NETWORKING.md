# Private Networking Implementation Summary

This document summarizes the comprehensive private networking implementation for the Azure infrastructure.

## Overview

All resources have been secured behind a Virtual Network with no public access. The architecture implements:

✅ **Virtual Network** - Isolated network with dedicated subnets
✅ **VPN Gateway** - Secure remote access using Azure Entra ID authentication
✅ **Private DNS Resolver** - Internal name resolution
✅ **Private Endpoints** - Secure access to Storage and Container Registry
✅ **Container Apps VNet Integration** - Internal-only Container Apps
✅ **Azure Front Door Premium** - Public-facing endpoint with Private Link to backends
✅ **Network Security Groups** - Traffic isolation and security rules

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Internet                                        │
│                                                                          │
│  ┌──────────────────────┐           ┌────────────────────────┐         │
│  │  VPN Clients         │           │  Azure Front Door      │         │
│  │  (172.16.0.0/24)     │           │  (Premium)             │         │
│  │  Azure AD Auth       │           │  Public Endpoint       │         │
│  └──────────┬───────────┘           └──────────┬─────────────┘         │
│             │                                   │                        │
└─────────────┼───────────────────────────────────┼────────────────────────┘
              │                                   │
              │ OpenVPN                           │ Private Link
              │                                   │
┌─────────────▼───────────────────────────────────▼────────────────────────┐
│                     Azure Virtual Network                                 │
│                         (10.0.0.0/16)                                     │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  VPN Gateway Subnet (10.0.3.0/27)                               │    │
│  │  - VPN Gateway (VpnGw1)                                         │    │
│  │  - Public IP for VPN                                            │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Container Apps Subnet (10.0.0.0/23)                            │    │
│  │  - Container Apps Environment (internal load balancer)          │    │
│  │  - API Service (internal ingress only)                          │    │
│  │  - Notification Service (internal ingress only)                 │    │
│  │  - NSG: Allow Front Door + VPN traffic                          │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Private Endpoints Subnet (10.0.2.0/24)                         │    │
│  │  - Storage Account Private Endpoint (blob)                      │    │
│  │  - Container Registry Private Endpoint                          │    │
│  │  - NSG: Allow VNet traffic                                      │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  DNS Resolver Subnets                                           │    │
│  │  - Inbound Endpoint (10.0.4.0/28)                               │    │
│  │  - Outbound Endpoint (10.0.4.16/28)                             │    │
│  │  - Private DNS Resolver                                         │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Private DNS Zones                                              │    │
│  │  - <region>.azurecontainerapps.io                               │    │
│  │  - privatelink.blob.core.windows.net                            │    │
│  │  - privatelink.azurecr.io                                       │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────────────────────┘
```

## Infrastructure Files

The infrastructure is organized into modular Terraform files:

| File | Purpose | Resources |
|------|---------|-----------|
| `provider.tf` | Terraform and provider configuration | terraform, azurerm provider, data sources, locals |
| `resource-group.tf` | Resource group and naming | azurerm_resource_group, random_string |
| `network.tf` | Virtual network infrastructure | VNet, subnets, NSGs |
| `vpn-gateway.tf` | VPN Gateway with Azure AD auth | Public IP, Virtual Network Gateway |
| `dns-resolver.tf` | Private DNS Resolver | Resolver, inbound/outbound endpoints, forwarding rules |
| `private-dns.tf` | Private DNS Zones | DNS zones for Container Apps, Storage, ACR |
| `private-endpoints.tf` | Private Endpoints | Storage and ACR private endpoints |
| `storage.tf` | Storage Account (private) | Storage account with private endpoint |
| `container-registry.tf` | Container Registry (private) | ACR Premium with private endpoint |
| `container-apps.tf` | Container Apps (internal) | Environment with VNet integration, Container Apps |
| `front-door.tf` | Azure Front Door | Profile, endpoint, origins, routes |
| `outputs.tf` | Terraform outputs | All resource outputs |
| `variables.tf` | Input variables | Configuration variables |

## Security Configuration

### Storage Account
```hcl
public_network_access_enabled = false
network_rules {
  default_action = "Deny"
  bypass         = ["AzureServices"]
}
```

### Container Registry
```hcl
sku                           = "Premium"  # Required for private endpoints
public_network_access_enabled = false
network_rule_set {
  default_action = "Deny"
}
```

### Container Apps Environment
```hcl
infrastructure_subnet_id       = azurerm_subnet.container_apps.id
internal_load_balancer_enabled = true
workload_profile {
  name                  = "Consumption"
  workload_profile_type = "Consumption"
}
```

### Container Apps
```hcl
ingress {
  external_enabled = false  # Internal only
  target_port      = <port>
  transport        = "http"
}
```

### Network Security Groups

**Container Apps NSG:**
- Allow inbound from Azure Front Door Backend (ports 80, 443)
- Allow inbound from VPN client pool (172.16.0.0/24)
- Allow outbound to Internet (for external dependencies)

**Private Endpoints NSG:**
- Allow inbound from VNet (all ports)
- Allow outbound to VNet (all ports)

### VPN Gateway with Azure Entra ID
```hcl
vpn_client_configuration {
  address_space        = ["172.16.0.0/24"]
  vpn_client_protocols = ["OpenVPN"]  # Only OpenVPN supports Azure AD
  vpn_auth_types       = ["AAD"]

  aad_tenant   = "https://login.microsoftonline.com/<tenant-id>/"
  aad_audience = "41b23e61-6c1e-4545-b367-cd054e0ed4b4"  # Azure VPN Client ID
  aad_issuer   = "https://sts.windows.net/<tenant-id>/"
}
```

**Benefits of Azure AD Authentication:**
- ✅ No certificate management required
- ✅ Centralized user management in Azure AD
- ✅ Supports Conditional Access policies
- ✅ MFA and device compliance enforcement
- ✅ Easier onboarding/offboarding

## Deployment Guide

### 1. Prerequisites

- Terraform 1.13.3+
- Azure CLI
- Azure subscription with permissions
- Azure VPN Client (for VPN access)

### 2. Deploy Infrastructure

```bash
cd infra/core

# Initialize Terraform
terraform init -backend-config=backends/backend-dev.hcl

# Review changes
terraform plan -var-file=vars/dev.tfvars

# Deploy (VPN Gateway takes 20-45 minutes)
terraform apply -var-file=vars/dev.tfvars
```

### 3. Set Up VPN Access

Follow the detailed guide in [VPN-SETUP.md](./VPN-SETUP.md):

1. Download VPN client configuration
2. Import into Azure VPN Client
3. Connect using Azure AD credentials
4. Verify access to private resources

### 4. Deploy Services

Once connected via VPN, deploy the services:

```bash
# Deploy Notification Service
cd services/notification-service
./deploy.sh

# Deploy API Service
cd services/api
./deploy.sh

# Deploy UI
cd services/ui
./deploy.sh
```

## Access Patterns

### Public Access (via Front Door)

Users access the application through Azure Front Door:

```
https://afd-core-dev-<suffix>.z01.azurefd.net/
  ├─ /*                     → Static Website (Storage)
  ├─ /api/*                 → API Service (via Private Link)
  └─ /api/notifications/*   → Notification Service (via Private Link)
```

Front Door connects to Container Apps via Private Link, ensuring backends remain private.

### Private Access (via VPN)

Developers/admins connect via VPN for:

1. **Direct Container App Access**
   ```bash
   curl https://<app-name>.internal.<region>.azurecontainerapps.io/health
   ```

2. **Storage Account Access**
   ```bash
   az storage blob list --account-name <storage> --container-name '$web' --auth-mode login
   ```

3. **Container Registry Access**
   ```bash
   az acr login --name <acr>
   docker push <acr>.azurecr.io/<image>
   ```

4. **Container App Exec/Debug**
   ```bash
   az containerapp exec --name <app> --resource-group <rg>
   ```

## Cost Analysis

### Monthly Costs (Approximate)

| Resource | SKU/Tier | Monthly Cost |
|----------|----------|--------------|
| VPN Gateway | VpnGw1 | $140 |
| Container Registry | Premium | $280 |
| Private DNS Resolver | Standard | $29 + queries |
| Azure Front Door | Premium | $330 + data |
| Container Apps Environment | Consumption | $0 + usage |
| Storage Account | Standard LRS | $20-40 |
| Log Analytics | Pay-as-you-go | $2-10 |
| Virtual Network | Free | $0 |
| Private Endpoints (2) | Standard | $15 |
| NSGs | Free | $0 |
| **Total** | | **~$816-874/month** |

**Note**: Actual costs vary based on:
- Data transfer (outbound)
- Container Apps usage (CPU/memory/requests)
- Front Door requests and data transfer
- Log Analytics ingestion
- DNS resolver queries

### Cost Optimization

1. **VPN Gateway**: Use VpnGw1 unless higher throughput needed
2. **Container Registry**: Premium required for private endpoints
3. **Front Door**: Use caching to reduce origin requests
4. **Container Apps**: Set appropriate min/max replicas
5. **Log Analytics**: Set retention to 30 days
6. **Private DNS Resolver**: Monitor query volumes

## Monitoring and Troubleshooting

### Health Checks

```bash
# Check VPN Gateway status
az network vnet-gateway show \
  --resource-group <rg> \
  --name <vpn-gateway> \
  --query provisioningState

# Check Private DNS Resolver
az dns-resolver show \
  --resource-group <rg> \
  --name pdnsr-core-dev \
  --query provisioningState

# Check Container Apps health (via VPN)
curl https://<app-fqdn>/health

# Check Front Door health
az afd endpoint show \
  --profile-name afd-core-dev \
  --resource-group <rg> \
  --endpoint-name <endpoint>
```

### Logs

```bash
# Container Apps logs
az containerapp logs show \
  --name <app> \
  --resource-group <rg> \
  --follow

# VPN Gateway diagnostics
az network vnet-gateway show \
  --resource-group <rg> \
  --name <vpn-gateway> \
  --query vpnClientConfiguration

# Front Door logs (Log Analytics)
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "AzureDiagnostics | where Category == 'FrontDoorAccessLog'"
```

### Common Issues

1. **Cannot connect to VPN**
   - Verify Azure AD credentials
   - Check gateway provisioning state
   - Regenerate VPN client configuration
   - Verify tenant ID in configuration

2. **Cannot access Container Apps via VPN**
   - Verify VPN IP assignment (172.16.0.0/24)
   - Check NSG rules allow VPN traffic
   - Test DNS resolution
   - Verify Container Apps are running

3. **Front Door cannot reach backends**
   - Verify Private Link approval status
   - Check Container Apps health probes
   - Review Front Door routing rules
   - Check internal load balancer

4. **DNS resolution fails**
   - Check Private DNS Resolver status
   - Verify Private DNS Zone VNet links
   - Test with specific DNS server IP
   - Verify DNS forwarding rules

## Security Best Practices

### Implemented

- ✅ Azure AD authentication for VPN (no certificates)
- ✅ Private endpoints for PaaS services
- ✅ Internal-only Container Apps
- ✅ Network Security Groups
- ✅ Private DNS zones
- ✅ HTTPS everywhere
- ✅ No public access to backends
- ✅ Premium SKUs for security features

### Recommended Enhancements

- 🔐 **Enable Azure AD Conditional Access for VPN**
  - Require multi-factor authentication
  - Enforce compliant devices
  - Block risky sign-ins
  - Restrict by location

- 🔐 **Implement Azure DDoS Protection**
  - Enable DDoS Protection Standard on VNet
  - Configure alerts and monitoring

- 🔐 **Enable Azure Web Application Firewall**
  - Configure WAF on Front Door
  - Enable OWASP rules
  - Custom rules for application

- 🔐 **Use Managed Identity**
  - Configure Container Apps managed identity
  - Access Key Vault without secrets
  - Connect to Azure services securely

- 🔐 **Implement Key Vault**
  - Store secrets in Key Vault
  - Use private endpoint for Key Vault
  - Reference secrets in Container Apps

- 🔐 **Enable Azure Defender**
  - Enable Defender for Cloud
  - Configure security alerts
  - Implement recommendations

- 🔐 **Configure Azure Policy**
  - Enforce naming conventions
  - Require encryption
  - Audit compliance

- 🔐 **Implement Azure Sentinel**
  - Set up SIEM for security events
  - Configure threat detection
  - Create incident response workflows

- 🔐 **Enable Diagnostic Logs**
  - Send logs to Log Analytics
  - Configure retention policies
  - Create alerts for security events

## Next Steps

### 1. Enable Conditional Access

Configure Azure AD Conditional Access for VPN:

1. Go to **Azure Portal** → **Azure Active Directory** → **Security** → **Conditional Access**
2. Create new policy:
   - **Users**: Select specific users/groups
   - **Cloud apps**: "Azure VPN" (App ID: 41b23e61-6c1e-4545-b367-cd054e0ed4b4)
   - **Conditions**: Configure as needed
   - **Grant**: Require MFA, compliant device, etc.

### 2. Implement CI/CD with Private Access

Option A: Self-hosted GitHub Runners
```bash
# Deploy runner in VNet
# Configure runner to access private resources
```

Option B: Azure DevOps with Microsoft-hosted agents
```yaml
# Use Azure DevOps pipelines
# Configure service connections
```

### 3. Configure Monitoring

```bash
# Enable Application Insights
# Configure alerts for:
# - Failed VPN connections
# - Container App failures
# - Front Door errors
# - High latency
# - Resource exhaustion
```

### 4. Document Procedures

Create documentation for:
- **Onboarding**: How to get VPN access
- **Incident Response**: Troubleshooting guide
- **Disaster Recovery**: Backup and restore procedures
- **Security Incident**: Response playbook

### 5. Compliance and Governance

- Implement Azure Policy for compliance
- Configure resource locks on critical resources
- Set up cost management alerts
- Regular security audits
- Compliance reporting

## References

- [VPN Setup Guide](./VPN-SETUP.md) - Detailed VPN connection instructions
- [Azure VPN Gateway](https://learn.microsoft.com/en-us/azure/vpn-gateway/)
- [Azure AD Authentication for VPN](https://learn.microsoft.com/en-us/azure/vpn-gateway/openvpn-azure-ad-tenant)
- [Private DNS Resolver](https://learn.microsoft.com/en-us/azure/dns/dns-private-resolver-overview)
- [Container Apps VNet Integration](https://learn.microsoft.com/en-us/azure/container-apps/vnet-custom)
- [Front Door Private Link](https://learn.microsoft.com/en-us/azure/frontdoor/private-link)
- [Azure Private Endpoint](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview)
- [Conditional Access](https://learn.microsoft.com/en-us/azure/active-directory/conditional-access/)

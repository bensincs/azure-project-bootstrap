# Network Security Rules Documentation

This document explains the NSG rules and network flow for the infrastructure.

## Architecture Flow

```
Internet (Users)
    ↓
    ↓ HTTPS:443 / HTTP:80
    ↓
┌───────────────────────────────┐
│  Application Gateway          │
│  Subnet: 10.0.5.0/24         │
│  Public IP + Private IP       │
└───────────────────────────────┘
    ↓
    ↓ HTTPS:443 (via private IP)
    ↓
┌───────────────────────────────┐
│  API Management (APIM)        │
│  Subnet: 10.0.6.0/27         │
│  Internal VNet Mode (Private) │
│  - JWT Validation             │
│  - Path-based Routing         │
└───────────────────────────────┘
    ↓
    ↓ HTTPS:443
    ↓
┌───────────────────────────────┐
│  Container Apps               │
│  Subnet: 10.0.0.0/23         │
│  - API Service                │
│  - UI Service                 │
│  - Notification Service       │
└───────────────────────────────┘
```

## Subnet Allocation

| Subnet | Address Range | Purpose |
|--------|---------------|---------|
| Container Apps | 10.0.0.0/23 | Container Apps Environment (510 IPs) |
| Private Endpoints | 10.0.2.0/24 | Private endpoints for Storage, ACR (254 IPs) |
| VPN Gateway | 10.0.3.0/27 | VPN Gateway (27 IPs) |
| DNS Resolver | 10.0.4.0/28 | Private DNS Resolver (14 IPs) |
| App Gateway | 10.0.5.0/24 | Application Gateway (254 IPs) |
| APIM | 10.0.6.0/27 | API Management (27 IPs) |

## NSG Rules by Subnet

### 1. Application Gateway NSG (`nsg-appgw`)

**Purpose**: Allows public Internet traffic and Azure infrastructure management

| Priority | Direction | Source | Destination | Ports | Protocol | Purpose |
|----------|-----------|--------|-------------|-------|----------|---------|
| 110 | Inbound | Internet | * | 443 | TCP | Public HTTPS access |
| 120 | Inbound | Internet | * | 80 | TCP | HTTP to HTTPS redirect |
| 130 | Inbound | GatewayManager | * | 65200-65535 | TCP | Azure infrastructure (REQUIRED v2) |
| 140 | Inbound | AzureLoadBalancer | * | * | * | Health probes |

**Notes**:
- App Gateway does NOT communicate directly with Container Apps
- All traffic flows through APIM
- GatewayManager rule is mandatory for v2 SKU

### 2. APIM NSG (`nsg-apim`)

**Purpose**: Allows traffic from App Gateway and enables APIM management/monitoring

#### Inbound Rules

| Priority | Direction | Source | Destination | Ports | Protocol | Purpose |
|----------|-----------|--------|-------------|-------|----------|---------|
| 100 | Inbound | ApiManagement | VirtualNetwork | 3443 | TCP | Azure APIM management endpoint |
| 110 | Inbound | 10.0.5.0/24 | VirtualNetwork | 443 | TCP | HTTPS from App Gateway |

**Key Points**:
- APIM is Internal VNet mode - NO direct Internet access
- Only App Gateway subnet (10.0.5.0/24) can reach APIM on 443
- ApiManagement service tag required for Azure management plane

#### Outbound Rules

| Priority | Direction | Source | Destination | Ports | Protocol | Purpose |
|----------|-----------|--------|-------------|-------|----------|---------|
| 100 | Outbound | VirtualNetwork | Storage | 443 | TCP | APIM internal storage |
| 110 | Outbound | VirtualNetwork | Sql | 1433 | TCP | APIM analytics database |
| 120 | Outbound | VirtualNetwork | 10.0.0.0/23 | 443 | TCP | Route to Container Apps |

**Key Points**:
- APIM routes requests to Container Apps on port 443
- Container Apps subnet: 10.0.0.0/23
- HTTPS only (no HTTP)

### 3. Container Apps NSG (`nsg-container-apps`)

**Purpose**: Allows traffic only from APIM

| Priority | Direction | Source | Destination | Ports | Protocol | Purpose |
|----------|-----------|--------|-------------|-------|----------|---------|
| 100 | Inbound | 10.0.6.0/27 | * | 443 | TCP | HTTPS from APIM |

**Key Points**:
- Container Apps are fully private (internal load balancer)
- Only APIM subnet (10.0.6.0/27) can reach Container Apps
- No direct access from App Gateway or Internet
- Port 443 only (HTTPS)

## Traffic Flow Examples

### Example 1: Authenticated API Request

```
1. User → https://<app-gateway-ip>/api/hello
   - Internet → App Gateway (Public IP)
   - NSG: app_gateway_https_internet (Priority 110) ✅

2. App Gateway → APIM
   - 10.0.5.10 → 10.0.6.x:443
   - App Gateway NSG: Default allow outbound ✅
   - APIM NSG: apim_https_from_appgw (Priority 110) ✅

3. APIM validates JWT
   - Checks Azure AD token
   - Extracts user claims (email, groups, roles)
   - Adds headers: X-User-Email, X-User-Groups, etc.

4. APIM → Container Apps (API Service)
   - 10.0.6.x → 10.0.0.x:443
   - APIM NSG: apim_to_container_apps (Priority 120) ✅
   - Container Apps NSG: container_apps_from_apim (Priority 100) ✅

5. API Service processes request with user context
   - Response flows back through same path
```

### Example 2: Unauthenticated UI Request

```
1. User → https://<app-gateway-ip>/
   - Internet → App Gateway (Public IP)
   - NSG: app_gateway_https_internet (Priority 110) ✅

2. App Gateway → APIM
   - 10.0.5.10 → 10.0.6.x:443
   - APIM NSG: apim_https_from_appgw (Priority 110) ✅

3. APIM skips JWT validation (UI path)
   - No Authorization header required for / path
   - Routes to UI service

4. APIM → Container Apps (UI Service)
   - 10.0.6.x → 10.0.0.x:443
   - APIM NSG: apim_to_container_apps (Priority 120) ✅
   - Container Apps NSG: container_apps_from_apim (Priority 100) ✅

5. UI Service returns React application
```

### Example 3: Health Check

```
1. User → https://<app-gateway-ip>/api/health
   - Internet → App Gateway (Public IP)
   - NSG: app_gateway_https_internet (Priority 110) ✅

2. App Gateway → APIM
   - APIM NSG: apim_https_from_appgw (Priority 110) ✅

3. APIM skips JWT validation (health endpoint)
   - /api/health explicitly excluded from JWT validation

4. APIM → Container Apps (API Service)
   - APIM NSG: apim_to_container_apps (Priority 120) ✅
   - Container Apps NSG: container_apps_from_apim (Priority 100) ✅

5. API Service returns health status
```

## Security Principles

### 1. Defense in Depth
- **Layer 1**: App Gateway (public entry point, SSL termination)
- **Layer 2**: APIM (JWT validation, rate limiting, routing)
- **Layer 3**: Container Apps (internal load balancer, private endpoints)

### 2. Least Privilege
- App Gateway: Can only reach APIM (not Container Apps directly)
- APIM: Can only reach Container Apps (not public Internet)
- Container Apps: Can only be reached by APIM

### 3. Zero Trust
- All internal communication uses HTTPS (no HTTP)
- JWT validation at APIM layer for API endpoints
- No direct Internet access to APIM or Container Apps

## Common Troubleshooting

### Issue: 401 Unauthorized
**Symptom**: API requests fail with 401
**Check**:
1. JWT token present in Authorization header?
2. Token from correct Azure AD tenant?
3. Token audience matches App Registration Client ID?
4. Path requires JWT? (Check APIM policy exclusions)

### Issue: 502 Bad Gateway
**Symptom**: App Gateway returns 502
**Check**:
1. APIM healthy? Check `/status-0123456789abcdef`
2. NSG rule allows App Gateway → APIM on 443?
3. App Gateway backend pool has correct APIM private IP?
4. APIM gateway URL resolves correctly?

### Issue: 503 Service Unavailable
**Symptom**: APIM returns 503
**Check**:
1. Container Apps running? `az containerapp list`
2. NSG rule allows APIM → Container Apps on 443?
3. Container Apps ingress enabled?
4. Container Apps responding on internal FQDN?

### Issue: Timeout
**Symptom**: Requests timeout
**Check**:
1. All NSG rules in place?
2. Private DNS resolution working?
3. VNet DNS configured to use Private DNS Resolver?
4. Container Apps subnet delegation correct?

## Validation Commands

```bash
# Check App Gateway backend health
az network application-gateway show-backend-health \
  --resource-group rg-core-dev \
  --name appgw-core-dev

# Check APIM status
curl -k https://<apim-private-ip>/status-0123456789abcdef

# Check Container App status
az containerapp show \
  --resource-group rg-core-dev \
  --name ca-api-dev \
  --query "properties.runningStatus"

# Test NSG rules
az network watcher test-ip-flow \
  --resource-group rg-core-dev \
  --direction Inbound \
  --protocol TCP \
  --local 10.0.0.10:443 \
  --remote 10.0.6.10:443 \
  --vm <container-app-vm-id>
```

## Related Documentation

- [Application Gateway Configuration](./application-gateway.tf)
- [APIM Configuration](./api-management.tf)
- [Container Apps Configuration](./container-apps.tf)
- [Health Check Endpoints](../../HEALTH-CHECKS.md)
- [Authentication Setup](../../services/ui/AUTH-SETUP.md)
- [RBAC Endpoints](../../services/api/RBAC-ENDPOINTS.md)

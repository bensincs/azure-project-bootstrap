# Infrastructure Changes Summary

## Changes Made

### 1. Application Gateway - Made Private & HTTP-Only

**Removed:**
- Public IP resource (`azurerm_public_ip.app_gateway`)
- Domain name label configuration
- HTTPS listener (port 443)
- SSL certificate configuration
- HTTP to HTTPS redirect
- User-assigned managed identity for Key Vault access
- NSG rules for public Internet access (ports 80, 443)
- NSG rule for GatewayManager

**Changed:**
- Frontend IP configuration: Now uses **private IP** (dynamic allocation)
- NSG rule: Now allows traffic from **VirtualNetwork** instead of Internet
- Single HTTP listener on port 80 (internal only)
- Removed dependency on Key Vault certificate
- Removed dependency on auth service

**Result:**
- Application Gateway is now internal-only
- Only accessible from within the VNet
- No SSL/TLS termination (APIM handles this)
- HTTP-only communication between APIM and App Gateway

### 2. Auth Service - Removed

**Removed:**
- Container App resource (`azurerm_container_app.auth_service`)
- Backend pool (`auth-backend-pool`)
- Backend HTTP settings (`auth-http-settings`)
- Health probe (`auth-health-probe`)
- Path rule (`/api/auth/*`)
- Dependency in application-gateway.tf

**Reason:**
- APIM now handles JWT validation centrally
- No need for separate auth service
- Backend services receive user info via headers from APIM

### 3. API Management - Updated Backend

**Changed:**
- Backend URL: Changed from public IP to **private IP** of Application Gateway
- Protocol: Changed from HTTPS to **HTTP** (internal communication)
- `service_url`: Now uses `azurerm_application_gateway.core.frontend_ip_configuration[0].private_ip_address`
- `set-backend-service`: Updated to use private IP with HTTP

**Kept:**
- JWT validation policy (validates Azure AD tokens)
- User claims extraction and header forwarding
- CORS configuration
- Custom domain support (APIM still has SSL certificate)

## Architecture Changes

### Before:
```
Internet → Application Gateway (Public IP, HTTPS) → Container Apps
                     ↓
              Auth Service (JWT validation)
```

### After:
```
Internet → APIM (Public, HTTPS, JWT validation) → App Gateway (Private, HTTP) → Container Apps
```

## Security Improvements

1. **Reduced Attack Surface**: Application Gateway is no longer publicly accessible
2. **Centralized Authentication**: APIM validates all JWT tokens at the edge
3. **Simplified Architecture**: Removed redundant auth service
4. **Clear Separation**: APIM handles public SSL/auth, App Gateway handles internal routing

## DNS Configuration

**Important:** Since Application Gateway no longer has a public IP or DNS name:
- Point your custom domain (launch.crewdune.com) to **APIM**, not App Gateway
- APIM becomes the public-facing endpoint
- APIM forwards validated requests to App Gateway's private IP

## Breaking Changes

1. **Public IP removed**: Direct access to Application Gateway is no longer possible
2. **HTTPS removed from App Gateway**: Communication between APIM and App Gateway is HTTP
3. **Auth service removed**: `/api/auth/*` endpoints no longer exist
4. **Domain name label removed**: `*.cloudapp.azure.com` DNS name no longer available

## Required Actions

1. **Update DNS**: Point custom domain to APIM instead of old App Gateway public IP
2. **Deploy APIM**: Run `terraform apply` to create APIM (takes 30-45 minutes)
3. **Configure Azure AD**: Set up App Registration for JWT validation
4. **Update Variables**: Set `azure_tenant_id` and `azure_client_id` in `vars/dev.tfvars`
5. **Update Publisher Email**: Set `apim_publisher_email` in `vars/dev.tfvars`

## Testing

After deployment:

1. **Test APIM endpoint**: `https://apim-core-dev-xxxxx.azure-api.net`
2. **Verify JWT validation**: Call API with valid Azure AD token
3. **Check headers**: Backend services should receive X-User-* headers
4. **Test routing**: Verify UI, API, notification, and WebSocket endpoints work

## Rollback Plan

If issues occur:

1. Keep existing public Application Gateway resources
2. Don't apply these changes
3. Continue using Application Gateway as public entry point
4. Undo changes with `git restore`

## Files Modified

- `infra/core/application-gateway.tf` - Made private, removed SSL
- `infra/core/container-apps.tf` - Removed auth service
- `infra/core/api-management.tf` - Updated backend to private IP
- `infra/core/APIM-SETUP.md` - Updated documentation

## Next Steps

1. Review changes
2. Update variables in `vars/dev.tfvars`
3. Run `terraform plan` to preview changes
4. Run `terraform apply` when ready
5. Wait for APIM provisioning (30-45 minutes)
6. Update DNS to point to APIM
7. Test end-to-end authentication flow

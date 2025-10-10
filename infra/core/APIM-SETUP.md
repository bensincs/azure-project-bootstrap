# Azure API Management Setup

This document explains the Azure API Management (APIM) configuration for centralized JWT validation.

## Architecture

```
Internet → APIM (JWT Validation + SSL) → Application Gateway (Internal Routing) → Container Apps
```

**Key Points:**
- APIM is the public-facing entry point with SSL/TLS termination
- APIM validates JWT tokens from Azure AD before forwarding requests
- Application Gateway is **internal** (private IP only, HTTP-only)
- Application Gateway routes requests to Container Apps
- Backend services receive validated user information via HTTP headers

## What APIM Does

1. **JWT Validation**: Validates tokens against Azure AD's public keys (JWKS)
2. **Claims Extraction**: Extracts user claims from the validated token
3. **Header Forwarding**: Adds headers with user information:
   - `X-User-Email`: User's email address
   - `X-User-OID`: User's Object ID (unique identifier)
   - `X-User-Name`: User's display name
4. **CORS Handling**: Manages CORS for the API
5. **Backend Routing**: Forwards validated requests to Application Gateway

## Configuration Variables

Required variables in `variables.tf`:

- `apim_publisher_name`: Publisher name (default: "MyCompany")
- `apim_publisher_email`: Publisher email (required)
- `apim_sku_name`: SKU tier (default: "Developer_1")
- `apim_custom_domain_enabled`: Enable custom domain (default: false)
- `apim_custom_domain`: Custom domain name (optional)

Set in `vars/dev.tfvars`:

```hcl
apim_publisher_email = "your-email@example.com"
```

## JWT Validation Policy

The APIM policy validates JWT tokens with these settings:

- **Issuer**: `https://sts.windows.net/{tenant_id}/`
- **Audience**: Your Azure AD application client ID
- **Required Claims**: `aud`, `iss`, `iat`, `nbf`, `exp`
- **Public Keys**: Fetched from `https://login.microsoftonline.com/{tenant_id}/discovery/v2.0/keys`

## Azure AD App Registration

Before deploying, you need to:

1. Create an Azure AD App Registration
2. Note the **Tenant ID** and **Client ID**
3. Configure the app for your authentication needs
4. Set these values in `vars/dev.tfvars`:
   ```hcl
   azure_tenant_id = "your-tenant-id"
   azure_client_id = "your-client-id"
   ```

See `services/auth-service/AZURE_AD_SETUP.md` for detailed steps.

## Backend Services

Backend services receive these headers on every request:

```http
X-User-Email: user@example.com
X-User-OID: 00000000-0000-0000-0000-000000000000
X-User-Name: John Doe
```

Services can trust these headers because:
1. APIM validates the JWT before forwarding
2. APIM is the only public entry point
3. Application Gateway is private (not accessible from Internet)
4. Headers are set by APIM policy, not by client

### Example: Using Headers in Your Service

**Go:**
```go
email := r.Header.Get("X-User-Email")
oid := r.Header.Get("X-User-OID")
name := r.Header.Get("X-User-Name")
```

**Node.js:**
```javascript
const email = req.headers['x-user-email'];
const oid = req.headers['x-user-oid'];
const name = req.headers['x-user-name'];
```

**C#:**
```csharp
var email = Request.Headers["X-User-Email"];
var oid = Request.Headers["X-User-OID"];
var name = Request.Headers["X-User-Name"];
```

## Health Endpoint

The `/health` endpoint is excluded from JWT validation to allow health checks without authentication.

## Custom Domain (Optional)

To use APIM with your custom domain:

1. Set variables in `vars/dev.tfvars`:
   ```hcl
   apim_custom_domain_enabled = true
   apim_custom_domain = "launch.crewdune.com"
   ```

2. APIM will use the same SSL certificate from Key Vault as Application Gateway

3. Update DNS to point to APIM:
   - Get APIM gateway URL from Terraform output
   - Create CNAME or A record pointing to APIM

## Deployment

1. **Update email in vars/dev.tfvars**:
   ```hcl
   apim_publisher_email = "your-email@example.com"
   ```

2. **Set Azure AD values**:
   ```hcl
   azure_tenant_id = "your-tenant-id"
   azure_client_id = "your-client-id"
   ```

3. **Deploy**:
   ```bash
   cd infra/core
   terraform init
   terraform plan -var-file=vars/dev.tfvars
   terraform apply -var-file=vars/dev.tfvars
   ```

## Important Notes

- **APIM Deployment Time**: APIM can take 30-45 minutes to provision
- **SKU**: Developer_1 is for dev/test only (not production SLA)
- **Cost**: APIM has hourly charges even when not in use
- **Auth Service**: The separate auth service is no longer needed with APIM

## Testing

1. **Get Azure AD Token**:
   - Use Azure AD authentication in your app
   - Obtain JWT token for your client ID

2. **Call API through APIM**:
   ```bash
   curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
        https://apim-core-dev-xxxxx.azure-api.net/api/endpoint
   ```

3. **Verify Headers**:
   - Backend services should receive X-User-* headers
   - Check logs to confirm header values

## Troubleshooting

### JWT Validation Fails
- Check Azure AD Tenant ID and Client ID are correct
- Verify token audience matches client ID
- Ensure token is not expired
- Check APIM diagnostic logs

### Backend Not Receiving Headers
- Verify APIM policy is applied
- Check that request is going through APIM (not directly to App Gateway)
- Review APIM request logs

### Custom Domain Issues
- Verify SSL certificate includes custom domain in SAN list
- Check DNS points to APIM gateway
- Ensure Key Vault access policy is configured

## Resources

- Azure API Management: Official Azure service for API gateway
- JWT Validation Policy: https://learn.microsoft.com/azure/api-management/api-management-access-restriction-policies#ValidateJWT
- Azure AD App Registration: https://learn.microsoft.com/azure/active-directory/develop/quickstart-register-app

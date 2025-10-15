# API Management with OpenAPI

Each service owns its API definition and APIM policy.

## Architecture

```
services/
├── api/
│   ├── apim-policy.xml       # APIM policy for this service
│   ├── deploy.sh             # Deploys service + imports OpenAPI to APIM
│   └── Program.cs            # .NET API exposes /swagger/v1/swagger.json
├── notification-service/
│   ├── apim-policy.xml       # APIM policy for this service
│   ├── deploy.sh             # Deploys service + imports OpenAPI to APIM
│   └── src/index.ts          # Node.js API exposes /swagger.json
└── ui/
    ├── apim-policy.xml       # APIM policy for this service
    └── deploy.sh             # Deploys service + applies policy
```

## How It Works

### 1. Initial Infrastructure Deployment

```bash
cd infra/core
terraform apply -var-file=vars/dev.tfvars
```

This creates:
- ✅ APIM with 3 empty APIs (api-service, notification-service, ui-service)
- ✅ Container Apps (but not deployed yet)
- ✅ All networking, ACR, etc.

**Note:** APIs will be empty at this point - no operations defined yet!

### 2. Deploy Services

Each service deployment:
1. Builds Docker image
2. Pushes to ACR
3. Updates Container App
4. **Imports OpenAPI spec to APIM**
5. **Applies custom APIM policy**

```bash
# Deploy API service
cd services/api
./deploy.sh

# Deploy Notification service
cd services/notification-service
./deploy.sh

# Deploy UI service
cd services/ui
./deploy.sh
```

### 3. How OpenAPI Import Works

**API Service (C# .NET):**
- Exposes: `https://{fqdn}/swagger/v1/swagger.json`
- Deploy script imports this into APIM at path `/api`
- All endpoints defined in C# code automatically appear in APIM

**Notification Service (Node.js):**
- Exposes: `https://{fqdn}/swagger.json`
- Deploy script imports this into APIM at path `/notify`
- Uses JSDoc comments to generate OpenAPI spec

**UI Service:**
- No OpenAPI (it's a static SPA)
- Just applies routing policy

### 4. APIM Policies

Each service has its own `apim-policy.xml` that defines:

**API Service (`services/api/apim-policy.xml`):**
- JWT validation for authenticated endpoints
- User claim extraction (email, oid, name, groups, roles)
- Health endpoint exemption
- Backend routing

**Notification Service (`services/notification-service/apim-policy.xml`):**
- JWT validation for WebSocket connections
- User claim extraction (email, oid)
- Health endpoint exemption
- WebSocket support

**UI Service (`services/ui/apim-policy.xml`):**
- Simple passthrough
- No authentication (public SPA)

### 5. Policy Template Variables

Policies use template variables replaced during deployment:

```xml
<set-backend-service base-url="${BACKEND_URL}" />
<openid-config url="https://login.microsoftonline.com/${TENANT_ID}/v2.0/.well-known/openid-configuration" />
<audience>${CLIENT_ID}</audience>
```

Deploy scripts automatically substitute:
- `${BACKEND_URL}` - Container App FQDN
- `${TENANT_ID}` - Azure AD Tenant ID
- `${CLIENT_ID}` - Azure AD App Registration Client ID

## Benefits

✅ **Service Ownership** - Each service owns its API contract and policy
✅ **Self-Documenting** - OpenAPI generated from code
✅ **Auto-Sync** - Every deployment updates APIM
✅ **No Terraform Drift** - Policies managed in service repos, not Terraform
✅ **Testable** - Can test OpenAPI spec locally before deploying

## Development Workflow

### Adding a New API Endpoint

1. **Add endpoint to service code:**

```csharp
// In Program.cs
app.MapGet("/api/users/{id}", (int id) =>
    Results.Ok(new { id, name = "User" }))
    .WithName("GetUser")
    .WithOpenApi();
```

2. **Deploy service:**

```bash
cd services/api
./deploy.sh
```

3. **Done!** The new endpoint is now:
   - ✅ In your service
   - ✅ In the OpenAPI spec
   - ✅ In APIM with proper policy
   - ✅ Documented in Swagger UI

### Modifying APIM Policy

1. **Edit the policy file:**

```bash
vim services/api/apim-policy.xml
```

2. **Deploy to apply changes:**

```bash
cd services/api
./deploy.sh
```

### Testing OpenAPI Spec Locally

```bash
# API Service
curl http://localhost:8080/swagger/v1/swagger.json | jq

# Notification Service
curl http://localhost:3001/swagger.json | jq
```

## Troubleshooting

### OpenAPI import failed

**Symptom:** Deploy script shows import error

**Fix:** Check that service is healthy and /swagger endpoint works:
```bash
curl https://{service-fqdn}/swagger/v1/swagger.json
```

### Policy not applied

**Symptom:** JWT validation not working

**Fix:** Check policy was applied:
```bash
az apim api policy show \
  --resource-group rg-core-dev \
  --service-name {apim-name} \
  --api-id api-service
```

### Manual policy update

If deploy script fails, update policy manually:

```bash
az apim api policy create \
  --resource-group rg-core-dev \
  --service-name {apim-name} \
  --api-id api-service \
  --xml-content @services/api/apim-policy.xml
```

## References

- [APIM Policy Reference](https://learn.microsoft.com/en-us/azure/api-management/api-management-policies)
- [OpenAPI Specification](https://swagger.io/specification/)
- [.NET Minimal API OpenAPI](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/openapi)
- [swagger-jsdoc (Node.js)](https://github.com/Surnet/swagger-jsdoc)

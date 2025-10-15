# APIM Policy Management - Service-Owned Approach

## Summary of Changes

We've refactored APIM policy management from Terraform-managed to service-owned deployment.

## Architecture

### Before
```
infra/core/
├── api-management.tf
├── apim-policy-api.xml         ❌ Centralized in Terraform
├── apim-policy-notification.xml ❌ Centralized in Terraform
└── apim-policy-ui.xml           ❌ Centralized in Terraform
```

### After
```
services/
├── api/
│   ├── apim-policy.xml          ✅ Service-owned
│   └── deploy.sh                ✅ Imports OpenAPI + applies policy
├── notification-service/
│   ├── apim-policy.xml          ✅ Service-owned
│   └── deploy.sh                ✅ Imports OpenAPI + applies policy
└── ui/
    ├── apim-policy.xml          ✅ Service-owned
    └── deploy.sh                ✅ Applies policy (no OpenAPI)
```

## What Was Changed

### 1. Removed from Terraform (`infra/core/api-management.tf`)

**Deleted:**
- ❌ `azurerm_api_management_api_policy.api_service`
- ❌ `azurerm_api_management_api_policy.notification_service`
- ❌ `azurerm_api_management_api_policy.ui_service`
- ❌ All XML policy files from `infra/core/`

**Added:**
- ✅ `azurerm_api_management_api_operation.ui_wildcard` - Wildcard route for SPA
- ✅ Comment explaining policies are managed by deploy scripts

### 2. Terraform Now Creates

Terraform creates **empty API shells**:
- `api-service` API at path `/api` (no operations initially)
- `notification-service` API at path `/notify` (no operations initially)
- `ui-service` API at path `` (root) with `/*` wildcard operation

### 3. Deploy Scripts Now Handle

Each `deploy.sh` now:
1. Builds & pushes Docker image
2. Updates Container App
3. **Imports OpenAPI spec** (API & Notification services only)
4. **Applies custom APIM policy**

## Deployment Flow

### Initial Setup (Infrastructure Only)

```bash
cd infra/core
terraform apply -var-file=vars/dev.tfvars
```

**Result:**
- ✅ APIM created with 3 empty APIs
- ✅ Container Apps exist but may not be deployed
- ⚠️  No operations defined yet (except UI wildcard)
- ⚠️  No policies applied yet

### Service Deployment (Populates APIs)

```bash
# Deploy each service
cd services/api && ./deploy.sh
cd ../notification-service && ./deploy.sh
cd ../ui && ./deploy.sh
```

**Each service deployment:**
1. ✅ Deploys container
2. ✅ Imports OpenAPI spec (if applicable)
3. ✅ Applies APIM policy
4. ✅ Makes API fully functional

## Benefits

### ✅ Service Ownership
- Each service owns its API contract and policy
- Changes to policy deploy with the service
- No Terraform apply needed for policy updates

### ✅ No Terraform Drift
- Policies not managed by Terraform
- Won't show as "changed" on every `terraform plan`
- `lifecycle { ignore_changes = [import] }` prevents OpenAPI drift

### ✅ Synchronized Deployments
- Policy always matches deployed service
- OpenAPI spec updated automatically
- Single `./deploy.sh` does everything

### ✅ Testable
- Can test policy changes without Terraform
- Can run OpenAPI import independently
- Faster iteration cycle

## How Policies Are Applied

### API Service (`services/api/deploy.sh`)

```bash
# Template substitution
POLICY_CONTENT="${POLICY_CONTENT//\$\{BACKEND_URL\}/https://$FQDN}"
POLICY_CONTENT="${POLICY_CONTENT//\$\{TENANT_ID\}/$TENANT_ID}"
POLICY_CONTENT="${POLICY_CONTENT//\$\{CLIENT_ID\}/$CLIENT_ID}"

# Import OpenAPI
az apim api import \
  --api-id "api-service" \
  --specification-url "https://$FQDN/swagger/v1/swagger.json"

# Apply policy
az apim api policy create \
  --api-id "api-service" \
  --xml-content "@$TEMP_POLICY"
```

### Notification Service (`services/notification-service/deploy.sh`)

Same as API service, but:
- Uses `/swagger.json` endpoint
- Includes `wss` protocol for WebSocket

### UI Service (`services/ui/deploy.sh`)

```bash
# No OpenAPI import (static SPA)
# Just applies policy for routing

az apim api policy create \
  --api-id "ui-service" \
  --xml-content "@$TEMP_POLICY"
```

## Policy Template Variables

Each `apim-policy.xml` uses template variables:

```xml
<set-backend-service base-url="${BACKEND_URL}" />
<openid-config url="https://login.microsoftonline.com/${TENANT_ID}/v2.0/.well-known/openid-configuration" />
<audience>${CLIENT_ID}</audience>
```

Deploy scripts substitute:
- `${BACKEND_URL}` → Container App FQDN
- `${TENANT_ID}` → Azure AD Tenant ID
- `${CLIENT_ID}` → App Registration Client ID

## Terraform Outputs Required

Deploy scripts need these outputs from Terraform:

```hcl
output "apim_name" { }
output "tenant_id" { }
output "client_id" { }
output "api_service_name" { }
output "notification_service_name" { }
output "ui_service_name" { }
output "api_service_fqdn" { }
output "notification_service_fqdn" { }
output "ui_service_fqdn" { }
```

## Troubleshooting

### Policy not applied

**Check if policy exists:**
```bash
az apim api policy show \
  --resource-group rg-core-dev \
  --service-name <apim-name> \
  --api-id api-service
```

**Manually apply policy:**
```bash
cd services/api
az apim api policy create \
  --resource-group rg-core-dev \
  --service-name <apim-name> \
  --api-id api-service \
  --xml-content @apim-policy.xml
```

### OpenAPI import failed

**Test OpenAPI endpoint directly:**
```bash
curl https://<service-fqdn>/swagger/v1/swagger.json | jq
```

**Manually import OpenAPI:**
```bash
az apim api import \
  --resource-group rg-core-dev \
  --service-name <apim-name> \
  --api-id api-service \
  --specification-url https://<service-fqdn>/swagger/v1/swagger.json \
  --specification-format OpenApiJson
```

### UI wildcard not working

The wildcard operation is managed by Terraform:

```bash
cd infra/core
terraform apply -var-file=vars/dev.tfvars
```

## Migration Path (If Reverting)

If you need to move policies back to Terraform:

1. Remove policy application from deploy scripts
2. Move `apim-policy.xml` files back to `infra/core/`
3. Add `azurerm_api_management_api_policy` resources
4. Run `terraform apply`

**Note:** Not recommended - service-owned approach is cleaner!

## References

- [APIM Policy Reference](https://learn.microsoft.com/en-us/azure/api-management/api-management-policies)
- [APIM CLI Reference](https://learn.microsoft.com/en-us/cli/azure/apim/api/policy)
- [OpenAPI Import](https://learn.microsoft.com/en-us/azure/api-management/import-api-from-oas)

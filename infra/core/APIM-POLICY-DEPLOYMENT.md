# APIM Policy Deployment Guide

## Issue

The APIM policy resource (`azurerm_api_management_api_policy`) fails validation during initial infrastructure deployment with error:
```
ValidationError: One or more fields contain incorrect values
```

This occurs because Azure validates the policy XML at the time of resource creation, but the policy references Container App FQDNs that may not be fully propagated or the policy XML has syntax issues that Azure rejects.

## Workaround: Two-Step Deployment

### Step 1: Deploy Infrastructure Without Policy

The policy resource is currently commented out in `api-management.tf` (lines 45-63).

Run your Terraform deployment:
```bash
terraform apply -var-file=vars/dev.tfvars
```

This will deploy:
- ✅ APIM instance
- ✅ APIM API resource
- ✅ Container Apps (api, ui, notification)
- ✅ All networking resources
- ❌ APIM policy (commented out)

### Step 2: Apply Policy After Infrastructure Exists

Once the infrastructure is successfully deployed:

1. **Uncomment the policy resource** in `api-management.tf` (remove the `#` comments from lines 45-63)

2. **Choose which policy to use:**
   - `apim-policy.xml` - Simple routing policy (no JWT validation)
   - `apim-policy-full.xml` - Full policy with JWT validation and RBAC headers

3. **Update the templatefile path** if using the full policy:
   ```terraform
   xml_content = templatefile("${path.module}/apim-policy-full.xml", {
   ```

4. **Run Terraform apply again:**
   ```bash
   terraform apply -var-file=vars/dev.tfvars
   ```

## Policy Files

### apim-policy.xml (Simple)
- ✅ Basic routing to Container Apps based on path
- ✅ CORS configuration
- ✅ Forwards original host header
- ❌ No JWT validation
- ❌ No RBAC headers

**Use this if:** You want to get the infrastructure working first and add authentication later.

### apim-policy-full.xml (Complete)
- ✅ Conditional JWT validation (public UI + protected API pattern)
- ✅ Health endpoints excluded from JWT validation
- ✅ RBAC headers (X-User-Groups, X-User-Roles, X-User-Email, etc.)
- ✅ Path-based routing to Container Apps
- ✅ CORS configuration

**Use this if:** You need the full authentication and RBAC functionality.

## Alternative: Manual Policy Update

You can also apply the policy manually via Azure Portal or Azure CLI after infrastructure deployment:

### Via Azure Portal:
1. Navigate to API Management → APIs → main-api → Design → All operations
2. Click "Add policy" in the Inbound processing section
3. Paste the contents of `apim-policy-full.xml` (with placeholders replaced)
4. Save

### Via Azure CLI:
```bash
# Get the policy XML with replaced values
TENANT_ID=$(az account show --query tenantId -o tsv)
CLIENT_ID=$(az ad app list --display-name "your-app-name" --query "[0].appId" -o tsv)
API_FQDN=$(az containerapp show -n api-service-dev -g rg-core-dev --query properties.configuration.ingress.fqdn -o tsv)
# ... etc

# Apply via az cli
az apim api policy create \
  --resource-group rg-core-dev \
  --service-name apim-core-dev-xxxxx \
  --api-id main-api \
  --xml-content "@apim-policy-full.xml"
```

## Troubleshooting

If policy validation still fails after infrastructure exists:

1. **Check Container App FQDNs are valid:**
   ```bash
   az containerapp show -n api-service-dev -g rg-core-dev --query properties.configuration.ingress.fqdn
   ```

2. **Validate XML syntax:**
   - Ensure no `&quot;` entities in `@()` expressions (use regular quotes `"`)
   - Check all `<choose>/<when>/<otherwise>` blocks are properly closed
   - Verify all variable placeholders are replaced: `{{TENANT_ID}}`, `{{CLIENT_ID}}`, etc.

3. **Test with minimal policy first:**
   Start with `apim-policy.xml` (no JWT validation), then gradually add complexity.

## Future Improvement

Consider using a `null_resource` with `local-exec` provisioner to apply the policy via Azure CLI after Container Apps are created, avoiding Terraform validation issues.

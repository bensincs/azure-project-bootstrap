# Removed API Key and API Version Configuration

## Summary

Removed `azure_openai_api_key` and `azure_openai_api_version` from all configuration files since the service now uses **Azure CLI authentication** instead of API keys.

## Files Modified

### 1. `/services/ai-chat/app/config.py`
- ❌ Removed `azure_openai_api_key: str = ""`
- ❌ Removed `azure_openai_api_version: str = "2024-02-15-preview"`
- ✅ Kept `azure_openai_endpoint` and `azure_openai_deployment_name`

### 2. `/services/ai-chat/.env`
- ❌ Removed `AZURE_OPENAI_API_KEY`
- ❌ Removed `AZURE_OPENAI_API_VERSION`

### 3. `/services/ai-chat/.env.example`
- ❌ Removed `AZURE_OPENAI_API_KEY`
- ❌ Removed `AZURE_OPENAI_API_VERSION`

### 4. `/services/ai-chat/AGENT-FRAMEWORK-SETUP.md`
- ❌ Removed `AZURE_OPENAI_API_KEY` from environment variable examples
- ❌ Removed `AZURE_OPENAI_API_VERSION` from environment variable examples

### 5. `/AI-CHAT-DEPLOYMENT-CHECKLIST.md`
- ❌ Removed "API key from Azure OpenAI" prerequisite
- ✅ Added "Azure CLI installed and logged in" prerequisite
- ✅ Added "Appropriate RBAC role assigned" prerequisite
- ❌ Removed `AZURE_OPENAI_API_KEY` from configuration checklist

### 6. `/infra/core/container-apps.tf`
- ❌ Removed `AZURE_OPENAI_API_KEY` environment variable
- ❌ Removed `AZURE_OPENAI_API_VERSION` environment variable

## What You Need Now

Only 2 environment variables are required:

```bash
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4o-mini
```

## Authentication

The service now uses **Azure CLI credentials** via `AzureCliCredential`:

1. **Login**: `az login`
2. **Ensure RBAC role**: Your account needs `Cognitive Services OpenAI User` or `Cognitive Services OpenAI Contributor` on the Azure OpenAI resource

## Benefits

✅ **More secure**: No API keys stored in configuration  
✅ **Better for production**: Can use Managed Identity in Azure  
✅ **Simpler configuration**: Fewer environment variables to manage  
✅ **Audit trail**: Azure AD provides better audit logs  

## Production Deployment

For Container Apps deployment, you'll need to configure Managed Identity:

1. Enable system-assigned managed identity on the container app
2. Assign the managed identity the `Cognitive Services OpenAI User` role on the Azure OpenAI resource
3. The `AzureCliCredential` will automatically fall back to managed identity in Azure

No code changes needed - `AzureCliCredential` automatically works with managed identity!

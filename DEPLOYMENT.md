# Deployment with Environment Variables

## Overview

Both the API and UI services automatically read environment variables from their `.env` files during deployment and set them in the Azure Container App configuration.

## How It Works

### API Service (`services/api/deploy.sh`)

1. Reads the `.env` file in the API directory
2. Parses each line (skipping comments and empty lines)
3. Converts to `--set-env-vars` format for Azure CLI
4. Updates the Container App with the new environment variables

### UI Service (`services/ui/deploy.sh`)

1. Reads the `.env` file in the UI directory
2. Parses each line (skipping comments and empty lines)
3. Converts to `--set-env-vars` format for Azure CLI
4. Updates the Container App with the new environment variables

## Deployment Steps

### 1. Configure Environment Variables

**API Service:**
```bash
cd services/api
cp .env.example .env
# Edit .env with your values
vim .env
```

**UI Service:**
```bash
cd services/ui
cp .env.example .env
# Edit .env with your values
vim .env
```

### 2. Deploy

**API Service:**
```bash
cd services/api
./deploy.sh dev
```

**UI Service:**
```bash
cd services/ui
./deploy.sh
```

## What Gets Deployed

### API Environment Variables

From `services/api/.env`:
- `PORT` - HTTP server port
- `AZURE_TENANT_ID` - Azure AD tenant ID
- `AZURE_CLIENT_ID` - Azure AD application client ID
- `SKIP_TOKEN_VERIFICATION` - Disable JWT verification (dev only)

### UI Environment Variables

From `services/ui/.env`:
- `VITE_API_URL` - Backend API URL
- `VITE_WS_URL` - WebSocket URL for real-time chat
- `VITE_AUTH_CLIENT_ID` - Azure AD client ID
- `VITE_AUTH_TENANT_ID` - Azure AD tenant ID

## Important Notes

### Security

⚠️ **Never commit `.env` files to git!** They are in `.gitignore` by default.

✅ Use `.env.example` as a template
✅ Store production secrets in Azure Key Vault
✅ Use Azure Container App secrets for sensitive values

### Environment Variable Precedence

Azure Container Apps use environment variables in this order:
1. Container App environment variables (set by deploy script)
2. Container App secrets
3. System environment variables

### Verifying Deployment

After deployment, you can verify the environment variables are set:

```bash
# For API
az containerapp show \
  --name ca-core-api-service-dev \
  --resource-group <resource-group> \
  --query "properties.template.containers[0].env"

# For UI
az containerapp show \
  --name ca-core-ui-service-dev \
  --resource-group <resource-group> \
  --query "properties.template.containers[0].env"
```

## Troubleshooting

### Missing Environment Variables

If environment variables are not being set:

1. **Check .env file exists:**
   ```bash
   ls -la services/api/.env
   ls -la services/ui/.env
   ```

2. **Check .env format:**
   - No spaces around `=`
   - No quotes (unless needed)
   - Unix line endings (LF, not CRLF)

3. **Check deploy script output:**
   - Should show "✅ Loaded environment variables from .env"
   - Should list the variable names

### Application Not Reading Variables

If the application doesn't see the variables:

1. **Check Container App logs:**
   ```bash
   az containerapp logs show \
     --name ca-core-api-service-dev \
     --resource-group <resource-group> \
     --follow
   ```

2. **Verify in Azure Portal:**
   - Navigate to Container App → Configuration → Environment variables

3. **Restart the Container App:**
   ```bash
   az containerapp revision restart \
     --name ca-core-api-service-dev \
     --resource-group <resource-group>
   ```

## Best Practices

### Development
- Use `.env` files locally
- Keep `.env.example` updated with all required variables
- Document what each variable does

### Staging/Production
- Use Azure Key Vault for secrets
- Set environment variables through Azure Portal or Terraform
- Use different values per environment
- Enable Container App secrets for sensitive data

### CI/CD
- Store secrets in GitHub Secrets
- Use deploy script with environment variables from secrets
- Never log sensitive values in CI/CD output

## Example: Adding a New Environment Variable

### 1. Add to .env.example
```bash
# API Service Configuration
NEW_API_SETTING=default-value
```

### 2. Add to your local .env
```bash
NEW_API_SETTING=my-actual-value
```

### 3. Update application code
```go
// config.go
newSetting := viper.GetString("NEW_API_SETTING")
```

### 4. Deploy
```bash
./deploy.sh dev
```

The new environment variable will automatically be picked up and deployed! ✅

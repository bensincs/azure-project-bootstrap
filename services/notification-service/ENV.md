# API Environment Configuration

## Environment Files

### `.env` (Local Development)
- Used when running `yarn dev`
- Not committed to git
- Contains local development settings

```env
PORT=3001
NODE_ENV=development
```

### `.env.production` (Deployment)
- Used when running `yarn deploy`
- **Committed to git**
- Contains production configuration
- Automatically applied to Azure Container App

```env
PORT=3001
NODE_ENV=production
LOG_LEVEL=info
```

### `.env.local` or `.env.production.local` (Local Overrides)
- Not committed to git
- Overrides values for local testing
- Useful for testing production config locally

## How It Works

### Local Development

When you run `yarn dev`, Node.js loads environment variables from `.env`:

```bash
yarn dev  # Uses .env
```

### Production Deployment

When you run `yarn deploy`, the script:

1. Reads `.env.production`
2. Parses each `KEY=VALUE` pair
3. Passes them to `az containerapp update --set-env-vars`
4. Azure Container App applies the variables

Example output:
```
📝 Loading environment variables from .env.production...
  ✓ PORT
  ✓ NODE_ENV
  ✓ LOG_LEVEL
🚀 Updating Container App with new image...
```

## Adding Environment Variables

1. **Edit `.env.production`:**
```env
PORT=3001
NODE_ENV=production
NEW_FEATURE_FLAG=true
API_TIMEOUT=30000
```

2. **Deploy:**
```bash
yarn deploy
```

The variables are automatically applied during deployment.

## Best Practices

### ✅ DO commit to `.env.production`:
- Port numbers
- Node environment (production/development)
- Feature flags
- Public API URLs
- Log levels
- Connection pool sizes
- Timeout values

### ❌ DON'T commit to `.env.production`:
- Database passwords
- API keys
- Secrets
- Access tokens
- Private keys

For secrets, use:
- **Azure Key Vault** integration
- **Container App secrets** (separate from env vars)
- **Managed identities**

## Secrets vs Environment Variables

### Environment Variables (`.env.production`)
- Public configuration
- Visible in Azure Portal
- Version controlled in git
- Easy to update

### Secrets (Container App Secrets)
- Sensitive data
- Encrypted at rest
- Not visible in git
- Referenced from Key Vault

**Example using secrets:**

```bash
# Add a secret to Container App
az containerapp secret set \
  --name <app-name> \
  --resource-group <rg> \
  --secrets "db-password=<secret-value>"

# Reference it as env var
az containerapp update \
  --name <app-name> \
  --resource-group <rg> \
  --set-env-vars "DATABASE_PASSWORD=secretref:db-password"
```

## Viewing Current Configuration

```bash
# Get all environment variables
az containerapp show \
  --name <app-name> \
  --resource-group <rg> \
  --query "properties.template.containers[0].env" \
  -o table

# Get specific variable
az containerapp show \
  --name <app-name> \
  --resource-group <rg> \
  --query "properties.template.containers[0].env[?name=='PORT'].value" \
  -o tsv
```

## Troubleshooting

### Variables not updating

1. Check `.env.production` format (no quotes around values)
2. Ensure `yarn deploy` is run from the `api` directory
3. Verify the output shows "Loading environment variables"

### Variables not loading locally

1. Make sure `.env` exists in the `api` directory
2. Restart the dev server: `yarn dev`
3. Check for syntax errors in `.env` file

### Wrong values in production

1. Check what's actually deployed:
```bash
az containerapp show --name <app> --resource-group <rg> \
  --query "properties.template.containers[0].env"
```

2. Compare with `.env.production`
3. Redeploy: `yarn deploy`

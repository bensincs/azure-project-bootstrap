# Deployment Guide

This guide covers deploying your application stack (infrastructure, notification service, and UI) to Azure.

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- Docker installed (for notification service deployment)
- Terraform installed
- Node.js and Yarn installed

## Initial Setup (One-time)

### 1. Bootstrap Terraform State

```bash
cd infra/bootstrap
terraform init
terraform apply
```

This creates the shared remote state storage that all environments use.

### 2. Initialize Your Environment

Choose your environment (dev, staging, or prod) and initialize:

```bash
cd ../core
terraform init -backend-config=backends/backend-dev.hcl
terraform apply -var-file=vars/dev.tfvars
```

This creates:
- Resource group
- Storage account with static website hosting
- Azure Container Registry
- Azure Container Apps Environment (with Log Analytics)
- Azure Container App for the API (with placeholder image initially)
- All necessary RBAC permissions

**Note:** The container app starts with a placeholder image. You'll deploy your actual API in the next step.

### 3. Deploy the Notification Service and UI

Now deploy your applications:

```bash
# Deploy the Notification Service
cd ../services/notification-service
yarn deploy

# Deploy the UI
cd ../ui
yarn deploy
```

Your stack is now fully deployed! 🎉

## Deploying Updates

After the initial setup, you can deploy updates independently:

### Deploy the Notification Service

From the `services/notification-service` folder:

```bash
yarn deploy
```

Or manually:

```bash
./deploy.sh
```

This will:
1. Load environment variables from `services/notification-service/.env`
2. Build the Docker image
3. Tag with timestamp (e.g., `20251002-143022`) and `latest`
4. Push both tags to Azure Container Registry
5. Update the container app with the timestamped version and env vars (rolling deployment, zero downtime!)
6. Show you the API URLs

**No Terraform reapply needed!** 🎉

Container Apps automatically handle rolling updates, so there's no downtime during deployment. Each deployment is versioned with a timestamp for easy tracking and rollback.

### Managing Environment Variables

Edit `services/notification-service/.env` to add or update environment variables:

```env
PORT=3001
NODE_ENV=production
```

Run `yarn deploy` and they'll be automatically applied. See `services/notification-service/ENV.md` for details.

### Deploy the UI

From the `services/ui` folder:

```bash
yarn deploy
```

Or manually:

```bash
./deploy.sh
```

This will:
1. Get the WebSocket URL from Terraform outputs
2. Build the React app
3. Upload to Azure Storage static website
4. Show you the website URL

**No Terraform reapply needed!** 🎉

The UI will automatically connect to the correct API environment based on the Terraform state.

## Environment Management

### Switching Environments

To work with a different environment, re-initialize Terraform with the appropriate backend:

```bash
cd infra/core
terraform init -backend-config=backends/backend-staging.hcl -reconfigure
```

Then deploy as usual. The deployment scripts will automatically use the current Terraform environment.

### Get Current Environment URLs

```bash
cd infra/core
terraform output website_url
terraform output notification_api_url
terraform output notification_api_websocket_url
```

## Local Development

### Run the Notification Service locally

```bash
cd services/notification-service
yarn install
yarn dev
```

API will be available at `http://localhost:3001`

### Run the UI locally

```bash
cd services/ui
yarn install
yarn dev
```

UI will be available at `http://localhost:5173`

The UI will connect to the local API automatically via the `.env` file.

## Testing the Notification System

### Send a test notification (local):

```bash
curl -X POST http://localhost:3001/api/notifications \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Test notification!",
    "type": "success",
    "title": "Hello"
  }'
```

### Send a test notification (production):

```bash
API_URL=$(cd infra/core && terraform output -raw notification_api_url)

curl -X POST $API_URL/api/notifications \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Production notification!",
    "type": "info",
    "title": "From Production"
  }'
```

## Workflow Summary

```
┌─────────────────────────────────────────────────────────┐
│  Initial Setup (Once per environment)                   │
│  1. terraform init -backend-config=backends/backend.hcl │
│  2. terraform apply -var-file=vars/env.tfvars          │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  Deploy Updates (As often as needed)                    │
│  • cd services/notification-service && yarn deploy      │
│  • cd services/ui && yarn deploy                        │
│  • No Terraform needed!                                 │
└─────────────────────────────────────────────────────────┘
```

## Troubleshooting

### "Resource not found" error

Make sure Terraform has been initialized and applied for the current environment:

```bash
cd infra/core
terraform init -backend-config=backends/backend-dev.hcl
terraform plan  # Check what exists
```

### "Permission denied" error

Ensure you're logged in to Azure with the correct account:

```bash
az login
az account show
```

### Container not updating

Container Apps should update automatically with `yarn deploy`. If you're experiencing issues, check the revision status:

```bash
RESOURCE_GROUP=$(cd infra/core && terraform output -raw resource_group_name)
CONTAINER_APP=$(cd infra/core && terraform output -raw container_app_name)
az containerapp revision list --name $CONTAINER_APP --resource-group $RESOURCE_GROUP --query "[].{Name:name, Active:properties.active, Created:properties.createdTime}" -o table
```

### UI not updating

Clear the browser cache or do a hard refresh (Cmd+Shift+R on Mac, Ctrl+Shift+R on Windows).

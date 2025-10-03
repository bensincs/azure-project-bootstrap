# Deployment Guide

This guide covers deploying your application stack to Azure, including:
- **Infrastructure** (Terraform)
- **UI** (React/Vite static website)
- **Notification Service** (Node.js/WebSocket)
- **API Service** (.NET 9 Web API)
- **Azure Front Door** (Global CDN & routing)

## Architecture Overview

```
Azure Front Door (Global Entry Point)
├── /* → Static Website (Azure Storage)
├── /api/* → .NET API Service (Container App)
└── /notifications/*, /ws → Notification Service (Container App)
```

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- Docker installed (for container deployments)
- Terraform installed (>= 1.13.0)
- .NET 9 SDK installed (for API development)
- Node.js and npm/yarn installed

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
- **Resource group** - Container for all resources
- **Storage account** - Static website hosting for UI
- **Container Registry** - Docker image storage
- **Log Analytics Workspace** - Logging and monitoring
- **Container Apps Environment** - Managed Kubernetes-like environment
- **Container Apps**:
  - Notification Service (WebSocket/REST API)
  - API Service (.NET 9 Web API)
- **Azure Front Door** - Global CDN with routes:
  - `/*` → Static website
  - `/api/*` → .NET API
  - `/notifications/*`, `/ws` → Notification service
- **RBAC permissions** - Automated role assignments

**Note:** Container apps start with placeholder images. You'll deploy your actual services in the next step.

### 3. Deploy All Services

Now deploy your applications:

```bash
# Deploy the .NET API
cd ../../services/api
./deploy.sh dev

# Deploy the Notification Service
cd ../notification-service
./deploy.sh dev

# Deploy the UI
cd ../ui
./deploy.sh dev
```

Your stack is now fully deployed! 🎉

### 4. Get Your URLs

```bash
cd ../../infra/core
terraform output frontdoor_endpoint_url    # Main application URL
terraform output api_service_url           # Direct API URL
terraform output notification_api_url      # Direct notification URL
terraform output website_url               # Direct storage URL
```

## Deploying Updates

After the initial setup, you can deploy updates independently:

### Deploy the .NET API Service

From the `services/api` folder:

```bash
./deploy.sh dev
```

This will:
1. Get infrastructure details from Terraform outputs
2. Build the Docker image (multi-stage .NET 9 build)
3. Tag with timestamp and `latest`
4. Push to Azure Container Registry
5. Update the container app with the new image
6. Show you the API URLs

**Endpoints available:**
- `GET /` - Service info
- `GET /health` - Health check
- `GET /api/hello` - Hello world
- `GET /api/hello/{name}` - Personalized greeting
- `GET /api/config` - Configuration info
- `GET /swagger` - Swagger UI (development only)

### Deploy the Notification Service

From the `services/notification-service` folder:

```bash
./deploy.sh dev
```

Or with npm/yarn:

```bash
yarn deploy
```

This will:
1. Load environment variables from `.env`
2. Build the Docker image
3. Tag with timestamp and `latest`
4. Push to Azure Container Registry
5. Update the container app with rolling deployment
6. Show you the WebSocket and API URLs

**No Terraform reapply needed!** 🎉

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
./deploy.sh dev
```

Or with npm/yarn:

```bash
yarn deploy
```

This will:
1. Get URLs from Terraform outputs (Front Door, WebSocket, API)
2. Build the React app with Vite
3. Upload to Azure Storage static website
4. Show you the website URL

**No Terraform reapply needed!** 🎉

The UI will automatically connect to the correct services via Azure Front Door.

## Infrastructure Files

The infrastructure is organized into modular files:

```
infra/core/
├── provider.tf           # Terraform & provider config
├── resource-group.tf     # Resource group & random suffix
├── storage.tf            # Storage account & static website
├── container-registry.tf # Azure Container Registry
├── container-apps.tf     # Container Apps (API & Notification)
├── front-door.tf        # Azure Front Door routing
├── variables.tf          # Input variables
├── outputs.tf            # Output values
├── backends/             # Backend configs per environment
│   └── backend-dev.hcl
└── vars/                 # Variable values per environment
    └── dev.tfvars
```

### Making Infrastructure Changes

Edit the relevant `.tf` file and apply:

```bash
cd infra/core
terraform plan -var-file=vars/dev.tfvars
terraform apply -var-file=vars/dev.tfvars
```

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

# Front Door (main entry point)
terraform output frontdoor_endpoint_url

# Direct service URLs
terraform output api_service_url
terraform output notification_api_url
terraform output website_url

# WebSocket URL
terraform output notification_api_websocket_url
```

## Local Development

### Run the .NET API locally

```bash
cd services/api
dotnet restore
dotnet run
```

API will be available at `http://localhost:5000`
- Swagger UI: `http://localhost:5000/swagger`

### Run the Notification Service locally

```bash
cd services/notification-service
yarn install
yarn dev
```

Notification API will be available at `http://localhost:3001`

### Run the UI locally

```bash
cd services/ui
yarn install

# Update .env for local development
cat > .env << EOF
VITE_WS_URL=ws://localhost:3001/ws
VITE_API_URL=http://localhost:5000
EOF

yarn dev
```

UI will be available at `http://localhost:5173`

The UI will connect to local services automatically via the `.env` file.

## Testing

### Test the .NET API

```bash
# Local
curl http://localhost:5000/api/hello
curl http://localhost:5000/health

# Production (via Front Door)
FRONTDOOR_URL=$(cd infra/core && terraform output -raw frontdoor_endpoint_url)
curl $FRONTDOOR_URL/api/hello
curl $FRONTDOOR_URL/health

# Direct Container App URL
API_URL=$(cd infra/core && terraform output -raw api_service_url)
curl $API_URL/api/hello
```

### Test the Notification System

### Send a test notification (local):

```bash
curl -X POST http://localhost:3001/api/notifications/broadcast \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Test notification!",
    "type": "success",
    "title": "Hello"
  }'
```

### Send a test notification (production via Front Door):

```bash
FRONTDOOR_URL=$(cd infra/core && terraform output -raw frontdoor_endpoint_url)

curl -X POST $FRONTDOOR_URL/notifications/api/notifications/broadcast \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Production notification!",
    "type": "info",
    "title": "From Production"
  }'
```

### Test via Direct URL:

```bash
API_URL=$(cd infra/core && terraform output -raw notification_api_url)

curl -X POST $API_URL/api/notifications/broadcast \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Direct notification!",
    "type": "success"
  }'
```

## Deployment Workflow

```
┌─────────────────────────────────────────────────────────┐
│  Initial Setup (Once per environment)                   │
│  1. Bootstrap: terraform init && apply                  │
│  2. Core: terraform init -backend-config + apply        │
│  3. Deploy services: api, notification, ui              │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  Deploy Updates (As often as needed)                    │
│  • cd services/api && ./deploy.sh dev                   │
│  • cd services/notification-service && ./deploy.sh dev  │
│  • cd services/ui && ./deploy.sh dev                    │
│  • No Terraform needed for service updates!             │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  Infrastructure Changes (When needed)                   │
│  • Edit .tf files in infra/core/                        │
│  • terraform plan && apply                              │
│  • Redeploy affected services if needed                 │
└─────────────────────────────────────────────────────────┘
```

## Azure Front Door Routes

All traffic goes through Azure Front Door for optimal performance:

| Path Pattern | Destination | Purpose |
|-------------|-------------|---------|
| `/*` | Storage Account | React UI (default route) |
| `/api/*` | API Service (Container App) | .NET Web API endpoints |
| `/notifications/*` | Notification Service | REST endpoints |
| `/ws` | Notification Service | WebSocket connection |

**Benefits:**
- Single domain for all services
- Global CDN with edge caching
- SSL/TLS termination
- Health monitoring
- Load balancing
- DDoS protection

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

Container Apps should update automatically with deploy scripts. If you're experiencing issues, check the revision status:

```bash
RESOURCE_GROUP=$(cd infra/core && terraform output -raw resource_group_name)

# Check API Service
API_APP=$(cd infra/core && terraform output -raw api_service_name)
az containerapp revision list \
  --name $API_APP \
  --resource-group $RESOURCE_GROUP \
  --query "[].{Name:name, Active:properties.active, Created:properties.createdTime}" \
  -o table

# Check Notification Service
NOTIF_APP=$(cd infra/core && terraform output -raw container_app_name)
az containerapp revision list \
  --name $NOTIF_APP \
  --resource-group $RESOURCE_GROUP \
  --query "[].{Name:name, Active:properties.active, Created:properties.createdTime}" \
  -o table
```

### Front Door not routing correctly

Check the Front Door configuration:

```bash
RESOURCE_GROUP=$(cd infra/core && terraform output -raw resource_group_name)
FRONTDOOR_NAME=$(cd infra/core && terraform output -raw frontdoor_profile_name)

# List routes
az afd route list \
  --profile-name $FRONTDOOR_NAME \
  --resource-group $RESOURCE_GROUP \
  --endpoint-name $(cd infra/core && terraform output -raw frontdoor_endpoint_name) \
  -o table
```

### .NET API not starting

Check the container logs:

```bash
RESOURCE_GROUP=$(cd infra/core && terraform output -raw resource_group_name)
API_APP=$(cd infra/core && terraform output -raw api_service_name)

az containerapp logs show \
  --name $API_APP \
  --resource-group $RESOURCE_GROUP \
  --follow
```

### UI not updating

Clear the browser cache or do a hard refresh (Cmd+Shift+R on Mac, Ctrl+Shift+R on Windows).

# Notification API

WebSocket-based notification server that broadcasts notifications to connected clients via REST API.

## Features

- **WebSocket Server**: Real-time bidirectional communication
- **REST API**: POST endpoint to push notifications
- **Broadcasting**: Sends notifications to all connected clients
- **Connection Management**: Automatic reconnection handling
- **TypeScript**: Full type safety

## Local Development

### Start the server

```bash
yarn install
yarn dev
```

The server will start on `http://localhost:3001`

### Endpoints

- **WebSocket**: `ws://localhost:3001/ws`
- **REST API**: `POST http://localhost:3001/api/notifications/broadcast`
- **Health Check**: `GET http://localhost:3001/health`

### Test with curl

Send a notification:

```bash
curl -X POST http://localhost:3001/api/notifications/broadcast \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello from the API!",
    "type": "success",
    "title": "Test Notification"
  }'
```

### Notification Payload

```json
{
  "message": "Your notification message",
  "type": "info|success|warning|error",
  "title": "Optional title"
}
```

## Azure Deployment

### Environment Variables

The deployment script automatically reads environment variables from `.env.production` and applies them to the Container App.

**Files:**
- `.env` - Local development (not committed)
- `.env.production` - Production deployment (committed to git)
- `.env.*.local` - Local overrides (not committed)

**Example `.env.production`:**
```env
PORT=3001
NODE_ENV=production
LOG_LEVEL=info
MAX_CONNECTIONS=1000
```

Environment variables are automatically updated during `yarn deploy`.

### 1. Apply Terraform Infrastructure (One-time setup)

```bash
cd ../core
terraform init -backend-config=backends/backend-dev.hcl
terraform apply -var-file=vars/dev.tfvars
```

This will create:
- Azure Container Registry
- Azure Container Instance
- RBAC permissions
- Initial container deployment

### 2. Deploy Updates with Yarn

After the initial setup, you can deploy updates without touching Terraform:

```bash
# Deploy to dev
yarn deploy

# Deploy to staging
yarn deploy:staging

# Deploy to prod
yarn deploy:prod
```

This will:
1. Load environment variables from `.env.production`
2. Build the Docker image
3. Tag it with a timestamp (e.g., `20251002-143022`)
4. Also tag it as `latest` for convenience
5. Push both tags to Azure Container Registry
6. Update the container app with the timestamped version and new env vars
7. Show you the API URLs

That's it! No Terraform reapply needed. 🎉

### Image Versioning

Every deployment creates a timestamped image tag:
- `notification-api:20251002-143022` (timestamp)
- `notification-api:latest` (always points to most recent)

This allows you to:
- Track which version is deployed
- Roll back to previous versions if needed
- See deployment history in ACR

### Rollback to Previous Version

If you need to roll back:

```bash
# List available versions
az acr repository show-tags --name <acr-name> --repository notification-api --orderby time_desc

# Update to a specific version
az containerapp update \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --image <acr-login-server>/notification-api:20251002-120000
```

### Managing Environment Variables

**Add a new environment variable:**

1. Edit `.env.production`:
```env
PORT=3001
NODE_ENV=production
NEW_VARIABLE=value
```

2. Deploy:
```bash
yarn deploy
```

The new variable will be automatically applied.

**View current environment variables:**

```bash
az containerapp show \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --query "properties.template.containers[0].env"
```

**Important:** Environment variables in `.env.production` are committed to git. For secrets, use Azure Key Vault integration or Container App secrets instead.

### Manual Deployment

If you prefer to run the script directly:

```bash
./deploy.sh dev
```

### Get API URLs Anytime

```bash
cd ../core
terraform output notification_api_url
terraform output notification_api_websocket_url
```

### Update UI Environment

Update `/ui/.env.production` with the WebSocket URL:

```env
VITE_WS_URL=ws://api-core-dev-xxxxxx.uaenorth.azurecontainer.io:3001/ws
```

## Architecture

```
┌──────────────┐         ┌──────────────────┐         ┌──────────────┐
│   REST API   │ ──POST─→│  Notification    │ ──WS──→ │   Clients    │
│   Client     │         │     Server       │         │ (Browser)    │
└──────────────┘         └──────────────────┘         └──────────────┘
                                  │
                                  └──────→ Broadcast to all clients
```

## Testing

1. Start the API server locally
2. Open browser console and connect:

```javascript
const ws = new WebSocket('ws://localhost:3001/ws');
ws.onmessage = (event) => console.log(JSON.parse(event.data));
```

3. Send a notification via REST API
4. See the notification in browser console

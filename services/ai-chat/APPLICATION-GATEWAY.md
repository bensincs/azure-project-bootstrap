# Application Gateway Integration

The AI Chat service is integrated with the Application Gateway to provide:
- Centralized access through a single public IP
- SSL/TLS termination
- Health monitoring
- Path-based routing

## Configuration

### Backend Pool
- **Name**: `ai-chat-backend-pool`
- **Backend**: Container App FQDN (from `azurerm_container_app.ai_chat_service.latest_revision_fqdn`)

### HTTP Settings
- **Name**: `ai-chat-http-settings`
- **Protocol**: HTTPS
- **Port**: 443
- **Request Timeout**: 120 seconds (increased to support streaming responses)
- **Host Name Pickup**: Enabled (uses Container App hostname)

### Health Probe
- **Name**: `ai-chat-health-probe`
- **Protocol**: HTTPS
- **Host**: Container App hostname
- **Path**: `/ai-chat/health`
- **Interval**: 30 seconds
- **Timeout**: 30 seconds
- **Unhealthy Threshold**: 3 consecutive failures

### Path-Based Routing
- **Path Pattern**: `/ai-chat/*`
- **Backend Pool**: `ai-chat-backend-pool`
- **HTTP Settings**: `ai-chat-http-settings`
- **Priority**: 20 (between API at 10 and UI default at 30)

## Access URLs

After deployment, the AI Chat service is accessible at:
```
https://{app-gateway-public-ip}/ai-chat/*
```

### Endpoints
- **Health Check**: `https://{app-gateway-public-ip}/ai-chat/health`
- **Chat Stream**: `https://{app-gateway-public-ip}/ai-chat/stream` (POST)
- **Other endpoints**: `https://{app-gateway-public-ip}/ai-chat/{endpoint}`

## Get Your Application Gateway IP

```bash
cd infra/core
terraform output app_gateway_public_ip
```

## Streaming Considerations

The Application Gateway HTTP settings have been configured with:
- **120-second timeout**: Allows long-running streaming responses
- **HTTPS backend**: Secure communication with Container App
- **Dedicated health probe**: Monitors service availability independently

## UI Integration

Update your UI service `.env` file to use the Application Gateway URL:
```bash
VITE_AI_CHAT_URL=https://{app-gateway-public-ip}/ai-chat
```

This ensures:
- All traffic goes through the Application Gateway
- Consistent security posture across services
- Centralized SSL/TLS management
- Single point of entry for all services

## Monitoring

The Application Gateway health probe continuously monitors:
- Service availability at `/ai-chat/health`
- Response time and health status
- Automatic failover if service becomes unhealthy

Check health status in Azure Portal:
```
Application Gateway → Backend Health → ai-chat-backend-pool
```

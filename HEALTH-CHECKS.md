# Health Check Endpoints

All services provide health check endpoints that can be accessed **without JWT authentication**. These endpoints are explicitly excluded from JWT validation in the APIM policy.

## Available Health Endpoints

### 1. API Service Health Check
**Endpoint**: `/api/health`
**Method**: `GET`
**Authentication**: None required

**Response**:
```json
{
  "status": "healthy",
  "timestamp": "2025-10-14T12:00:00Z"
}
```

**Usage**:
```bash
# Via App Gateway (public)
curl https://<app-gateway-ip>/api/health

# Direct to API service (requires VPN or internal access)
curl https://<api-service-fqdn>/api/health
```

### 2. Notification Service Health Check
**Endpoint**: `/notify/health`
**Method**: `GET`
**Authentication**: None required

**Response**:
```json
{
  "status": "ok",
  "connectedClients": 5,
  "uptime": 3600.123
}
```

**Usage**:
```bash
# Via App Gateway (public)
curl https://<app-gateway-ip>/notify/health

# Direct to notification service (requires VPN or internal access)
curl https://<notification-service-fqdn>/api/health
```

**Note**: The notification service exposes `/api/health` internally, but APIM routes `/notify/*` to this service, so the public path is `/notify/health`.

### 3. Generic Health Check
**Endpoint**: `/health`
**Method**: `GET`
**Authentication**: None required

This endpoint routes to the UI service by default (since it doesn't match `/api` or `/notify` paths).

**Usage**:
```bash
# Via App Gateway (public)
curl https://<app-gateway-ip>/health
```

## APIM Policy Configuration

The APIM policy explicitly excludes these paths from JWT validation:

```xml
<when condition="@(context.Request.Url.Path.Equals("/health") ||
                   context.Request.Url.Path.Equals("/api/health") ||
                   context.Request.Url.Path.Equals("/notify/health"))">
    <!-- Health endpoints - no JWT validation required -->
</when>
```

This means:
- ✅ Health checks work without authentication
- ✅ Suitable for load balancers, monitoring systems, and automated health checks
- ✅ Each backend service handles its own health check logic
- ✅ Returns real service status, not just APIM availability

## Monitoring Integration

These health endpoints can be used with:

### Azure Application Gateway Health Probes
```terraform
backend_http_settings {
  probe_name = "api-health-probe"
  # ... other settings
}

probe {
  name                = "api-health-probe"
  protocol            = "Https"
  path                = "/api/health"
  interval            = 30
  timeout             = 30
  unhealthy_threshold = 3
  host                = "<apim-private-ip>"

  match {
    status_code = ["200"]
  }
}
```

### Azure Container Apps Health Probes
```terraform
liveness_probe {
  transport = "HTTP"
  path      = "/api/health"
  port      = 8080

  initial_delay_seconds = 30
  interval_seconds      = 30
  timeout_seconds       = 10
  failure_threshold     = 3
}

readiness_probe {
  transport = "HTTP"
  path      = "/api/health"
  port      = 8080

  initial_delay_seconds = 5
  interval_seconds      = 10
  timeout_seconds       = 5
  failure_threshold     = 3
}
```

### External Monitoring (Azure Monitor, Datadog, etc.)
```bash
# Simple HTTP check
curl -f https://<app-gateway-ip>/api/health || exit 1

# Check response status
response=$(curl -s -o /dev/null -w "%{http_code}" https://<app-gateway-ip>/api/health)
if [ "$response" != "200" ]; then
  echo "Health check failed with status: $response"
  exit 1
fi
```

## Authenticated vs Unauthenticated Paths

For reference, here's the complete authentication matrix:

| Path Pattern | JWT Required | Routes To | Notes |
|--------------|--------------|-----------|-------|
| `/` | ❌ No | UI Service | Public UI access |
| `/assets/*` | ❌ No | UI Service | Static assets |
| `/health` | ❌ No | UI Service | Generic health check |
| `/api/health` | ❌ No | API Service | API health check |
| `/api/hello` | ✅ Yes | API Service | Protected endpoint |
| `/api/user/me` | ✅ Yes | API Service | RBAC endpoint |
| `/notify/health` | ❌ No | Notification Service | Notification health check |
| `/notify/*` | ✅ Yes | Notification Service | Protected endpoints |
| `/ws` | ✅ Yes | Notification Service | WebSocket connections |

## Testing

### Local Testing (via App Gateway)
```bash
# Test API health
curl -v https://<app-gateway-ip>/api/health

# Test notification health
curl -v https://<app-gateway-ip>/notify/health

# Test protected endpoint (should fail without token)
curl -v https://<app-gateway-ip>/api/hello
# Expected: 401 Unauthorized

# Test with JWT token
TOKEN="<your-jwt-token>"
curl -v -H "Authorization: Bearer $TOKEN" https://<app-gateway-ip>/api/hello
# Expected: 200 OK
```

### Direct Testing (requires VPN)
```bash
# API service direct
curl -v https://<api-service-fqdn>/api/health

# Notification service direct
curl -v https://<notification-service-fqdn>/api/health
```

## Troubleshooting

### Health check returns 401 Unauthorized
- Check APIM policy - ensure health paths are in the exclusion list
- Verify the exact path being called matches the exclusion condition
- Check APIM logs in Azure Portal

### Health check returns 404 Not Found
- Verify the backend service has implemented the health endpoint
- Check APIM routing rules
- Verify Container App is running and accessible

### Health check times out
- Check Container App is running: `az containerapp list`
- Check Container App logs: `az containerapp logs show`
- Verify network connectivity between APIM and Container Apps
- Check Container Apps subnet NSG rules

### Inconsistent health check results
- Check if Container App is scaling (may be starting new instances)
- Review Container App startup time
- Consider increasing health probe intervals
- Check if liveness/readiness probes are properly configured

## Best Practices

1. **Implement Comprehensive Health Checks**: Don't just return `{ status: "ok" }`. Include:
   - Database connectivity
   - External service availability
   - Resource usage metrics
   - Dependencies status

2. **Use Different Endpoints for Liveness vs Readiness**:
   - `/api/health/live` - Basic process health (is it running?)
   - `/api/health/ready` - Ready to accept traffic (dependencies available?)

3. **Set Appropriate Timeouts**:
   - Health checks should respond quickly (< 5 seconds)
   - Don't perform expensive operations in health checks

4. **Monitor Health Check Metrics**:
   - Track health check response times
   - Alert on sustained failures
   - Use Azure Monitor or Application Insights

5. **Secure Direct Access**:
   - Health endpoints are public via APIM
   - Direct Container App access still requires private network (VPN)
   - Consider rate limiting for health endpoints if needed

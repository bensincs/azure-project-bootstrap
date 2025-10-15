# API Authentication

This API uses Azure AD JWT authentication to secure endpoints.

## Configuration

The following environment variables are required:

- `AZURE_TENANT_ID`: Your Azure AD tenant ID
- `AZURE_CLIENT_ID`: Your Azure AD application (client) ID
- `PORT`: (Optional) Server port, defaults to 8080

## Endpoints

### Public Endpoints

- `GET /api/health` - Health check endpoint (no authentication required)

### Authenticated Endpoints

- `GET /api/user/me` - Get current authenticated user information

## Authentication

Protected endpoints require a valid Azure AD JWT token in the Authorization header:

```
Authorization: Bearer <your-jwt-token>
```

### Token Requirements

The JWT must:
- Be signed by Azure AD with a valid RSA signature
- Have the correct issuer: `https://login.microsoftonline.com/{tenant-id}/v2.0`
- Have the correct audience matching your `AZURE_CLIENT_ID`
- Not be expired

### User Information

The middleware extracts the following information from the JWT and makes it available to handlers:

```json
{
  "id": "user-object-id",
  "email": "user@example.com",
  "name": "User Name",
  "preferredUsername": "user@example.com",
  "tenantId": "tenant-id",
  "roles": ["role1", "role2"],
  "groups": ["group-id-1", "group-id-2"],
  "issuedAt": "2025-10-15T10:00:00Z",
  "expiresAt": "2025-10-15T11:00:00Z"
}
```

## Example Usage

### Testing with curl

```bash
# Get a token from your frontend or auth flow
TOKEN="your-jwt-token-here"

# Call the authenticated endpoint
curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:8080/api/user/me
```

### Response Example

```json
{
  "id": "12345678-1234-1234-1234-123456789012",
  "email": "user@example.com",
  "name": "John Doe",
  "preferredUsername": "user@example.com",
  "tenantId": "87654321-4321-4321-4321-210987654321",
  "roles": [],
  "groups": [],
  "issuedAt": "2025-10-15T10:00:00Z",
  "expiresAt": "2025-10-15T11:00:00Z"
}
```

## Development

### Running Locally

```bash
# Set environment variables
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-client-id"
export PORT="8080"

# Run the API
go run cmd/api/main.go
```

### Adding New Protected Endpoints

To protect a new endpoint with authentication:

```go
// In main.go
protectedHandler := handlers.NewYourHandler()
http.Handle("/api/your-endpoint", authMiddleware.Middleware(protectedHandler))
```

To access the authenticated user in your handler:

```go
// In your handler
import "api-service/internal/middleware"

func (h *YourHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    user, ok := middleware.GetUserFromContext(r.Context())
    if !ok {
        http.Error(w, "Unauthorized", http.StatusUnauthorized)
        return
    }

    // Use user information
    log.Printf("Request from user: %s", user.Email)
}
```

## Security Notes

- The middleware caches JWKS (public keys) for 1 hour to reduce calls to Azure AD
- Tokens are validated on every request
- The middleware verifies:
  - Token signature using Azure AD public keys
  - Token expiration
  - Issuer matches your tenant
  - Audience matches your client ID

## Troubleshooting

### "Missing authorization header"
Ensure you're sending the `Authorization` header with your request.

### "Invalid token"
- Check that your token hasn't expired
- Verify `AZURE_TENANT_ID` and `AZURE_CLIENT_ID` are correct
- Ensure the token was issued for your application

### "Failed to refresh JWKS"
- Check your network connection
- Verify the tenant ID is correct
- Ensure `https://login.microsoftonline.com` is accessible

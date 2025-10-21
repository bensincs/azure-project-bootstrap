# JWT Authentication for WebRTC Signaling Server

This service uses JWT (JSON Web Token) authentication with Azure AD to secure WebSocket connections and REST API endpoints.

## How It Works

1. **Client Authentication**: The UI authenticates users with Azure AD and obtains a JWT access token
2. **Token Transmission**: The JWT token is sent to the signaling server in two ways:
   - WebSocket: Via `auth.token` in the Socket.IO handshake
   - REST API: Via `Authorization: Bearer <token>` header
3. **Token Validation**: The server validates the JWT signature using Azure AD's JWKS (JSON Web Key Set)
4. **User Identification**: User information (name, email, ID) is extracted from the validated JWT claims

## Security Benefits

- **No User-Provided Usernames**: Username comes from verified JWT claims, preventing impersonation
- **Cryptographic Verification**: JWT signature is verified using Azure AD public keys
- **Token Expiration**: Tokens automatically expire and must be refreshed
- **Audience Validation**: Ensures tokens are issued for this specific application
- **Issuer Validation**: Confirms tokens are issued by the expected Azure AD tenant

## Configuration

### Environment Variables

```bash
# Required in production
AZURE_TENANT_ID=your-tenant-id-here      # Azure AD tenant ID
AZURE_CLIENT_ID=your-client-id-here      # Application (client) ID

# Development mode (skips signature verification - NOT FOR PRODUCTION!)
SKIP_TOKEN_VERIFICATION=false            # Set to 'true' only for local dev

# Server configuration
PORT=3000
ALLOWED_ORIGINS=http://localhost:5173    # Comma-separated list
```

### Setup Steps

1. **Install Dependencies**:
   ```bash
   npm install
   ```

2. **Configure Environment**:
   ```bash
   # Option 1: Use env.sh script (reads from Terraform)
   ./env.sh

   # Option 2: Manually create .env file
   cp .env.example .env
   # Edit .env with your values
   ```

3. **Start Server**:
   ```bash
   # Development
   npm run dev

   # Production
   npm start
   ```

## Development Mode

For local development without Azure AD setup:

```bash
export SKIP_TOKEN_VERIFICATION=true
npm run dev
```

⚠️ **WARNING**: This disables JWT signature verification. Only use in development!

## API Endpoints

### Protected Endpoints (Require JWT)

- `GET /api/rooms` - List all rooms
- `POST /api/rooms` - Create a new room
- `GET /api/rooms/:roomId` - Get room details

### Public Endpoints

- `GET /health` - Health check (no auth required)

## WebSocket Authentication

Socket.IO connections must include the JWT token:

```javascript
import { io } from 'socket.io-client';

const socket = io('http://localhost:3000', {
  auth: {
    token: userAccessToken  // JWT from Azure AD
  }
});
```

## JWT Claims Used

The server extracts the following claims from the JWT:

- `oid` or `sub` - User ID (unique identifier)
- `name` - User's display name
- `email` - User's email address
- `preferred_username` - User's preferred username (usually email)

## Error Handling

### Common Authentication Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `Missing authorization header` | No token provided | Include `Authorization: Bearer <token>` header |
| `Invalid token` | Token signature verification failed | Check token is valid and from correct Azure AD tenant |
| `Authentication token required` | WebSocket connection without token | Include token in `auth.token` during connection |
| `Authentication failed` | Token expired or invalid | Refresh the token and reconnect |

## Security Best Practices

1. **Never skip token verification in production**
2. **Use HTTPS in production** (required for secure token transmission)
3. **Rotate Azure AD signing keys regularly** (handled automatically by Azure AD)
4. **Monitor for authentication failures** (may indicate attacks)
5. **Set appropriate CORS origins** (limit to known domains)

## Token Flow Diagram

```
User → Azure AD
         ↓
      JWT Token
         ↓
    UI Component → WebRTC Signaling Server
                      ↓
                  Validate with Azure AD JWKS
                      ↓
                  Extract User Claims
                      ↓
                  Authorize WebSocket/API Access
```

## Testing

### Test with curl (REST API)

```bash
# Get a token from your UI or Azure AD
export TOKEN="your-jwt-token-here"

# List rooms
curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:3000/api/rooms

# Create room
curl -X POST \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"name":"Test Room"}' \
     http://localhost:3000/api/rooms
```

### Test WebSocket Connection

```javascript
// In browser console or Node.js
const token = 'your-jwt-token-here';
const socket = io('http://localhost:3000', {
  auth: { token }
});

socket.on('connect', () => {
  console.log('Connected and authenticated!');
});

socket.on('connect_error', (error) => {
  console.error('Authentication failed:', error.message);
});
```

## Troubleshooting

### "JWKS client not initialized"
- Ensure `AZURE_TENANT_ID` environment variable is set
- Check that the tenant ID is correct

### "Public key not found for kid: xxx"
- The JWT was signed with a key not in Azure AD's JWKS
- Try refreshing (keys are cached for 1 hour)
- Verify the token is from the correct Azure AD tenant

### "Invalid issuer"
- Token was not issued by the expected Azure AD tenant
- Check `AZURE_TENANT_ID` matches the token's `iss` claim

### "Invalid audience"
- Token was not issued for this application
- Check `AZURE_CLIENT_ID` matches the token's `aud` claim

## Related Documentation

- [Azure AD JWT Token Reference](https://docs.microsoft.com/en-us/azure/active-directory/develop/access-tokens)
- [Socket.IO Authentication](https://socket.io/docs/v4/middlewares/)
- [JWT.io - Debug Tokens](https://jwt.io)

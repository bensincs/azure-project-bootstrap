# Video Chat Security Enhancement - JWT Authentication

## Overview
Implemented JWT-based authentication for the WebRTC signaling server to secure video chat rooms using the same Azure AD authentication as other services in the application.

## Changes Made

### 1. WebRTC Signaling Server (`services/webrtc-signaling/`)

#### Added Dependencies
- `jsonwebtoken@^9.0.2` - JWT parsing and verification
- `jwks-rsa@^3.1.0` - Azure AD public key fetching and caching

#### Modified Files

**`src/server.js`**:
- Added JWT verification middleware using Azure AD JWKS
- Protected REST API endpoints (`/api/rooms/*`) with JWT authentication
- Added Socket.IO authentication middleware
- Extract username from JWT claims instead of client input
- Configuration via environment variables:
  - `AZURE_TENANT_ID` - Azure AD tenant ID
  - `AZURE_CLIENT_ID` - Application client ID
  - `SKIP_TOKEN_VERIFICATION` - Development mode flag (default: false)

**`package.json`**:
- Added `jsonwebtoken` and `jwks-rsa` dependencies

**`env.sh`**:
- Updated to read and set `AZURE_TENANT_ID` and `AZURE_CLIENT_ID` from Terraform outputs
- Added authentication configuration to generated `.env` file

#### New Files

**`AUTH.md`**:
- Comprehensive documentation on JWT authentication
- Setup instructions and configuration
- Security best practices
- Troubleshooting guide
- API endpoint documentation

### 2. UI Service (`services/ui/`)

#### Modified Files

**`src/pages/VideoChat.tsx`**:
- Import and use `useAuth` hook to access user and JWT token
- Pass JWT token in Socket.IO connection via `auth.token`
- Include JWT token in REST API calls via `Authorization` header
- Removed username input from join modal (now uses JWT claims)
- Display user's name from JWT profile throughout UI
- Simplified join flow - just confirmation instead of name entry

**Changes in detail**:
```typescript
// Socket.IO connection with JWT
const socket = io(SIGNALING_SERVER, {
  auth: {
    token: user.access_token
  }
});

// API calls with JWT
fetch(`${SIGNALING_SERVER}/api/rooms`, {
  headers: {
    'Authorization': `Bearer ${user.access_token}`
  }
});

// Display name from JWT
{user?.profile?.name || user?.profile?.preferred_username || user?.profile?.email}
```

## Security Improvements

### Before
- ❌ Users could enter any username (impersonation risk)
- ❌ No authentication on REST API endpoints
- ❌ No authentication on WebSocket connections
- ❌ Anyone could create/join rooms

### After
- ✅ Username verified via Azure AD JWT token
- ✅ All API endpoints require valid JWT
- ✅ WebSocket connections require valid JWT
- ✅ User identity cryptographically verified
- ✅ Token signature verified using Azure AD public keys
- ✅ Automatic token expiration handling
- ✅ Consistent authentication with other services (API, AI Chat)

## How It Works

### Authentication Flow

1. **User Login**: User authenticates with Azure AD via the UI
2. **Token Acquisition**: UI receives JWT access token with user claims
3. **WebSocket Connection**:
   - UI passes token in Socket.IO `auth.token` parameter
   - Server validates token signature against Azure AD JWKS
   - Server extracts user ID, name, email from verified claims
4. **REST API Calls**:
   - UI includes `Authorization: Bearer <token>` header
   - Server validates token before processing request
5. **Room Operations**:
   - All room operations now associated with authenticated user
   - Username displayed in video chat comes from JWT, not user input

### JWT Claims Used

The server extracts and uses these claims:
- `oid` or `sub` - Unique user ID
- `name` - Display name (shown in video chat)
- `email` - Email address
- `preferred_username` - Preferred username (fallback)

## Configuration

### Development Mode

For local development without Azure AD:
```bash
export SKIP_TOKEN_VERIFICATION=true
export AZURE_TENANT_ID=dummy
export AZURE_CLIENT_ID=dummy
npm run dev
```

⚠️ **WARNING**: Only use `SKIP_TOKEN_VERIFICATION=true` in local development!

### Production Mode

Set proper environment variables:
```bash
export AZURE_TENANT_ID=cab08f14-2b61-43ee-8ebe-16acd8e371bf
export AZURE_CLIENT_ID=0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2
export SKIP_TOKEN_VERIFICATION=false
npm start
```

Or use the `env.sh` script to generate from Terraform:
```bash
./env.sh  # Generates .env file from Terraform outputs
npm start
```

## Testing

### 1. Start the signaling server:
```bash
cd services/webrtc-signaling
npm install
export SKIP_TOKEN_VERIFICATION=true  # Development only!
npm run dev
```

### 2. Start the UI:
```bash
cd services/ui
yarn dev
```

### 3. Test the flow:
1. Login to the UI (authenticates with Azure AD)
2. Navigate to Video Chat
3. Create a room (sends JWT in Authorization header)
4. Join the room (connects WebSocket with JWT)
5. Your name from Azure AD profile appears automatically
6. Other authenticated users can join

### 4. Verify authentication:
- Check server logs for "Authenticated user: ..." messages
- Try accessing `/api/rooms` without token (should fail with 401)
- Check that displayed username matches Azure AD profile

## Migration Notes

### Breaking Changes
- WebSocket connections now require `auth.token` parameter
- REST API endpoints require `Authorization` header
- Username is no longer accepted from client (comes from JWT)

### Backwards Compatibility
- None - this is a breaking change requiring authentication

### Deployment Considerations
1. Ensure `AZURE_TENANT_ID` and `AZURE_CLIENT_ID` are set in production
2. Set `SKIP_TOKEN_VERIFICATION=false` in production
3. Update CORS `ALLOWED_ORIGINS` to include your production domain
4. Ensure UI can reach signaling server (network/firewall rules)

## Related Files

### Documentation
- `/services/webrtc-signaling/AUTH.md` - Complete authentication guide
- `/services/webrtc-signaling/README.md` - Service overview

### Configuration
- `/services/webrtc-signaling/env.sh` - Environment setup script
- `/services/webrtc-signaling/package.json` - Dependencies

### Implementation
- `/services/webrtc-signaling/src/server.js` - Server with JWT auth
- `/services/ui/src/pages/VideoChat.tsx` - Client with JWT integration

## Next Steps

### Optional Enhancements
1. **Room Ownership**: Track who created each room (using JWT user ID)
2. **Room Access Control**: Restrict room access to specific users/groups
3. **Rate Limiting**: Limit API calls per user (using JWT user ID)
4. **Audit Logging**: Log all actions with authenticated user ID
5. **User Roles**: Use JWT roles/groups for admin features

### Production Readiness
- [ ] Test with real Azure AD in staging environment
- [ ] Verify CORS configuration for production domains
- [ ] Set up monitoring for authentication failures
- [ ] Document token refresh flow for long sessions
- [ ] Load test with authenticated connections

## Troubleshooting

### Common Issues

**"Missing authorization header"**
- Solution: Ensure UI is passing JWT token in requests

**"Authentication token required" (WebSocket)**
- Solution: Check Socket.IO connection includes `auth.token`

**"Invalid token"**
- Solution: Verify token is from correct Azure AD tenant
- Solution: Check token hasn't expired (refresh if needed)

**"JWKS client not initialized"**
- Solution: Set `AZURE_TENANT_ID` environment variable

### Debug Mode

Enable detailed logging:
```javascript
// In server.js, the JWT verification already logs:
console.log('Authenticated user:', socket.user.name);
console.log('Token claims:', decoded);
```

Check client-side token:
```javascript
// In browser console
console.log('Access token:', user.access_token);
console.log('Token payload:', JSON.parse(atob(user.access_token.split('.')[1])));
```

## Conclusion

The video chat service is now secured with the same JWT authentication system used throughout the application. Users are identified by their Azure AD credentials, preventing impersonation and providing a consistent security model across all services.

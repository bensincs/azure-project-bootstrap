# Testing Azure AD JWT Authentication

## Current Status
✅ **API is working!** The logs show successful token validation and user info retrieval.

The API logs show:
```
Token claims (unverified): iss=https://login.microsoftonline.com/.../v2.0,
                          aud=0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2
Found public key for kid: HS23b7Do7TcaU1RoLHwpIq24VYg
User info retrieved for: (ac0a7274-caba-4b78-a48f-d44739ce7dab)
```

This means:
- ✅ Token has correct audience (your client ID)
- ✅ JWT signature validation is working
- ✅ User info extraction is successful

## UI Changes
The frontend has been simplified to focus on testing the authenticated endpoint:

**Removed:**
- Health check test button
- Config test button
- Hello endpoint tests
- Name input field

**Kept:**
- Single "Get My User Info" button that tests `/api/user/me`
- Clear instructions for first-time testing
- Result display with authentication status

## Testing Steps

### If This Is Your First Test (After Auth Config Update)

1. **Open your browser DevTools** (F12 or right-click → Inspect)

2. **Navigate to Application → Storage:**
   - Clear all **Local Storage**
   - Clear all **Session Storage**

3. **Log out** of the application (if currently logged in)

4. **Log back in** - this will get you a fresh token with the correct scope:
   ```
   api://0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2/api.access
   ```

5. **Click "Get My User Info"** button

### Expected Results

**Success Response (200):**
```json
{
  "id": "ac0a7274-caba-4b78-a48f-d44739ce7dab",
  "email": "your-email@domain.com",
  "name": "Your Name",
  "preferred_username": "your-email@domain.com",
  "tenant_id": "cab08f14-2b61-43ee-8ebe-16acd8e371bf",
  "roles": [],
  "groups": []
}
```

**Common Error (if you haven't cleared storage):**
```json
{
  "error": "token validation failed",
  "message": "token audience does not match"
}
```
This means you're still using an old token - follow the cleanup steps above.

## Architecture Overview

### Backend (Go API)
- **Config**: Loads Azure AD credentials from environment
- **Middleware**:
  - CORS for cross-origin requests
  - JWT validation with JWKS caching (1-hour TTL)
  - RSA signature verification
- **Endpoint**: `GET /api/user/me` (authenticated)

### Frontend (React/TypeScript)
- **Auth**: oidc-client-ts with Azure AD
- **Scope**: `api://0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2/api.access`
- **Token**: Automatically included in `Authorization: Bearer <token>` header

## Configuration

### Azure AD Application
- **Client ID**: `0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2`
- **Tenant ID**: `cab08f14-2b61-43ee-8ebe-16acd8e371bf`
- **Application ID URI**: `api://0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2`
- **Scope**: `api.access`

### Environment Variables (API)
```bash
AZURE_TENANT_ID=cab08f14-2b61-43ee-8ebe-16acd8e371bf
AZURE_CLIENT_ID=0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2
PORT=8080
```

### Environment Variables (UI)
```bash
VITE_API_URL=http://localhost:8080/api
VITE_AZURE_TENANT_ID=cab08f14-2b61-43ee-8ebe-16acd8e371bf
VITE_AZURE_CLIENT_ID=0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2
```

## Debugging

### API Logs to Watch
```
✅ Token claims (unverified): iss=..., aud=..., kid=...
✅ Found public key for kid: ...
✅ User info retrieved for: <email> (<user-id>)
```

### Common Issues

**"token signature is invalid"**
- Old issue - now fixed with correct JWKS parsing

**"token audience does not match"**
- Token still has Graph API audience (`00000003-0000-0000-c000-000000000000`)
- Solution: Clear browser storage and re-login

**"resource principal not found"**
- Application ID URI not set in Azure AD
- Solution: Already fixed via `az ad app update`

**401 Unauthorized on Graph API**
- Old issue from `loadUserInfo: true`
- Solution: Already fixed in `authConfig.ts`

## Related Documentation
- `AUTH.md` - General authentication setup
- `DEBUGGING-AUTH.md` - Comprehensive troubleshooting guide
- `TOKEN-FIX.md` - Details on the token audience fix

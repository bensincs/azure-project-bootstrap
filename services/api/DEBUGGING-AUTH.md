# JWT Token Verification Debugging

## Issue
Token signature verification is failing with error: `crypto/rsa: verification error`

## Quick Fix for Development

To temporarily bypass signature verification and get your app working:

```bash
export SKIP_TOKEN_VERIFICATION=true
go run cmd/api/main.go
```

⚠️ **WARNING**: Only use this for local development! Never deploy to production with this enabled.

## Root Cause Analysis

The signature verification error can occur due to several reasons:

### 1. **Token Audience Mismatch**
The token's `aud` (audience) claim must match your `AZURE_CLIENT_ID`.

**Check**: Look at the API logs for the unverified token claims:
```
Token claims (unverified): iss=..., aud=..., kid=...
```

The `aud` should match your CLIENT_ID: `0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2`

### 2. **Wrong Token Endpoint**
If your frontend is getting tokens for the wrong resource/scope.

**Solution**: Ensure your frontend auth config requests a token with the correct scope:
```typescript
// In your frontend authConfig
scope: `api://${clientId}/access_as_user`
// OR
scope: `${clientId}/.default`
```

### 3. **Token Issuer Mismatch**
Azure AD can issue tokens with different issuer formats:
- v2.0: `https://login.microsoftonline.com/{tenant}/v2.0`
- v1.0: `https://sts.windows.net/{tenant}/`

**Current Config**: The API now accepts both formats.

### 4. **JWK Key ID (kid) Not Found**
The API caches public keys from Azure AD. If Azure rotates keys, the kid might not match.

**Solution**: The API automatically refreshes keys if not found, but you can force refresh by restarting.

## Debugging Steps

### Step 1: Check Token Claims (No Verification)

With `SKIP_TOKEN_VERIFICATION=true`, you can see what's in the token:

```bash
export SKIP_TOKEN_VERIFICATION=true
go run cmd/api/main.go
```

Watch the logs for:
```
Token claims (unverified): iss=..., aud=..., kid=...
```

### Step 2: Verify Audience

Check that the `aud` claim matches your CLIENT_ID:
```
Expected: 0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2
Actual:   <check logs>
```

If they don't match, update your frontend to request the correct token scope.

### Step 3: Check Frontend Auth Configuration

In your UI, verify the auth config at `/services/ui/src/lib/authConfig.ts`:

```typescript
export const msalConfig = {
  auth: {
    clientId: "0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2",
    authority: "https://login.microsoftonline.com/cab08f14-2b61-43ee-8ebe-16acd8e371bf",
    redirectUri: window.location.origin + "/auth/callback",
  },
};

export const loginRequest = {
  scopes: ["api://0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2/access_as_user"],
};
```

### Step 4: Check Azure AD App Registration

1. Go to Azure Portal → Azure Active Directory → App Registrations
2. Find your app: `0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2`
3. Check **Expose an API**:
   - Should have scope: `api://0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2/access_as_user`
4. Check **API Permissions**:
   - Add `User.Read` (Microsoft Graph)
   - Grant admin consent if needed

### Step 5: Get a Fresh Token

Sometimes old cached tokens cause issues:
1. Clear browser local storage
2. Log out and log back in
3. Try the API call again

## Production Fix

Once you've verified the token works with `SKIP_TOKEN_VERIFICATION=true`, you need to fix the actual issue:

### Option A: Fix Token Scope (Most Common)

Update your frontend to request tokens with the correct audience:

```typescript
// services/ui/src/lib/authConfig.ts
export const loginRequest = {
  scopes: [`api://${process.env.VITE_AZURE_CLIENT_ID}/access_as_user`],
};
```

### Option B: Use Access Token for API (v2.0)

Ensure you're using the access token, not the ID token:

```typescript
const accounts = instance.getAllAccounts();
const response = await instance.acquireTokenSilent({
  scopes: ["api://0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2/access_as_user"],
  account: accounts[0],
});
const token = response.accessToken; // Use accessToken, not idToken
```

### Option C: Accept ID Tokens

If you want to accept ID tokens (issued to your client ID), the audience will be your CLIENT_ID itself. This is already supported.

## Testing

Once fixed, test with verification enabled:

```bash
unset SKIP_TOKEN_VERIFICATION  # or export SKIP_TOKEN_VERIFICATION=false
go run cmd/api/main.go
```

Test the endpoint:
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8080/api/user/me
```

You should see your user info without errors!

## Environment Variables

```bash
# Required
export AZURE_TENANT_ID="cab08f14-2b61-43ee-8ebe-16acd8e371bf"
export AZURE_CLIENT_ID="0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2"

# Optional
export PORT="8080"

# Development only (never in production!)
export SKIP_TOKEN_VERIFICATION="true"  # Only for debugging
```

# 🎯 SOLUTION: Token Audience Mismatch

## The Problem

Your token was being issued for **Microsoft Graph API** (aud: `00000003-0000-0000-c000-000000000000`) instead of for your custom API (aud: `0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2`).

This is why the signature verification was failing - the token wasn't meant for your API.

## The Fix

I've updated `/services/ui/src/lib/authConfig.ts` to request the correct scope:

```typescript
scope: `api://${clientId}/api.access openid profile email`
```

This tells Azure AD to issue an access token specifically for your API.

## What Changed

### Before (❌ Wrong)
```typescript
scope: "openid profile email"  // This gives you a Microsoft Graph token
```

### After (✅ Correct)
```typescript
scope: `api://0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2/api.access openid profile email`
```

## How to Test

1. **Clear your browser storage** (important - old tokens are cached):
   - Open DevTools (F12)
   - Go to Application tab
   - Clear all local storage and session storage
   - Or use incognito/private window

2. **Restart your UI**:
   ```bash
   cd services/ui
   npm run dev
   ```

3. **Log out and log back in** to get a new token with the correct audience

4. **Make a request to `/api/user/me`** - it should now work!

## Verify the Token

When you make a request, the API logs will now show:
```
Token claims (unverified): iss=..., aud=0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2, kid=...
```

The `aud` should now match your CLIENT_ID! ✅

## Using the Token in Your UI

When making API calls from your frontend, use the access token:

```typescript
import { useAuth } from '@/hooks/useAuth';

function MyComponent() {
  const { user } = useAuth();

  const callAPI = async () => {
    if (!user) return;

    const response = await fetch('http://localhost:8080/api/user/me', {
      headers: {
        'Authorization': `Bearer ${user.access_token}`,  // <-- Use access_token
      },
    });

    const data = await response.json();
    console.log(data);
  };

  return <button onClick={callAPI}>Get My Info</button>;
}
```

## API Configuration Required

Your Azure AD app registration (already configured in terraform) exposes the API scope:

```hcl
api {
  oauth2_permission_scope {
    value = "api.access"  # This is what we're requesting
  }
}
```

The full scope URI becomes: `api://0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2/api.access`

## Remove Debug Mode

Once this works, you can remove the skip verification flag:

```bash
unset SKIP_TOKEN_VERIFICATION
# or
export SKIP_TOKEN_VERIFICATION=false
```

## Expected Result

✅ Token will have the correct audience
✅ Signature verification will pass
✅ `/api/user/me` endpoint will return your user info
✅ All authenticated endpoints will work

## Why This Happened

When you request scopes like `openid profile email` without specifying your API, Azure AD issues tokens for Microsoft Graph by default. To get a token for your custom API, you must explicitly request a scope that your API exposes.

The scope format is: `api://{clientId}/{scope-name}`

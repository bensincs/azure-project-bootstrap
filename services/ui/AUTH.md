# Authentication Implementation

This UI uses OpenID Connect (OIDC) with Azure AD for authentication.

## Overview

The authentication is configured to allow **anyone with a Microsoft account** to log in. No special group membership or organization enrollment is required.

## File Organization

Following the existing project structure:

### `lib/authConfig.ts`
Contains the OIDC configuration including:
- Azure AD tenant ID (from `VITE_AUTH_TENANT_ID` env var)
- Application client ID (from `VITE_AUTH_CLIENT_ID` env var)
- Redirect URIs (dynamically generated from current origin)
- Scopes (openid, profile, email)

The configuration reads from environment variables set in `.env`:
```bash
VITE_AUTH_CLIENT_ID=0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2
VITE_AUTH_TENANT_ID=cab08f14-2b61-43ee-8ebe-16acd8e371bf
```

### `hooks/useAuth.tsx`
React context hook for managing authentication state throughout the app using `oidc-client-ts`:
- `AuthProvider` - Context provider component
- `useAuth()` - Hook to access auth state and userManager

### `components/LoginButton.tsx`
A simple component that shows:
- **Login button** when user is not authenticated
- **User name + Logout button** when authenticated

### `pages/AuthCallback.tsx`
Handles the OAuth2 redirect callback after login. This component processes the authentication response and redirects users back to the main app.

## Usage

The authentication is already wired up in the app:

1. **Main App** (`main.tsx`): Wrapped with `<AuthProvider>`
2. **Landing Page**: Includes the `<LoginButton />` in the header
3. **Routes**: Added `/auth/callback` route for OAuth2 redirect

## Testing Locally

1. Make sure `.env` has the correct auth values:
   ```bash
   VITE_AUTH_CLIENT_ID=0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2
   VITE_AUTH_TENANT_ID=cab08f14-2b61-43ee-8ebe-16acd8e371bf
   ```
2. Start the dev server: `yarn dev`
3. Click "Login" in the header
4. Sign in with any Microsoft account (personal or work)
5. You'll be redirected back to the app as authenticated

## Deployment

The auth configuration is injected via environment variables in `.env`. The `deploy.sh` script automatically reads these values and sets them in the Container App.

To get the correct values from Terraform:
```bash
cd ../../infra/core
terraform output -raw azure_ad_application_id  # Use for VITE_AUTH_CLIENT_ID
terraform output -raw azure_ad_tenant_id       # Use for VITE_AUTH_TENANT_ID
```

Update `.env` with these values, then deploy:
```bash
cd ../../services/ui
./deploy.sh
```

The redirect URIs are configured in Terraform (`azure-ad.tf`) to support:
- **Production**: `https://74.243.252.255/auth/callback`
- **Local dev**: `http://localhost:5173/auth/callback`

When you update redirect URIs:
```bash
cd infra/core
terraform apply -var-file=vars/dev.tfvars -auto-approve
```

## Allowing Anyone to Login

The Azure AD app is configured with:
- **Supported account types**: Accounts in any organizational directory (Any Azure AD directory - Multitenant) and personal Microsoft accounts
- This means **anyone** with a Microsoft account can log in
- No group membership or special permissions required

## Using Auth in Components

```tsx
import { useAuth } from '../hooks/useAuth';

function MyComponent() {
  const { user, isLoading, userManager } = useAuth();
  
  if (isLoading) return <div>Loading...</div>;
  
  if (!user) {
    return <button onClick={() => userManager.signinRedirect()}>Login</button>;
  }
  
  return <div>Welcome, {user.profile.name}!</div>;
}
```

## Next Steps

To add authorization (restricting access based on groups/roles):
1. Configure group memberships in Azure AD
2. Use the `user.profile.groups` claim in your React components
3. Add conditional rendering based on group membership
4. Configure APIM policies to validate groups in JWT tokens

# UI Authentication Setup Guide

This guide explains how to implement Azure AD authentication in the React UI using MSAL (Microsoft Authentication Library).

## Overview

- **UI Access**: Publicly accessible without authentication
- **API Access**: Requires valid JWT token from Azure AD
- **Authentication Flow**: Authorization Code Flow with PKCE (recommended for SPAs)
- **Library**: [@azure/msal-browser](https://github.com/AzureAD/microsoft-authentication-library-for-js)

## Prerequisites

1. Azure AD App Registration configured (already done in `infra/core/azure-ad.tf`)
2. App Registration Client ID
3. Azure AD Tenant ID

## Installation

```bash
npm install @azure/msal-browser @azure/msal-react
```

## Configuration

### 1. Create MSAL Configuration

Create `src/authConfig.ts`:

```typescript
import { Configuration, PopupRequest } from "@azure/msal-browser";

// Get these values from your Azure AD App Registration or Terraform outputs
export const msalConfig: Configuration = {
  auth: {
    clientId: import.meta.env.VITE_AZURE_AD_CLIENT_ID!, // Set in .env file
    authority: `https://login.microsoftonline.com/${import.meta.env.VITE_AZURE_AD_TENANT_ID}`,
    redirectUri: window.location.origin, // Or specific path like "/auth/callback"
  },
  cache: {
    cacheLocation: "sessionStorage", // Or "localStorage"
    storeAuthStateInCookie: false,
  },
};

// Scopes to request when acquiring tokens
export const loginRequest: PopupRequest = {
  scopes: [`api://${import.meta.env.VITE_AZURE_AD_CLIENT_ID}/access_as_user`],
};

// Additional scopes for Microsoft Graph (if needed)
export const graphRequest = {
  scopes: ["User.Read"],
};
```

### 2. Environment Variables

Create `.env.local` for development:

```env
VITE_AZURE_AD_CLIENT_ID=your-client-id-here
VITE_AZURE_AD_TENANT_ID=your-tenant-id-here
VITE_API_BASE_URL=http://localhost:5173
```

For production, these will come from App Gateway:
```env
VITE_AZURE_AD_CLIENT_ID=your-client-id-here
VITE_AZURE_AD_TENANT_ID=your-tenant-id-here
VITE_API_BASE_URL=https://your-app-gateway-ip
```

### 3. Update Main App Entry

Update `src/main.tsx`:

```typescript
import React from 'react';
import ReactDOM from 'react-dom/client';
import { PublicClientApplication } from '@azure/msal-browser';
import { MsalProvider } from '@azure/msal-react';
import App from './App';
import { msalConfig } from './authConfig';
import './index.css';

// Create MSAL instance
const msalInstance = new PublicClientApplication(msalConfig);

// Initialize MSAL before rendering
msalInstance.initialize().then(() => {
  ReactDOM.createRoot(document.getElementById('root')!).render(
    <React.StrictMode>
      <MsalProvider instance={msalInstance}>
        <App />
      </MsalProvider>
    </React.StrictMode>
  );
});
```

### 4. Create Authentication Hook

Create `src/hooks/useAuth.ts`:

```typescript
import { useMsal } from '@azure/msal-react';
import { InteractionRequiredAuthError } from '@azure/msal-browser';
import { loginRequest } from '../authConfig';

export function useAuth() {
  const { instance, accounts } = useMsal();

  const isAuthenticated = accounts.length > 0;
  const user = accounts[0] || null;

  const login = async () => {
    try {
      await instance.loginPopup(loginRequest);
    } catch (error) {
      console.error('Login failed:', error);
      throw error;
    }
  };

  const logout = () => {
    instance.logoutPopup({
      postLogoutRedirectUri: window.location.origin,
    });
  };

  const getAccessToken = async () => {
    if (!isAuthenticated) {
      return null;
    }

    const request = {
      ...loginRequest,
      account: accounts[0],
    };

    try {
      // Try to acquire token silently first
      const response = await instance.acquireTokenSilent(request);
      return response.accessToken;
    } catch (error) {
      if (error instanceof InteractionRequiredAuthError) {
        // If silent acquisition fails, use popup
        const response = await instance.acquireTokenPopup(request);
        return response.accessToken;
      }
      console.error('Token acquisition failed:', error);
      throw error;
    }
  };

  return {
    isAuthenticated,
    user,
    login,
    logout,
    getAccessToken,
  };
}
```

### 5. Create API Client with Token Injection

Create `src/lib/apiClient.ts`:

```typescript
import { PublicClientApplication } from '@azure/msal-browser';
import { loginRequest, msalConfig } from '../authConfig';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL;

let msalInstance: PublicClientApplication | null = null;

export function initApiClient(instance: PublicClientApplication) {
  msalInstance = instance;
}

async function getAccessToken(): Promise<string | null> {
  if (!msalInstance) {
    return null;
  }

  const accounts = msalInstance.getAllAccounts();
  if (accounts.length === 0) {
    return null;
  }

  try {
    const response = await msalInstance.acquireTokenSilent({
      ...loginRequest,
      account: accounts[0],
    });
    return response.accessToken;
  } catch (error) {
    console.error('Failed to acquire token:', error);
    return null;
  }
}

export async function apiCall<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const token = await getAccessToken();

  const headers: HeadersInit = {
    'Content-Type': 'application/json',
    ...options.headers,
  };

  // Add Authorization header if token is available
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const response = await fetch(`${API_BASE_URL}${endpoint}`, {
    ...options,
    headers,
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`API call failed: ${response.status} - ${error}`);
  }

  return response.json();
}

// Convenience methods
export const api = {
  get: <T>(endpoint: string) => apiCall<T>(endpoint, { method: 'GET' }),

  post: <T>(endpoint: string, data: any) =>
    apiCall<T>(endpoint, {
      method: 'POST',
      body: JSON.stringify(data),
    }),

  put: <T>(endpoint: string, data: any) =>
    apiCall<T>(endpoint, {
      method: 'PUT',
      body: JSON.stringify(data),
    }),

  delete: <T>(endpoint: string) => apiCall<T>(endpoint, { method: 'DELETE' }),
};
```

### 6. Update App Component

Update `src/App.tsx` to include authentication:

```typescript
import { useMsal } from '@azure/msal-react';
import { useEffect } from 'react';
import { useAuth } from './hooks/useAuth';
import { initApiClient } from './lib/apiClient';
import AppPage from './pages/AppPage';
import Landing from './pages/Landing';

function App() {
  const { instance } = useMsal();
  const { isAuthenticated, user, login, logout } = useAuth();

  // Initialize API client with MSAL instance
  useEffect(() => {
    initApiClient(instance);
  }, [instance]);

  return (
    <div className="App">
      {/* Authentication UI - example */}
      <nav className="auth-nav">
        {isAuthenticated ? (
          <div>
            <span>Welcome, {user?.name || user?.username}</span>
            <button onClick={logout}>Sign Out</button>
          </div>
        ) : (
          <button onClick={login}>Sign In</button>
        )}
      </nav>

      {/* Your app content - accessible regardless of auth status */}
      <AppPage />
    </div>
  );
}

export default App;
```

### 7. Using API with Authentication

Example component that calls protected API:

```typescript
import { useState } from 'react';
import { api } from '../lib/apiClient';
import { useAuth } from '../hooks/useAuth';

interface UserInfo {
  email: string;
  objectId: string;
  name: string;
  groups: string[];
  roles: string[];
}

function UserProfile() {
  const { isAuthenticated, login } = useAuth();
  const [userInfo, setUserInfo] = useState<UserInfo | null>(null);
  const [error, setError] = useState<string | null>(null);

  const fetchUserInfo = async () => {
    if (!isAuthenticated) {
      await login();
      return;
    }

    try {
      const data = await api.get<UserInfo>('/api/user/me');
      setUserInfo(data);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch user info');
    }
  };

  return (
    <div>
      <button onClick={fetchUserInfo}>
        {isAuthenticated ? 'Load My Profile' : 'Sign In to View Profile'}
      </button>

      {error && <p style={{ color: 'red' }}>{error}</p>}

      {userInfo && (
        <div>
          <h2>User Profile</h2>
          <p>Name: {userInfo.name}</p>
          <p>Email: {userInfo.email}</p>
          <p>Object ID: {userInfo.objectId}</p>
          <p>Groups: {userInfo.groups.length}</p>
          <p>Roles: {userInfo.roles.join(', ') || 'None'}</p>
        </div>
      )}
    </div>
  );
}

export default UserProfile;
```

## Testing Locally

1. **Get Azure AD Configuration**:
   ```bash
   cd infra/core
   terraform output azure_ad_client_id
   terraform output azure_ad_tenant_id
   ```

2. **Set Environment Variables**:
   Create `services/ui/.env.local` with the values from step 1

3. **Update Azure AD Redirect URIs** (if not already done):
   - Add `http://localhost:5173` to redirect URIs in Azure AD App Registration
   - Already configured in Terraform: `infra/core/azure-ad.tf`

4. **Run UI Locally**:
   ```bash
   cd services/ui
   npm install
   npm run dev
   ```

5. **Test Authentication Flow**:
   - Open http://localhost:5173
   - UI should load without authentication
   - Click "Sign In" → Should redirect to Azure AD login
   - After login → Should receive JWT token
   - Call `/api/hello` → Should succeed with token
   - Call `/api/user/me` → Should return your user info with groups/roles

## Production Deployment

1. **Environment Variables**: Set in your deployment pipeline or Container App environment variables
2. **Redirect URIs**: Already configured for App Gateway IP in `azure-ad.tf`
3. **CORS**: Already configured in APIM policy

## Important Notes

1. **Token Storage**: Tokens are stored in sessionStorage by default. Consider localStorage for persistent sessions.

2. **Token Refresh**: MSAL automatically refreshes tokens using refresh tokens. Use `acquireTokenSilent()` which handles this.

3. **Error Handling**: Handle `InteractionRequiredAuthError` when tokens expire or consent is needed.

4. **Security**:
   - Never store tokens in localStorage if you're concerned about XSS attacks
   - Always use HTTPS in production
   - Set appropriate token lifetimes in Azure AD

5. **Groups**: Azure AD returns group GUIDs, not names. You may need to map these to friendly names or use Directory.Read.All permission to fetch group names.

## Troubleshooting

### Common Issues

1. **CORS Errors**: Ensure your App Gateway IP and localhost are in the APIM CORS policy
2. **Redirect URI Mismatch**: Check that redirect URIs in code match Azure AD App Registration
3. **Token Not Sent**: Verify `getAccessToken()` is being called before API requests
4. **401 Unauthorized**: Check that the audience claim in token matches your Client ID

### Debug Tips

```typescript
// Log token claims to console
const response = await instance.acquireTokenSilent(loginRequest);
console.log('Token claims:', response.account);
console.log('Access Token:', response.accessToken);

// Decode JWT (for debugging only)
const base64Url = response.accessToken.split('.')[1];
const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
const payload = JSON.parse(window.atob(base64));
console.log('Token payload:', payload);
```

## Next Steps

1. Deploy the infrastructure changes: `cd infra/core && terraform apply`
2. Get the Client ID and Tenant ID from Terraform outputs
3. Install MSAL packages: `npm install @azure/msal-browser @azure/msal-react`
4. Implement the authentication setup following this guide
5. Test locally with `npm run dev`
6. Deploy UI with authentication: `cd services/ui && ./deploy.sh`

## References

- [MSAL.js Documentation](https://github.com/AzureAD/microsoft-authentication-library-for-js/tree/dev/lib/msal-browser)
- [MSAL React Documentation](https://github.com/AzureAD/microsoft-authentication-library-for-js/tree/dev/lib/msal-react)
- [Azure AD Authentication Flows](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-auth-code-flow)
- [SPA Authorization Code Flow with PKCE](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-auth-code-flow#spa-authorization-code-flow)

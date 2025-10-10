# Azure AD App Registration - Terraform Managed

This document explains the Azure AD App Registration that is automatically created by Terraform for JWT validation in APIM.

## Overview

The Terraform configuration in `azure-ad.tf` automatically creates and manages:
1. **Azure AD Application Registration** - For authentication
2. **Service Principal** - For the application to run
3. **API Permissions** - Microsoft Graph permissions for user info

## What Gets Created

### 1. Application Registration

**Name:** `app-{resource_name_prefix}-{environment}`

**Example:** `app-core-dev`

**Purpose:**
- Issues JWT tokens for authenticated users
- Validates user authentication via Azure AD
- Provides user claims (email, name, object ID)

### 2. Permissions Configured

The app registration automatically requests these Microsoft Graph permissions:

- `User.Read` - Read user profile
- `openid` - OpenID Connect sign-in
- `offline_access` - Refresh tokens
- `email` - Read user email address
- `profile` - Read user profile information

### 3. API Scope Exposed

The app exposes a custom API scope:

- **Scope:** `api.access`
- **Purpose:** Allow applications to access the API on behalf of users
- **Consent:** User consent required

## How It Works with APIM

1. User authenticates with Azure AD and gets a JWT token
2. User includes token in `Authorization: Bearer <token>` header
3. APIM validates the token using the app registration's configuration
4. APIM extracts user claims and forwards them as headers to backend services

## Token Validation

APIM validates JWT tokens against:
- **Tenant ID:** Your Azure AD tenant (automatically detected)
- **Client ID:** The application's client ID (automatically created)
- **Issuer:** `https://login.microsoftonline.com/{tenant_id}/v2.0`
- **Audience:** The application's client ID

## User Claims Forwarded to Backend

After successful validation, APIM adds these headers to backend requests:

```http
X-User-Email: user@example.com
X-User-OID: 00000000-0000-0000-0000-000000000000
X-User-Name: John Doe
```

## Getting Authentication Tokens

### For Testing (Using Azure CLI)

```bash
# Get an access token for your app
az account get-access-token --resource <client-id> --query accessToken -o tsv
```

### For Web Applications

```javascript
// Using MSAL.js
import { PublicClientApplication } from '@azure/msal-browser';

const msalConfig = {
  auth: {
    clientId: '<your-client-id>', // Get from Terraform output
    authority: 'https://login.microsoftonline.com/<tenant-id>',
    redirectUri: window.location.origin
  }
};

const msalInstance = new PublicClientApplication(msalConfig);

// Login
const loginRequest = {
  scopes: ['api://<client-id>/api.access']
};

const response = await msalInstance.loginPopup(loginRequest);
const accessToken = response.accessToken;
```

### For Mobile/Desktop Applications

Use the appropriate MSAL library:
- **iOS/macOS:** MSAL for iOS
- **Android:** MSAL for Android
- **.NET:** MSAL.NET
- **Node.js:** @azure/msal-node

## Terraform Outputs

After deployment, you can get the App Registration details:

```bash
# Get the Client ID
terraform output azure_ad_application_id

# Get the Tenant ID
terraform output azure_ad_tenant_id

# Get the Application Name
terraform output azure_ad_application_name

# Get the Service Principal Object ID
terraform output azure_ad_service_principal_id
```

## Manual Configuration (If Needed)

If you need to add additional permissions or configure advanced settings:

1. Go to **Azure Portal** → **Azure Active Directory** → **App registrations**
2. Find the app: `app-{resource_name_prefix}-{environment}`
3. Configure as needed:
   - **Authentication** → Add redirect URIs
   - **Certificates & secrets** → Add client secrets (if needed)
   - **API permissions** → Add more permissions
   - **Token configuration** → Add optional claims

## Security Considerations

### Public Client vs Confidential Client

The current configuration is suitable for:
- ✅ Single Page Applications (SPA)
- ✅ Mobile applications
- ✅ Desktop applications

For server-side applications that need client secrets:
- Add `client_secret` configuration
- Store secret in Key Vault
- Never commit secrets to source control

### Token Lifetime

Default token lifetimes:
- **Access Token:** 1 hour
- **Refresh Token:** 90 days (if offline_access granted)

To customize token lifetimes:
1. Go to **Azure AD** → **App registrations** → Your app
2. **Token configuration** → Configure token lifetime policies

### Multi-Tenant Applications

Current configuration is single-tenant (your organization only).

To support users from other organizations:
- Change `signInAudience` in app registration
- Update APIM policy to accept tokens from multiple tenants

## Troubleshooting

### Token Validation Fails

**Check:**
1. Token audience matches the client ID
2. Token issuer matches `https://login.microsoftonline.com/{tenant_id}/v2.0`
3. Token is not expired
4. User has consented to required permissions

**Debug:**
```bash
# Decode JWT token to inspect claims
echo "<token>" | cut -d. -f2 | base64 -d | jq
```

### Missing User Claims

Some claims require admin consent or additional configuration:
- `email` - Requires email claim in token configuration
- `name` - Requires profile scope
- `oid` - Always included (user's object ID)

### Permission Issues

If users can't consent to permissions:
1. Go to **Azure AD** → **App registrations** → Your app
2. **API permissions** → Click "Grant admin consent"
3. Admin grants consent on behalf of all users

## Integration with Frontend

### Example: React with MSAL

```typescript
// App.tsx
import { MsalProvider } from '@azure/msal-react';
import { PublicClientApplication } from '@azure/msal-browser';

const msalConfig = {
  auth: {
    clientId: process.env.REACT_APP_AZURE_CLIENT_ID!,
    authority: `https://login.microsoftonline.com/${process.env.REACT_APP_AZURE_TENANT_ID}`,
    redirectUri: window.location.origin
  }
};

const pca = new PublicClientApplication(msalConfig);

function App() {
  return (
    <MsalProvider instance={pca}>
      {/* Your app components */}
    </MsalProvider>
  );
}
```

### Making Authenticated API Calls

```typescript
import { useMsal } from '@azure/msal-react';

function MyComponent() {
  const { instance, accounts } = useMsal();

  const callAPI = async () => {
    const request = {
      scopes: [`api://${process.env.REACT_APP_AZURE_CLIENT_ID}/api.access`],
      account: accounts[0]
    };

    const response = await instance.acquireTokenSilent(request);

    // Call your API with the token
    const apiResponse = await fetch('https://your-apim-url/api/endpoint', {
      headers: {
        'Authorization': `Bearer ${response.accessToken}`
      }
    });

    return apiResponse.json();
  };

  return (
    <button onClick={callAPI}>Call Protected API</button>
  );
}
```

## Environment Variables for Frontend

Set these in your UI application:

```env
REACT_APP_AZURE_CLIENT_ID=<from terraform output>
REACT_APP_AZURE_TENANT_ID=<from terraform output>
VITE_AZURE_CLIENT_ID=<from terraform output>  # For Vite
VITE_AZURE_TENANT_ID=<from terraform output>
```

Get values from Terraform:
```bash
terraform output azure_ad_application_id
terraform output azure_ad_tenant_id
```

## Resources

- [Azure AD App Registration Documentation](https://learn.microsoft.com/azure/active-directory/develop/quickstart-register-app)
- [MSAL.js Documentation](https://learn.microsoft.com/azure/active-directory/develop/msal-overview)
- [APIM JWT Validation Policy](https://learn.microsoft.com/azure/api-management/api-management-access-restriction-policies#ValidateJWT)
- [Azure AD Token Claims](https://learn.microsoft.com/azure/active-directory/develop/access-tokens)

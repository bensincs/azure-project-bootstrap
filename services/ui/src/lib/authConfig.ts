import type { UserManagerSettings } from "oidc-client-ts";

// Auth configuration from environment variables
// Set by deploy.sh in production, falls back to defaults for local development
const clientId =
  import.meta.env.VITE_AUTH_CLIENT_ID || "0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2";
const tenantId =
  import.meta.env.VITE_AUTH_TENANT_ID || "cab08f14-2b61-43ee-8ebe-16acd8e371bf";

// Get the current URL for redirect URIs
const getRedirectUri = () => {
  const origin = window.location.origin;
  return `${origin}/auth/callback`;
};

export const oidcConfig: UserManagerSettings = {
  authority: `https://login.microsoftonline.com/${tenantId}/v2.0`,
  client_id: clientId,
  redirect_uri: getRedirectUri(),
  post_logout_redirect_uri: getRedirectUri(),
  response_type: "code",
  // Request token for your API using the exposed scope
  // This will give you an access token with audience = your clientId
  scope: `api://${clientId}/api.access openid profile email`,
  automaticSilentRenew: true,
  // Don't load userinfo from Graph - we get user info from token claims
  loadUserInfo: false,
};

/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_WS_URL?: string;
  readonly VITE_API_URL?: string;
  readonly VITE_NOTIFY_URL?: string;
  readonly VITE_AUTH_CLIENT_ID?: string;
  readonly VITE_AUTH_TENANT_ID?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

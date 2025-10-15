import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./App.tsx";
import { AuthProvider } from "./hooks/useAuth";
import { oidcConfig } from "./lib/authConfig";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <AuthProvider config={oidcConfig}>
      <App />
    </AuthProvider>
  </StrictMode>
);

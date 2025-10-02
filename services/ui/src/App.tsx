import { BrowserRouter, Routes, Route } from "react-router-dom";
import Landing from "./pages/Landing";
import AppPage from "./pages/AppPage";
import { useNotifications } from "./hooks/useNotifications";
import { NotificationContainer } from "./components/NotificationToast";

// WebSocket URL - automatically set by deploy.sh in production
// Falls back to localhost for local development
const WS_URL = import.meta.env.VITE_WS_URL || "ws://localhost:3001/ws";

export default function App() {
  const { notifications, isConnected, dismissNotification } =
    useNotifications(WS_URL);

  return (
    <BrowserRouter>
      <NotificationContainer
        notifications={notifications}
        isConnected={isConnected}
        onDismiss={dismissNotification}
      />
      <Routes>
        <Route path="/" element={<Landing />} />
        <Route path="/app" element={<AppPage />} />
      </Routes>
    </BrowserRouter>
  );
}

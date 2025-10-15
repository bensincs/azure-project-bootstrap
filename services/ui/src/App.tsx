import { BrowserRouter, Routes, Route } from "react-router-dom";
import Landing from "./pages/Landing";
import AppPage from "./pages/AppPage";
import { AuthCallback } from "./pages/AuthCallback";
import { EventsProvider } from "./hooks/useEvents";

export default function App() {
  return (
    <BrowserRouter>
      <EventsProvider>
        <Routes>
          <Route path="/" element={<Landing />} />
          <Route path="/app" element={<AppPage />} />
          <Route path="/auth/callback" element={<AuthCallback />} />
        </Routes>
      </EventsProvider>
    </BrowserRouter>
  );
}

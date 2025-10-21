import { BrowserRouter, Routes, Route } from "react-router-dom";
import Landing from "./pages/Landing";
import AppPage from "./pages/AppPage";
import AIChatPage from "./pages/AIChatPage";
import VideoChat from "./pages/VideoChat";
import { AuthCallback } from "./pages/AuthCallback";
import { EventsProvider } from "./hooks/useEvents";

export default function App() {
  return (
    <BrowserRouter>
      <EventsProvider>
        <Routes>
          <Route path="/" element={<Landing />} />
          <Route path="/app" element={<AppPage />} />
          <Route path="/ai-chat" element={<AIChatPage />} />
          <Route path="/video-chat" element={<VideoChat />} />
          <Route path="/auth/callback" element={<AuthCallback />} />
        </Routes>
      </EventsProvider>
    </BrowserRouter>
  );
}

import { useEffect, useState } from "react";
import AnimatedBackground from "../components/AnimatedBackground";
import { useAuth } from "../hooks/useAuth";
import { useEvents, type ChatEvent, type UserEvent } from "../hooks/useEvents";
import { LoginButton } from "../components/LoginButton";

interface Notification {
  id: string;
  title: string;
  message: string;
  type: "info" | "success" | "warning" | "error";
  timestamp: string;
}

interface ActiveUser {
  id: string;
  name: string;
  email: string;
}

interface ChatMessage {
  type: string;
  from: string;
  name: string;
  email: string;
  content: string;
  timestamp?: number;
}

export default function AppPage() {
  const { user } = useAuth();
  const { connectionStatus, subscribe } = useEvents();
  const [activeUsers, setActiveUsers] = useState<ActiveUser[]>([]);
  const [selectedUser, setSelectedUser] = useState<ActiveUser | null>(null);
  const [messageInput, setMessageInput] = useState("");
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [sendingMessage, setSendingMessage] = useState(false);

  const apiUrl = import.meta.env.VITE_API_URL || "http://localhost:8080/api";

  // Fetch active users
  const fetchActiveUsers = async () => {
    if (!user) return;

    try {
      const response = await fetch(`${apiUrl}/users/active`, {
        headers: {
          Authorization: `Bearer ${user.access_token}`,
        },
      });

      if (response.ok) {
        const data = await response.json();
        setActiveUsers(data.users || []);
      }
    } catch (error) {
      console.error("Failed to fetch active users:", error);
    }
  };

  // Subscribe to events
  useEffect(() => {
    const unsubChat = subscribe("chat", (event) => {
      const chatEvent = event as ChatEvent;
      setMessages((prev) => [
        ...prev,
        {
          type: "chat",
          from: chatEvent.payload.from,
          name: chatEvent.payload.name,
          email: chatEvent.payload.email,
          content: chatEvent.payload.content,
          timestamp: Date.now(),
        },
      ]);
    });

    const unsubUserJoined = subscribe("user_joined", (event) => {
      console.log("User joined:", event);
      fetchActiveUsers();
    });

    const unsubUserLeft = subscribe("user_left", (event) => {
      console.log("User left:", event);
      fetchActiveUsers();
    });

    return () => {
      unsubChat();
      unsubUserJoined();
      unsubUserLeft();
    };
  }, [subscribe]);

  // Fetch active users when connected
  useEffect(() => {
    console.log(connectionStatus);
    if (connectionStatus === "connected") {
      fetchActiveUsers();
    }
  }, [connectionStatus]);

  // Refresh active users periodically
  useEffect(() => {
    if (!user || connectionStatus !== "connected") return;

    const interval = setInterval(fetchActiveUsers, 5000);
    return () => clearInterval(interval);
  }, [user, connectionStatus]);

  // Send message via REST API
  const handleSendMessage = async () => {
    if (!user || !selectedUser || !messageInput.trim()) return;

    setSendingMessage(true);

    try {
      const response = await fetch(`${apiUrl}/messages/send`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${user.access_token}`,
        },
        body: JSON.stringify({
          to: selectedUser.id,
          content: messageInput.trim(),
        }),
      });

      if (response.ok) {
        // Add to local messages as "sent"
        setMessages((prev) => [
          ...prev,
          {
            type: "chat",
            from: user.profile.sub || "",
            name: user.profile.name || "",
            email: user.profile.email || "",
            content: messageInput.trim(),
            timestamp: Date.now(),
          },
        ]);
        setMessageInput("");
      } else {
        console.error("Failed to send message");
      }
    } catch (error) {
      console.error("Error sending message:", error);
    } finally {
      setSendingMessage(false);
    }
  };

  return (
    <div className="relative min-h-screen overflow-hidden">
      <AnimatedBackground />
      <div className="relative z-10 px-6 pb-20 pt-10">
        <header className="mx-auto flex w-full max-w-6xl flex-col gap-4">
          <div className="flex flex-col gap-2 sm:flex-row sm:items-baseline sm:justify-between">
            <div>
              <p className="text-xs uppercase tracking-[0.35em] text-slate-500">
                Realtime Chat
              </p>
              <h1 className="text-3xl font-semibold text-white">
                Direct Messages
              </h1>
            </div>
            <p className="max-w-sm text-sm text-slate-400">
              Send messages to connected users in real-time via WebSocket
            </p>
          </div>

          {/* Login & Connection Status */}
          <div className="rounded-2xl border border-white/10 bg-black/40 p-4 backdrop-blur">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div>
                  <p className="text-xs uppercase tracking-[0.3em] text-slate-500">
                    {user ? "Connected as" : "Authentication"}
                  </p>
                  {user ? (
                    <p className="mt-1 text-sm text-white">
                      <span className="font-semibold">
                        {user.profile.name || user.profile.email}
                      </span>
                    </p>
                  ) : (
                    <p className="mt-1 text-sm text-slate-400">
                      Sign in to start chatting
                    </p>
                  )}
                </div>
                {user && (
                  <div className="flex items-center gap-2">
                    <div
                      className={`h-2 w-2 rounded-full ${
                        connectionStatus === "connected"
                          ? "bg-emerald-400"
                          : connectionStatus === "connecting"
                          ? "bg-yellow-400 animate-pulse"
                          : "bg-slate-500"
                      }`}
                    />
                    <span className="text-xs text-slate-400">
                      {connectionStatus}
                    </span>
                  </div>
                )}
              </div>
              <LoginButton />
            </div>
          </div>
        </header>

        {!user ? (
          <main className="mx-auto mt-12 w-full max-w-6xl">
            <div className="rounded-3xl border border-white/10 bg-black/40 p-12 text-center shadow-neon backdrop-blur">
              <p className="text-lg text-slate-300">
                🔒 Please sign in to start using the chat
              </p>
            </div>
          </main>
        ) : (
          <main className="mx-auto mt-12 grid w-full max-w-6xl grid-cols-1 gap-6 lg:grid-cols-3">
            {/* Active Users List */}
            <section className="rounded-3xl border border-white/10 bg-black/40 p-6 shadow-neon backdrop-blur lg:col-span-1">
              <div className="flex items-center justify-between">
                <h2 className="text-lg font-semibold text-white">
                  Active Users
                </h2>
                <span className="rounded-full bg-cyan-500/20 px-2 py-1 text-xs font-semibold text-cyan-300">
                  {activeUsers.length}
                </span>
              </div>
              <p className="mt-1 text-xs text-slate-400">
                Currently connected via WebSocket
              </p>

              <div className="mt-6 space-y-2">
                {activeUsers.length === 0 ? (
                  <p className="text-sm text-slate-500">
                    No other users connected
                  </p>
                ) : (
                  activeUsers.map((u) => (
                    <button
                      key={u.id}
                      onClick={() => setSelectedUser(u)}
                      className={`w-full rounded-2xl border p-3 text-left transition ${
                        selectedUser?.id === u.id
                          ? "border-cyan-400/70 bg-cyan-500/10"
                          : "border-white/10 bg-white/5 hover:border-cyan-400/30 hover:bg-white/10"
                      }`}
                    >
                      <div className="font-medium text-white">{u.name}</div>
                      <div className="mt-1 text-xs text-slate-400">
                        {u.email}
                      </div>
                    </button>
                  ))
                )}
              </div>
            </section>

            {/* Chat Area */}
            <section className="rounded-3xl border border-white/10 bg-black/40 p-6 shadow-neon backdrop-blur lg:col-span-2">
              {!selectedUser ? (
                <div className="flex h-full items-center justify-center">
                  <p className="text-slate-400">
                    👈 Select a user to start chatting
                  </p>
                </div>
              ) : (
                <div className="flex h-full flex-col">
                  <div className="border-b border-white/10 pb-4">
                    <h2 className="text-lg font-semibold text-white">
                      {selectedUser.name}
                    </h2>
                    <p className="text-xs text-slate-400">
                      {selectedUser.email}
                    </p>
                  </div>

                  {/* Messages */}
                  <div className="flex-1 space-y-3 overflow-y-auto py-4">
                    {messages
                      .filter(
                        (msg) =>
                          msg.from === selectedUser.id ||
                          msg.from === user.profile.sub
                      )
                      .map((msg, idx) => {
                        const isFromMe = msg.from === user.profile.sub;
                        return (
                          <div
                            key={idx}
                            className={`flex ${
                              isFromMe ? "justify-end" : "justify-start"
                            }`}
                          >
                            <div
                              className={`max-w-[70%] rounded-2xl px-4 py-2 ${
                                isFromMe
                                  ? "bg-cyan-500/20 text-cyan-100"
                                  : "bg-white/10 text-white"
                              }`}
                            >
                              <p className="text-sm">{msg.content}</p>
                              <p className="mt-1 text-xs opacity-60">
                                {msg.timestamp
                                  ? new Date(msg.timestamp).toLocaleTimeString()
                                  : ""}
                              </p>
                            </div>
                          </div>
                        );
                      })}
                    {messages.filter(
                      (msg) =>
                        msg.from === selectedUser.id ||
                        msg.from === user.profile.sub
                    ).length === 0 && (
                      <p className="text-center text-sm text-slate-500">
                        No messages yet. Start the conversation!
                      </p>
                    )}
                  </div>

                  {/* Message Input */}
                  <div className="border-t border-white/10 pt-4">
                    <div className="flex gap-2">
                      <input
                        type="text"
                        value={messageInput}
                        onChange={(e) => setMessageInput(e.target.value)}
                        onKeyPress={(e) =>
                          e.key === "Enter" && handleSendMessage()
                        }
                        placeholder="Type a message..."
                        className="flex-1 rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder-slate-500 outline-none transition focus:border-cyan-400/70 focus:ring-2 focus:ring-cyan-400/30"
                      />
                      <button
                        onClick={handleSendMessage}
                        disabled={sendingMessage || !messageInput.trim()}
                        className="rounded-2xl bg-cyan-500/20 px-6 py-3 text-sm font-semibold text-cyan-300 transition hover:bg-cyan-500/30 disabled:cursor-not-allowed disabled:opacity-50"
                      >
                        {sendingMessage ? "Sending..." : "Send"}
                      </button>
                    </div>
                  </div>
                </div>
              )}
            </section>
          </main>
        )}
      </div>
    </div>
  );
}

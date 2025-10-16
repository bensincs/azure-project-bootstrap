import { useState, useEffect, useRef } from "react";
import { Link, useNavigate } from "react-router-dom";
import AnimatedBackground from "../components/AnimatedBackground";
import { useAuth } from "../hooks/useAuth";

interface ChatMessage {
  role: "user" | "assistant";
  content: string;
  timestamp: string;
}

export default function AIChatPage() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [inputMessage, setInputMessage] = useState("");
  const [loading, setLoading] = useState(false);
  const [loadingHistory, setLoadingHistory] = useState(true);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const typingIntervalRef = useRef<number | null>(null);
  const fullContentRef = useRef<string>("");
  const currentIndexRef = useRef<number>(0);

  const aiChatUrl = import.meta.env.VITE_AI_CHAT_URL;

  // Redirect to landing if not authenticated
  useEffect(() => {
    if (!user) {
      navigate("/");
    }
  }, [user, navigate]);

  // Scroll to bottom when messages change
  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  // Load chat history on mount
  useEffect(() => {
    loadHistory();
  }, []);

  // Cleanup typing animation on unmount
  useEffect(() => {
    return () => {
      if (typingIntervalRef.current !== null) {
        clearInterval(typingIntervalRef.current);
      }
    };
  }, []);

  const loadHistory = async () => {
    if (!user) return;

    try {
      setLoadingHistory(true);
      const response = await fetch(`${aiChatUrl}/chat/history`, {
        headers: {
          Authorization: `Bearer ${user.access_token}`,
        },
      });

      if (response.ok) {
        const history = await response.json();
        setMessages(history);
      }
    } catch (error) {
      console.error("Failed to load chat history:", error);
    } finally {
      setLoadingHistory(false);
    }
  };

  const sendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!inputMessage.trim() || !user || loading) return;

    const userMessage = inputMessage.trim();
    setInputMessage("");
    setLoading(true);

    // Clear any previous typing animation
    if (typingIntervalRef.current !== null) {
      clearInterval(typingIntervalRef.current);
      typingIntervalRef.current = null;
    }

    // Add user message to UI immediately
    const newUserMessage: ChatMessage = {
      role: "user",
      content: userMessage,
      timestamp: new Date().toISOString(),
    };
    setMessages((prev) => [...prev, newUserMessage]);

    // Create placeholder for assistant message
    const assistantMessageIndex = messages.length + 1;
    const assistantMessage: ChatMessage = {
      role: "assistant",
      content: "",
      timestamp: new Date().toISOString(),
    };
    setMessages((prev) => [...prev, assistantMessage]);

    // Reset refs for typing animation
    fullContentRef.current = "";
    currentIndexRef.current = 0;

    // Start typing animation
    const startTyping = () => {
      typingIntervalRef.current = window.setInterval(() => {
        if (currentIndexRef.current < fullContentRef.current.length) {
          currentIndexRef.current += 1;

          setMessages((prev) => {
            const newMessages = [...prev];
            if (newMessages[assistantMessageIndex]) {
              newMessages[assistantMessageIndex] = {
                ...newMessages[assistantMessageIndex],
                content: fullContentRef.current.substring(
                  0,
                  currentIndexRef.current
                ),
              };
            }
            return newMessages;
          });
        }
      }, 15); // 30ms per character for smooth typing effect
    };

    startTyping();

    try {
      const response = await fetch(`${aiChatUrl}/chat/stream`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${user.access_token}`,
        },
        body: JSON.stringify({ message: userMessage }),
      });

      if (!response.ok) {
        throw new Error("Failed to send message");
      }

      const reader = response.body?.getReader();
      const decoder = new TextDecoder();

      if (!reader) {
        throw new Error("No reader available");
      }

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const chunk = decoder.decode(value);
        const lines = chunk.split("\n");

        for (const line of lines) {
          if (line.startsWith("data: ")) {
            const data = line.slice(6);
            try {
              const parsed = JSON.parse(data);
              if (parsed.done) {
                break;
              }
              if (parsed.content) {
                // Add to full content buffer for typing animation
                fullContentRef.current += parsed.content;
              }
            } catch (e) {
              // Ignore parsing errors for incomplete chunks
            }
          }
        }
      }

      // Wait for typing to finish
      const waitForTyping = setInterval(() => {
        if (currentIndexRef.current >= fullContentRef.current.length) {
          clearInterval(waitForTyping);
          if (typingIntervalRef.current !== null) {
            clearInterval(typingIntervalRef.current);
            typingIntervalRef.current = null;
          }
        }
      }, 100);
    } catch (error) {
      console.error("Error sending message:", error);
      // Clear typing animation
      if (typingIntervalRef.current !== null) {
        clearInterval(typingIntervalRef.current);
        typingIntervalRef.current = null;
      }
      // Update the placeholder with error message
      setMessages((prev) => {
        const newMessages = [...prev];
        newMessages[assistantMessageIndex] = {
          role: "assistant",
          content: "Sorry, I encountered an error. Please try again.",
          timestamp: new Date().toISOString(),
        };
        return newMessages;
      });
    } finally {
      setLoading(false);
    }
  };

  const clearHistory = async () => {
    if (!user || !confirm("Are you sure you want to clear your chat history?"))
      return;

    try {
      const response = await fetch(`${aiChatUrl}/chat/history`, {
        method: "DELETE",
        headers: {
          Authorization: `Bearer ${user.access_token}`,
        },
      });

      if (response.ok) {
        setMessages([]);
      }
    } catch (error) {
      console.error("Failed to clear history:", error);
    }
  };

  if (!user) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-blue-900 via-purple-900 to-pink-900 flex items-center justify-center">
        <AnimatedBackground />
        <div className="relative z-10 text-center">
          <h1 className="text-4xl font-bold text-white mb-4">Redirecting...</h1>
          <p className="text-white/80 mb-8">Please sign in to use AI Chat</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen">
      <AnimatedBackground />

      <div className="relative z-10 container mx-auto px-4 py-8 h-screen flex flex-col">
        {/* Header */}
        <div className="bg-white/10 backdrop-blur-md rounded-t-2xl p-6 border-b border-white/20">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold text-white mb-2">
                AI Assistant
              </h1>
              <p className="text-white/80">Powered by GPT-5 mini</p>
            </div>
            <div className="flex gap-3">
              <Link
                to="/"
                className="px-4 py-2 bg-white/10 hover:bg-white/20 text-white rounded-lg transition-all"
              >
                ← Home
              </Link>
              <button
                onClick={loadHistory}
                disabled={loadingHistory}
                className="px-4 py-2 bg-white/10 hover:bg-white/20 text-white rounded-lg transition-all disabled:opacity-50"
              >
                {loadingHistory ? "Loading..." : "Refresh"}
              </button>
              <button
                onClick={clearHistory}
                className="px-4 py-2 bg-red-500/80 hover:bg-red-600 text-white rounded-lg transition-all"
              >
                Clear History
              </button>
            </div>
          </div>
        </div>

        {/* Messages */}
        <div className="flex-1 bg-white/5 backdrop-blur-md overflow-y-auto p-6 space-y-4">
          {loadingHistory ? (
            <div className="flex items-center justify-center h-full">
              <div className="text-white/60">Loading chat history...</div>
            </div>
          ) : messages.length === 0 ? (
            <div className="flex items-center justify-center h-full">
              <div className="text-center">
                <div className="text-6xl mb-4">💬</div>
                <p className="text-white/60 text-lg">
                  Start a conversation with your AI assistant
                </p>
              </div>
            </div>
          ) : (
            messages.map((message, index) => (
              <div
                key={index}
                className={`flex ${
                  message.role === "user" ? "justify-end" : "justify-start"
                }`}
              >
                <div
                  className={`max-w-[70%] rounded-2xl p-4 ${
                    message.role === "user"
                      ? "bg-blue-500 text-white"
                      : "bg-white/10 text-white border border-white/20"
                  }`}
                >
                  <div className="flex items-start gap-3">
                    <div className="text-2xl flex-shrink-0">
                      {message.role === "user" ? "👤" : "🤖"}
                    </div>
                    <div className="flex-1">
                      <p className="whitespace-pre-wrap break-words">
                        {message.content}
                        {message.role === "assistant" &&
                          loading &&
                          index === messages.length - 1 && (
                            <span className="inline-block w-2 h-4 ml-1 bg-white animate-pulse" />
                          )}
                      </p>
                      <p className="text-xs mt-2 opacity-60">
                        {new Date(message.timestamp).toLocaleTimeString()}
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            ))
          )}
          <div ref={messagesEndRef} />
        </div>

        {/* Input */}
        <form
          onSubmit={sendMessage}
          className="bg-white/10 backdrop-blur-md rounded-b-2xl p-6 border-t border-white/20"
        >
          <div className="flex gap-4">
            <input
              type="text"
              value={inputMessage}
              onChange={(e) => setInputMessage(e.target.value)}
              placeholder="Type your message..."
              disabled={loading}
              className="flex-1 bg-white/10 text-white placeholder-white/40 rounded-xl px-6 py-3 focus:outline-none focus:ring-2 focus:ring-white/50 disabled:opacity-50"
            />
            <button
              type="submit"
              disabled={loading || !inputMessage.trim()}
              className="px-8 py-3 bg-gradient-to-r from-blue-500 to-purple-500 text-white font-semibold rounded-xl hover:from-blue-600 hover:to-purple-600 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? "Sending..." : "Send"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

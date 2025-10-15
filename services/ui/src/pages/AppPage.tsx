import { useState } from "react";
import AnimatedBackground from "../components/AnimatedBackground";
import { useAuth } from "../hooks/useAuth";
import { LoginButton } from "../components/LoginButton";

export default function AppPage() {
  const { user } = useAuth();
  const [message, setMessage] = useState("");
  const [title, setTitle] = useState("");
  const [type, setType] = useState<"info" | "success" | "warning" | "error">(
    "info"
  );
  const [sending, setSending] = useState(false);
  const [status, setStatus] = useState<{
    type: string;
    message: string;
  } | null>(null);

  // API testing state
  const [apiTestResult, setApiTestResult] = useState<any>(null);
  const [apiTestLoading, setApiTestLoading] = useState(false);
  const [testName, setTestName] = useState("World");

  // Get API URL from environment or default to localhost
  const notifyUrl =
    import.meta.env.VITE_NOTIFY_URL || "http://localhost:8080/notify";
  const apiUrl = import.meta.env.VITE_API_URL || "http://localhost:8080/api";

  const handleSendNotification = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!message.trim()) {
      setStatus({ type: "error", message: "Message is required" });
      return;
    }

    setSending(true);
    setStatus(null);

    try {
      const response = await fetch(`${notifyUrl}/broadcast`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: message.trim(),
          title: title.trim() || undefined,
          type,
        }),
      });

      if (!response.ok) {
        throw new Error(`Failed to send notification: ${response.statusText}`);
      }

      const result = await response.json();
      setStatus({
        type: "success",
        message: `Notification sent to ${result.clients} client(s)`,
      });

      // Clear form
      setMessage("");
      setTitle("");
      setType("info");
    } catch (error) {
      console.error("Error sending notification:", error);
      setStatus({
        type: "error",
        message:
          error instanceof Error
            ? error.message
            : "Failed to send notification",
      });
    } finally {
      setSending(false);
    }
  };

  const testApiEndpoint = async (endpoint: string, description: string) => {
    setApiTestLoading(true);
    setApiTestResult(null);

    try {
      // Get the access token if user is logged in
      const headers: HeadersInit = {
        "Content-Type": "application/json",
      };

      if (user) {
        headers["Authorization"] = `Bearer ${user.access_token}`;
      }

      const response = await fetch(`${apiUrl}${endpoint}`, {
        headers,
      });
      const data = await response.json();

      setApiTestResult({
        endpoint,
        description,
        status: response.status,
        statusText: response.ok ? "Success" : "Error",
        data,
        authenticated: !!user,
      });
    } catch (error) {
      setApiTestResult({
        endpoint,
        description,
        status: 0,
        statusText: "Failed",
        error: error instanceof Error ? error.message : "Unknown error",
        authenticated: !!user,
      });
    } finally {
      setApiTestLoading(false);
    }
  };

  return (
    <div className="relative min-h-screen overflow-hidden">
      <AnimatedBackground />
      <div className="relative z-10 px-6 pb-20 pt-10">
        <header className="mx-auto flex w-full max-w-4xl flex-col gap-4">
          <div className="flex flex-col gap-2 sm:flex-row sm:items-baseline sm:justify-between">
            <div>
              <p className="text-xs uppercase tracking-[0.35em] text-slate-500">
                Crew Dune Control
              </p>
              <h1 className="text-3xl font-semibold text-white">
                Control Room
              </h1>
            </div>
            <p className="max-w-sm text-sm text-slate-400">
              Send realtime notifications and verify the API connection that
              powers them.
            </p>
          </div>

          {/* Login Section */}
          <div className="rounded-2xl border border-white/10 bg-black/40 p-4 backdrop-blur">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-xs uppercase tracking-[0.3em] text-slate-500">
                  Authentication
                </p>
                {user ? (
                  <p className="mt-1 text-sm text-white">
                    Logged in as{" "}
                    <span className="font-semibold">
                      {user.profile.name || user.profile.email}
                    </span>
                  </p>
                ) : (
                  <p className="mt-1 text-sm text-slate-400">
                    Sign in to test authenticated endpoints
                  </p>
                )}
              </div>
              <LoginButton />
            </div>
          </div>
        </header>

        <main className="mx-auto mt-12 flex w-full max-w-4xl flex-col gap-10">
          <section className="rounded-3xl border border-white/10 bg-black/40 p-6 shadow-neon backdrop-blur">
            <h2 className="text-xl font-semibold text-white">
              Send a notification
            </h2>
            <p className="mt-2 text-sm text-slate-400">
              Compose a message and broadcast it to every connected client.
            </p>

            <form onSubmit={handleSendNotification} className="mt-6 space-y-6">
              <div className="space-y-2">
                <label
                  htmlFor="title"
                  className="text-xs uppercase tracking-[0.3em] text-slate-500"
                >
                  Title (optional)
                </label>
                <input
                  type="text"
                  id="title"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="e.g. Deployment complete"
                  className="w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder-slate-500 outline-none transition focus:border-cyan-400/70 focus:ring-2 focus:ring-cyan-400/30"
                />
              </div>

              <div className="space-y-2">
                <label
                  htmlFor="message"
                  className="text-xs uppercase tracking-[0.3em] text-slate-500"
                >
                  Message *
                </label>
                <textarea
                  id="message"
                  value={message}
                  onChange={(e) => setMessage(e.target.value)}
                  placeholder="Enter the payload you want to broadcast"
                  rows={4}
                  required
                  className="w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder-slate-500 outline-none transition focus:border-cyan-400/70 focus:ring-2 focus:ring-cyan-400/30"
                />
              </div>

              <div className="space-y-2 sm:flex sm:items-center sm:gap-3 sm:space-y-0">
                <label
                  htmlFor="type"
                  className="text-xs uppercase tracking-[0.3em] text-slate-500 sm:w-32"
                >
                  Type
                </label>
                <select
                  id="type"
                  value={type}
                  onChange={(e) => setType(e.target.value as any)}
                  className="w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white outline-none transition focus:border-cyan-400/70 focus:ring-2 focus:ring-cyan-400/30 sm:flex-1"
                >
                  <option value="info">Info</option>
                  <option value="success">Success</option>
                  <option value="warning">Warning</option>
                  <option value="error">Error</option>
                </select>
              </div>

              {status && (
                <div
                  className={`rounded-2xl border px-4 py-3 text-sm ${
                    status.type === "success"
                      ? "border-emerald-400/40 bg-emerald-500/10 text-emerald-200"
                      : "border-rose-500/40 bg-rose-500/10 text-rose-200"
                  }`}
                >
                  {status.message}
                </div>
              )}

              <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
                <button
                  type="submit"
                  disabled={sending}
                  className="ui-button-plain w-full justify-center sm:w-auto disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {sending ? "Sending…" : "Send notification"}
                </button>
                <p className="text-xs text-slate-500">
                  Endpoint:{" "}
                  <code className="font-mono text-cyan-200">
                    POST /api/notifications/broadcast
                  </code>
                </p>
              </div>
            </form>
          </section>

          {/* API Testing Section */}
          <section className="rounded-3xl border border-white/10 bg-black/40 p-6 shadow-neon backdrop-blur">
            <h2 className="text-xl font-semibold text-white">
              API Endpoint Testing
            </h2>
            <p className="mt-2 text-sm text-slate-400">
              Test various API endpoints to verify connectivity and
              authentication.
            </p>

            <div className="mt-6 grid gap-3 sm:grid-cols-2">
              <button
                onClick={() => testApiEndpoint("/health", "Health Check")}
                disabled={apiTestLoading}
                className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-left text-sm text-white transition hover:border-cyan-400/50 hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-50"
              >
                <div className="font-semibold">Health Check</div>
                <div className="mt-1 text-xs text-slate-400">
                  GET /api/health
                </div>
              </button>

              <button
                onClick={() => testApiEndpoint("/hello", "Hello Endpoint")}
                disabled={apiTestLoading}
                className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-left text-sm text-white transition hover:border-cyan-400/50 hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-50"
              >
                <div className="font-semibold">Hello World</div>
                <div className="mt-1 text-xs text-slate-400">
                  GET /api/hello
                </div>
              </button>

              <button
                onClick={() => testApiEndpoint("/config", "Configuration")}
                disabled={apiTestLoading}
                className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-left text-sm text-white transition hover:border-cyan-400/50 hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-50"
              >
                <div className="font-semibold">Configuration</div>
                <div className="mt-1 text-xs text-slate-400">
                  GET /api/config
                </div>
              </button>

              <button
                onClick={() =>
                  testApiEndpoint(
                    `/hello/${encodeURIComponent(testName)}`,
                    `Hello ${testName}`
                  )
                }
                disabled={apiTestLoading}
                className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-left text-sm text-white transition hover:border-cyan-400/50 hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-50"
              >
                <div className="font-semibold">Hello with Name</div>
                <div className="mt-1 text-xs text-slate-400">
                  GET /api/hello/:name
                </div>
              </button>

              <button
                onClick={() => testApiEndpoint("/user/me", "User Info")}
                disabled={apiTestLoading || !user}
                className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-left text-sm text-white transition hover:border-cyan-400/50 hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-50"
              >
                <div className="font-semibold">User Info {!user && "🔒"}</div>
                <div className="mt-1 text-xs text-slate-400">
                  GET /api/user/me
                </div>
              </button>

              <button
                onClick={() => testApiEndpoint("/admin/test", "Admin Test")}
                disabled={apiTestLoading || !user}
                className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-left text-sm text-white transition hover:border-cyan-400/50 hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-50"
              >
                <div className="font-semibold">Admin Test {!user && "🔒"}</div>
                <div className="mt-1 text-xs text-slate-400">
                  GET /api/admin/test
                </div>
              </button>
            </div>

            {/* Name input for hello/:name endpoint */}
            <div className="mt-4 space-y-2">
              <label
                htmlFor="test-name"
                className="text-xs uppercase tracking-[0.3em] text-slate-500"
              >
                Name for Hello Endpoint
              </label>
              <input
                id="test-name"
                type="text"
                value={testName}
                onChange={(e) => setTestName(e.target.value)}
                placeholder="Enter a name"
                className="w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder-slate-500 outline-none transition focus:border-cyan-400/70 focus:ring-2 focus:ring-cyan-400/30"
              />
              <p className="text-xs text-slate-400">
                This name will be used for the "Hello with Name" endpoint test
              </p>
            </div>

            {apiTestLoading && (
              <div className="mt-6 rounded-2xl border border-cyan-400/40 bg-cyan-500/10 px-4 py-3 text-sm text-cyan-200">
                Testing endpoint...
              </div>
            )}

            {apiTestResult && !apiTestLoading && (
              <div className="mt-6 space-y-3">
                <div className="flex items-center justify-between">
                  <h3 className="text-sm font-semibold text-white">
                    {apiTestResult.description}
                    {apiTestResult.authenticated && (
                      <span className="ml-2 text-xs font-normal text-cyan-300">
                        🔑 Authenticated
                      </span>
                    )}
                  </h3>
                  <span
                    className={`rounded-full px-3 py-1 text-xs font-semibold ${
                      apiTestResult.status >= 200 && apiTestResult.status < 300
                        ? "bg-emerald-500/20 text-emerald-300"
                        : apiTestResult.status >= 400
                        ? "bg-rose-500/20 text-rose-300"
                        : "bg-slate-500/20 text-slate-300"
                    }`}
                  >
                    {apiTestResult.status > 0 ? apiTestResult.status : "Failed"}
                  </span>
                </div>

                <div className="rounded-2xl border border-white/10 bg-black/60 p-4">
                  <pre className="overflow-x-auto text-xs text-slate-300">
                    {JSON.stringify(
                      apiTestResult.data || apiTestResult.error,
                      null,
                      2
                    )}
                  </pre>
                </div>
              </div>
            )}
          </section>
        </main>
      </div>
    </div>
  );
}

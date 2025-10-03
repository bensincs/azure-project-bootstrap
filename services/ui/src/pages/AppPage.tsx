import { useState } from "react";
import HelloWorld from "../components/HelloWorld";
import AnimatedBackground from "../components/AnimatedBackground";

export default function AppPage() {
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

  const apiUrl =
    import.meta.env.VITE_WS_URL?.replace(/^wss?:/, "https:").replace(
      /\/ws$/,
      ""
    ) || "http://localhost:3001";

  const handleSendNotification = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!message.trim()) {
      setStatus({ type: "error", message: "Message is required" });
      return;
    }

    setSending(true);
    setStatus(null);

    try {
      const response = await fetch(`${apiUrl}/api/notifications/broadcast`, {
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

  return (
    <div className="relative min-h-screen overflow-hidden">
      <AnimatedBackground />
      <div className="relative z-10 px-6 pb-20 pt-10">
        <header className="mx-auto flex w-full max-w-4xl flex-col gap-2 sm:flex-row sm:items-baseline sm:justify-between">
          <div>
            <p className="text-xs uppercase tracking-[0.35em] text-slate-500">
              Crew Dune Control
            </p>
            <h1 className="text-3xl font-semibold text-white">Control Room</h1>
          </div>
          <p className="max-w-sm text-sm text-slate-400">
            Send realtime notifications and verify the API connection that
            powers them.
          </p>
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

          <section className="rounded-3xl border border-white/10 bg-black/40 p-6 shadow-neon backdrop-blur">
            <HelloWorld />
          </section>
        </main>
      </div>
    </div>
  );
}

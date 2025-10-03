import { useState } from "react";

interface HelloResponse {
  message: string;
  version: string;
  timestamp: string;
  environment: string;
}

interface HelloWithNameResponse {
  message: string;
  timestamp: string;
}

export default function HelloWorld() {
  const [response, setResponse] = useState<HelloResponse | null>(null);
  const [nameResponse, setNameResponse] =
    useState<HelloWithNameResponse | null>(null);
  const [name, setName] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Get API URL from environment or default to localhost
  const apiUrl = import.meta.env.VITE_API_URL || "http://localhost:8080";

  const fetchHello = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`${apiUrl}/api/hello`);
      if (!res.ok) throw new Error(`HTTP ${res.status}: ${res.statusText}`);
      const data = await res.json();
      setResponse(data);
      setNameResponse(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to fetch");
      setResponse(null);
    } finally {
      setLoading(false);
    }
  };

  const fetchHelloWithName = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;

    setLoading(true);
    setError(null);
    try {
      const res = await fetch(
        `${apiUrl}/api/hello/${encodeURIComponent(name.trim())}`
      );
      if (!res.ok) throw new Error(`HTTP ${res.status}: ${res.statusText}`);
      const data = await res.json();
      setNameResponse(data);
      setResponse(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to fetch");
      setNameResponse(null);
    } finally {
      setLoading(false);
    }
  };

  const latestPayload = response ?? nameResponse;
  const hasPayload = Boolean(latestPayload);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-white">Check the API</h2>
        <p className="mt-2 text-sm text-slate-400">
          Issue a quick ping against the .NET backend and see the JSON surface instantly.
        </p>
      </div>

      <div className="flex flex-wrap gap-3">
        <button
          onClick={fetchHello}
          disabled={loading}
          className="inline-flex items-center rounded-full bg-white/10 px-4 py-2 text-sm font-medium text-white transition hover:bg-white/20 disabled:cursor-not-allowed disabled:opacity-60"
        >
          {loading ? "Calling…" : "Call /api/hello"}
        </button>
      </div>

      <form onSubmit={fetchHelloWithName} className="space-y-3">
        <label htmlFor="hello-name" className="text-xs uppercase tracking-[0.3em] text-slate-500">
          Personal handshake
        </label>
        <div className="flex flex-col gap-3 sm:flex-row">
          <input
            id="hello-name"
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Enter a name"
            className="flex-1 rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder-slate-500 outline-none transition focus:border-cyan-400/70 focus:ring-2 focus:ring-cyan-400/30"
          />
          <button
            type="submit"
            disabled={loading || !name.trim()}
            className="inline-flex items-center justify-center rounded-full bg-cyan-400/70 px-5 py-2 text-sm font-semibold text-slate-950 transition hover:bg-cyan-300 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {loading ? "Sending…" : "Call /api/hello/:name"}
          </button>
        </div>
      </form>

      {error && (
        <div className="rounded-2xl border border-rose-500/40 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">
          <p className="font-medium">Request failed</p>
          <p className="mt-1 text-xs text-rose-100/80">{error}</p>
        </div>
      )}

      <div className="rounded-2xl border border-white/10 bg-white/5 p-5 text-sm text-slate-200">
        <p className="text-xs uppercase tracking-[0.3em] text-slate-500">Latest response</p>
        <div className="glass-divider my-4" />
        {hasPayload ? (
          <pre className="max-h-64 overflow-auto text-sm text-cyan-100">
            {JSON.stringify(latestPayload, null, 2)}
          </pre>
        ) : (
          <p className="text-sm text-slate-400">
            Run either request above to view the JSON payload returned by the API.
          </p>
        )}
      </div>

      <p className="text-xs text-slate-500">
        Base URL: <code className="font-mono text-cyan-200">{apiUrl}</code>
      </p>
    </div>
  );
}

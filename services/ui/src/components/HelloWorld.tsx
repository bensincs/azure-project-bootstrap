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

  return (
    <div className="bg-white rounded-lg shadow p-6 mb-6">
      <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
        <span>🚀</span>
        .NET API Test
      </h2>

      {/* Simple Hello Button */}
      <div className="mb-4">
        <button
          onClick={fetchHello}
          disabled={loading}
          className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
        >
          {loading ? "Loading..." : "Call /api/hello"}
        </button>
      </div>

      {/* Hello with Name Form */}
      <form onSubmit={fetchHelloWithName} className="mb-4">
        <div className="flex gap-2">
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Enter your name"
            className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <button
            type="submit"
            disabled={loading || !name.trim()}
            className="bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
          >
            {loading ? "Loading..." : "Say Hello"}
          </button>
        </div>
      </form>

      {/* Error Display */}
      {error && (
        <div className="mt-4 p-4 bg-red-50 border border-red-200 rounded-md">
          <p className="text-red-800 font-medium">Error:</p>
          <p className="text-red-600 text-sm">{error}</p>
          <p className="text-xs text-gray-500 mt-2">
            Make sure the API is running at: {apiUrl}
          </p>
        </div>
      )}

      {/* Response Display */}
      {response && (
        <div className="mt-4 p-4 bg-green-50 border border-green-200 rounded-md">
          <p className="text-green-800 font-medium mb-2">✅ Response:</p>
          <div className="bg-white p-3 rounded border border-green-100">
            <pre className="text-sm overflow-x-auto">
              {JSON.stringify(response, null, 2)}
            </pre>
          </div>
        </div>
      )}

      {nameResponse && (
        <div className="mt-4 p-4 bg-blue-50 border border-blue-200 rounded-md">
          <p className="text-blue-800 font-medium mb-2">👋 Response:</p>
          <div className="bg-white p-3 rounded border border-blue-100">
            <pre className="text-sm overflow-x-auto">
              {JSON.stringify(nameResponse, null, 2)}
            </pre>
          </div>
        </div>
      )}

      {/* API URL Info */}
      <div className="mt-4 pt-4 border-t border-gray-200">
        <p className="text-xs text-gray-500">
          API URL:{" "}
          <code className="bg-gray-100 px-2 py-1 rounded">{apiUrl}</code>
        </p>
      </div>
    </div>
  );
}

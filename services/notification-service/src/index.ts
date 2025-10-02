import express from "express";
import { WebSocketServer, WebSocket } from "ws";
import cors from "cors";
import http from "http";

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware - Configure CORS to allow all origins
app.use(
  cors({
    origin: "*",
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);
app.use(express.json());

// Create HTTP server
const server = http.createServer(app);

// Create WebSocket server
const wss = new WebSocketServer({
  server,
  path: "/ws",
  // Verify client origin to help debug connection issues
  verifyClient: (info: { origin: string; req: http.IncomingMessage }) => {
    console.log("WebSocket connection attempt from:", info.origin);
    return true; // Accept all connections
  },
});

// Store connected clients
const clients = new Set<WebSocket>();

// WebSocket connection handler
wss.on("connection", (ws: WebSocket) => {
  console.log("New client connected");
  clients.add(ws);

  ws.on("close", () => {
    console.log("Client disconnected");
    clients.delete(ws);
  });

  ws.on("error", (error) => {
    console.error("WebSocket error:", error);
    clients.delete(ws);
  });

  // Send welcome message
  ws.send(
    JSON.stringify({
      type: "connection",
      message: "Connected to notification server",
    })
  );
});

// Broadcast notification to all connected clients
function broadcastNotification(notification: any) {
  const message = JSON.stringify({
    type: "notification",
    data: notification,
    timestamp: new Date().toISOString(),
  });

  clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(message);
    }
  });
}

// REST API endpoint to push notifications
app.post("/api/notifications", (req, res) => {
  const notification = req.body;

  if (!notification || !notification.message) {
    return res.status(400).json({ error: "Notification message is required" });
  }

  console.log("Broadcasting notification:", notification);
  broadcastNotification(notification);

  res.json({
    success: true,
    message: "Notification sent",
    clients: clients.size,
  });
});

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    connectedClients: clients.size,
    uptime: process.uptime(),
  });
});

// Start server
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`WebSocket available at ws://localhost:${PORT}/ws`);
  console.log(
    `REST API available at http://localhost:${PORT}/api/notifications`
  );
});

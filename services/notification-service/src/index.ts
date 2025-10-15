import express from "express";
import { WebSocketServer, WebSocket } from "ws";
import cors from "cors";
import http from "http";
import swaggerJsdoc from "swagger-jsdoc";
import swaggerUi from "swagger-ui-express";

const app = express();
const PORT = process.env.PORT || 3001;

// Swagger/OpenAPI definition
const swaggerOptions = {
  definition: {
    openapi: "3.0.0",
    info: {
      title: "Notification Service API",
      version: "1.0.0",
      description:
        "WebSocket notification service with REST API for broadcasting messages",
    },
    servers: [
      {
        url: "/",
        description: "Notification Service",
      },
    ],
  },
  apis: ["./src/index.ts", "./dist/index.js"], // Path to the API docs
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);

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

// Serve Swagger docs
app.use("/swagger", swaggerUi.serve, swaggerUi.setup(swaggerSpec));
app.get("/swagger.json", (req, res) => {
  res.setHeader("Content-Type", "application/json");
  res.send(swaggerSpec);
});

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

/**
 * @swagger
 * /notify/broadcast:
 *   post:
 *     summary: Broadcast a notification to all connected WebSocket clients
 *     description: Sends a notification message to all active WebSocket connections
 *     tags:
 *       - Notifications
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - message
 *             properties:
 *               message:
 *                 type: string
 *                 description: The notification message to broadcast
 *               type:
 *                 type: string
 *                 description: Optional notification type
 *     responses:
 *       200:
 *         description: Notification successfully broadcasted
 *       400:
 *         description: Invalid request - message is required
 */
// REST API endpoint to push notifications
app.post("/notify/broadcast", (req, res) => {
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

/**
 * @swagger
 * /notify/health:
 *   get:
 *     summary: Health check endpoint
 *     description: Returns the health status of the notification service
 *     tags:
 *       - Health
 *     responses:
 *       200:
 *         description: Service is healthy
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                   example: ok
 *                 connectedClients:
 *                   type: number
 *                   description: Number of active WebSocket connections
 *                 uptime:
 *                   type: number
 *                   description: Service uptime in seconds
 */
// Health check endpoint
app.get("/notify/health", (req, res) => {
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

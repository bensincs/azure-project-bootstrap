import express from "express";
import { createServer } from "http";
import { Server } from "socket.io";
import cors from "cors";
import { v4 as uuidv4 } from "uuid";
import jwt from "jsonwebtoken";
import jwksClient from "jwks-rsa";
import dotenv from "dotenv";

// Load environment variables from .env file
dotenv.config();

const app = express();
const httpServer = createServer(app);

// JWT Configuration
const AZURE_TENANT_ID = process.env.AZURE_TENANT_ID;
const AZURE_CLIENT_ID = process.env.AZURE_CLIENT_ID;
const SKIP_TOKEN_VERIFICATION = process.env.SKIP_TOKEN_VERIFICATION === "true";

if (!SKIP_TOKEN_VERIFICATION && (!AZURE_TENANT_ID || !AZURE_CLIENT_ID)) {
  console.error(
    "⚠️  AZURE_TENANT_ID and AZURE_CLIENT_ID are required unless SKIP_TOKEN_VERIFICATION=true"
  );
  console.error(
    "   Set these environment variables or enable SKIP_TOKEN_VERIFICATION for development"
  );
}

// JWKS client for fetching public keys from Azure AD
const jwksClientInstance = AZURE_TENANT_ID
  ? jwksClient({
      jwksUri: `https://login.microsoftonline.com/${AZURE_TENANT_ID}/discovery/v2.0/keys`,
      cache: true,
      cacheMaxAge: 3600000, // 1 hour
      rateLimit: true,
      jwksRequestsPerMinute: 10,
    })
  : null;

// Get signing key from JWKS
function getKey(header, callback) {
  if (!jwksClientInstance) {
    return callback(new Error("JWKS client not initialized"));
  }
  jwksClientInstance.getSigningKey(header.kid, (err, key) => {
    if (err) {
      return callback(err);
    }
    const signingKey = key.getPublicKey();
    callback(null, signingKey);
  });
}

// Verify JWT token
function verifyToken(token) {
  return new Promise((resolve, reject) => {
    // Always skip verification if SKIP_TOKEN_VERIFICATION is true OR if no tenant/client configured
    if (SKIP_TOKEN_VERIFICATION || !AZURE_TENANT_ID || !AZURE_CLIENT_ID) {
      if (SKIP_TOKEN_VERIFICATION) {
        console.log(
          "⚠️  Skipping token verification (SKIP_TOKEN_VERIFICATION=true)"
        );
      } else {
        console.log(
          "⚠️  Skipping token verification (Azure AD not configured)"
        );
      }
      const decoded = jwt.decode(token);
      if (!decoded) {
        return reject(new Error("Failed to decode token"));
      }
      return resolve(decoded);
    }

    jwt.verify(
      token,
      getKey,
      {
        audience: AZURE_CLIENT_ID,
        issuer: [
          `https://login.microsoftonline.com/${AZURE_TENANT_ID}/v2.0`,
          `https://sts.windows.net/${AZURE_TENANT_ID}/`,
        ],
        algorithms: ["RS256"],
      },
      (err, decoded) => {
        if (err) {
          return reject(err);
        }
        resolve(decoded);
      }
    );
  });
}

// Express middleware for JWT authentication
async function authenticateJWT(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    return res.status(401).json({ error: "Missing authorization header" });
  }

  const parts = authHeader.split(" ");
  if (parts.length !== 2 || parts[0].toLowerCase() !== "bearer") {
    return res
      .status(401)
      .json({ error: "Invalid authorization header format" });
  }

  const token = parts[1];

  try {
    const decoded = await verifyToken(token);
    req.user = {
      id: decoded.oid || decoded.sub,
      email: decoded.email,
      name: decoded.name,
      preferredUsername: decoded.preferred_username,
    };
    next();
  } catch (error) {
    console.error("Token verification failed:", error.message);
    return res
      .status(401)
      .json({ error: "Invalid token", details: error.message });
  }
}

// Configure CORS
app.use(
  cors({
    origin: process.env.ALLOWED_ORIGINS?.split(",") || "*",
    credentials: true,
  })
);

app.use(express.json());

// Base path for when running behind Application Gateway
const BASE_PATH = process.env.BASE_PATH || "";

// Socket.IO setup
const io = new Server(httpServer, {
  path: BASE_PATH ? `${BASE_PATH}/socket.io` : "/socket.io",
  cors: {
    origin: process.env.ALLOWED_ORIGINS?.split(",") || "*",
    credentials: true,
  },
  transports: ["websocket", "polling"],
});

// In-memory storage for rooms and users
const rooms = new Map();
const users = new Map();

// Room class to manage room state
class Room {
  constructor(id, name, createdBy) {
    this.id = id;
    this.name = name;
    this.createdBy = createdBy; // User ID of room creator
    this.participants = new Map();
    this.createdAt = new Date();
  }

  addParticipant(userId, socketId, username) {
    this.participants.set(socketId, { userId, username, joinedAt: new Date() });
  }

  removeParticipant(socketId) {
    this.participants.delete(socketId);
  }

  getParticipants() {
    return Array.from(this.participants.entries()).map(([socketId, data]) => ({
      id: data.userId,
      username: data.username,
      socketId: socketId,
    }));
  }

  isEmpty() {
    return this.participants.size === 0;
  }
}

// REST API endpoints
app.get(`${BASE_PATH}/health`, (req, res) => {
  res.json({
    status: "healthy",
    rooms: rooms.size,
    users: users.size,
    timestamp: new Date().toISOString(),
  });
});

app.get(`${BASE_PATH}/api/rooms`, authenticateJWT, (req, res) => {
  const roomList = Array.from(rooms.values()).map((room) => ({
    id: room.id,
    name: room.name,
    participants: room.participants.size,
    createdAt: room.createdAt,
    createdBy: room.createdBy,
    isOwner: req.user.id === room.createdBy,
  }));
  res.json({ rooms: roomList });
});

app.post(`${BASE_PATH}/api/rooms`, authenticateJWT, (req, res) => {
  const { name } = req.body;
  if (!name) {
    return res.status(400).json({ error: "Room name is required" });
  }

  const roomId = uuidv4();
  const room = new Room(roomId, name, req.user.id);
  rooms.set(roomId, room);

  res.status(201).json({
    id: room.id,
    name: room.name,
    participants: 0,
    createdBy: req.user.id,
    isOwner: true,
  });
});

app.get(`${BASE_PATH}/api/rooms/:roomId`, authenticateJWT, (req, res) => {
  const { roomId } = req.params;
  const room = rooms.get(roomId);

  if (!room) {
    return res.status(404).json({ error: "Room not found" });
  }

  res.json({
    id: room.id,
    name: room.name,
    participants: room.getParticipants(),
    createdAt: room.createdAt,
    createdBy: room.createdBy,
    isOwner: req.user.id === room.createdBy,
  });
});

app.delete(`${BASE_PATH}/api/rooms/:roomId`, authenticateJWT, (req, res) => {
  const { roomId } = req.params;
  const room = rooms.get(roomId);

  if (!room) {
    return res.status(404).json({ error: "Room not found" });
  }

  // Only room creator can delete the room
  if (room.createdBy !== req.user.id) {
    return res
      .status(403)
      .json({ error: "Only the room creator can delete this room" });
  }

  // Notify all participants that the room is being deleted
  io.to(roomId).emit("room-deleted", {
    roomId,
    message: "This room has been deleted by the owner",
  });

  // Remove all users from the room
  room.getParticipants().forEach((participant) => {
    users.delete(participant.socketId);
  });

  // Delete the room
  rooms.delete(roomId);

  res.json({ message: "Room deleted successfully" });
});

// Socket.IO middleware for authentication
io.use(async (socket, next) => {
  try {
    const token = socket.handshake.auth.token;

    if (!token) {
      return next(new Error("Authentication token required"));
    }

    const decoded = await verifyToken(token);

    socket.user = {
      id: decoded.oid || decoded.sub,
      email: decoded.email,
      name: decoded.name,
      preferredUsername: decoded.preferred_username,
    };

    console.log(
      `Authenticated user: ${socket.user.name || socket.user.email} (${
        socket.user.id
      })`
    );
    next();
  } catch (error) {
    console.error("Socket authentication failed:", error.message);
    next(new Error("Authentication failed"));
  }
});

// Socket.IO event handlers
io.on("connection", (socket) => {
  console.log(
    `User connected: ${socket.id} - ${socket.user.name || socket.user.email}`
  );

  // Join room - username now comes from JWT token
  socket.on("join-room", ({ roomId }) => {
    const room = rooms.get(roomId);

    if (!room) {
      socket.emit("error", { message: "Room not found" });
      return;
    }

    const userId = socket.user.id;
    const username =
      socket.user.name ||
      socket.user.preferredUsername ||
      socket.user.email ||
      "Unknown User";

    // Store user info
    users.set(socket.id, { userId, roomId, username });

    // Get existing participants BEFORE adding the new user
    const existingParticipants = room.getParticipants();

    // Add to room
    room.addParticipant(userId, socket.id, username);

    // Join socket room
    socket.join(roomId);

    // Notify user they joined successfully with existing participants (not including themselves)
    socket.emit("joined-room", {
      userId,
      roomId,
      participants: existingParticipants,
    });

    // Notify others in the room
    socket.to(roomId).emit("user-joined", {
      userId,
      username,
      socketId: socket.id,
    });

    console.log(`User ${username} (${userId}) joined room ${roomId}`);
  });

  // WebRTC signaling: offer
  socket.on("webrtc-offer", ({ to, offer }) => {
    const user = users.get(socket.id);
    if (!user) return;

    console.log(`Sending offer from ${user.userId} to ${to}`);
    io.to(to).emit("webrtc-offer", {
      from: socket.id,
      fromUserId: user.userId,
      offer,
    });
  });

  // WebRTC signaling: answer
  socket.on("webrtc-answer", ({ to, answer }) => {
    const user = users.get(socket.id);
    if (!user) return;

    console.log(`Sending answer from ${user.userId} to ${to}`);
    io.to(to).emit("webrtc-answer", {
      from: socket.id,
      fromUserId: user.userId,
      answer,
    });
  });

  // WebRTC signaling: ICE candidate
  socket.on("ice-candidate", ({ to, candidate }) => {
    const user = users.get(socket.id);
    if (!user) return;

    io.to(to).emit("ice-candidate", {
      from: socket.id,
      fromUserId: user.userId,
      candidate,
    });
  });

  // Handle disconnect
  socket.on("disconnect", () => {
    const user = users.get(socket.id);

    if (user) {
      const { userId, roomId, username } = user;
      const room = rooms.get(roomId);

      if (room) {
        room.removeParticipant(socket.id);

        // Notify others
        socket
          .to(roomId)
          .emit("user-left", { userId, username, socketId: socket.id });

        // Don't auto-delete rooms - only owner can delete
        console.log(
          `User left room ${roomId}. Room has ${room.participants.size} participants remaining.`
        );
      }

      users.delete(socket.id);
      console.log(
        `User ${username} (${userId}) disconnected from room ${roomId}`
      );
    } else {
      console.log(`User ${socket.id} disconnected (no room)`);
    }
  });

  // Leave room explicitly
  socket.on("leave-room", () => {
    const user = users.get(socket.id);

    if (user) {
      const { userId, roomId, username } = user;
      const room = rooms.get(roomId);

      if (room) {
        room.removeParticipant(socket.id);
        socket.leave(roomId);

        // Notify others
        socket
          .to(roomId)
          .emit("user-left", { userId, username, socketId: socket.id });

        // Don't auto-delete rooms - only owner can delete
        console.log(
          `User left room ${roomId}. Room has ${room.participants.size} participants remaining.`
        );
      }

      users.delete(socket.id);
      socket.emit("left-room");
      console.log(`User ${username} (${userId}) left room ${roomId}`);
    }
  });
});

// Start server
const PORT = process.env.PORT || 3000;
httpServer.listen(PORT, () => {
  console.log(`🚀 WebRTC Signaling Server running on port ${PORT}`);
  console.log(`   Environment: ${process.env.NODE_ENV || "development"}`);
  console.log(`   Base Path: ${BASE_PATH || "/"}`);
  console.log(`   Health check: http://localhost:${PORT}${BASE_PATH}/health`);

  // Authentication status
  if (SKIP_TOKEN_VERIFICATION) {
    console.log(
      `   🔓 Authentication: DISABLED (SKIP_TOKEN_VERIFICATION=true)`
    );
    console.log(`   ⚠️  WARNING: Token verification is disabled!`);
  } else if (!AZURE_TENANT_ID || !AZURE_CLIENT_ID) {
    console.log(`   🔓 Authentication: DISABLED (Azure AD not configured)`);
    console.log(`   ⚠️  Set AZURE_TENANT_ID and AZURE_CLIENT_ID to enable`);
  } else {
    console.log(`   🔒 Authentication: ENABLED (Azure AD JWT)`);
    console.log(`   Tenant: ${AZURE_TENANT_ID}`);
  }
});

// Graceful shutdown
process.on("SIGTERM", () => {
  console.log("SIGTERM signal received: closing HTTP server");
  httpServer.close(() => {
    console.log("HTTP server closed");
    process.exit(0);
  });
});

# Real-Time Chat System

## Overview
A WebSocket-based real-time chat system that allows authenticated users to send direct messages to other connected users. The system demonstrates how to push messages to individual connected users via WebSocket while maintaining JWT authentication.

## Architecture

### Backend (Go API)

#### Components

**1. Connection Manager (`internal/chat/manager.go`)**
- Manages all active WebSocket connections in memory
- Tracks connected users by their User ID
- Handles client registration/unregister
- Routes messages to specific users
- Thread-safe with mutex protection

**2. Chat Handlers (`internal/handlers/chat.go`)**
- `HandleWebSocket`: Upgrades HTTP connections to WebSocket, authenticates users, registers clients
- `GetActiveUsers`: REST endpoint to retrieve all currently connected users
- `SendMessage`: REST endpoint to send a message to a specific user

**3. Client Structure**
- Each connected user has a Client instance
- Contains: User ID, Name, Email, WebSocket connection, send channel
- Runs two goroutines: readPump (listens for close) and writePump (sends messages)

#### Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/api/ws` | ✅ Required | WebSocket upgrade endpoint |
| GET | `/api/users/active` | ✅ Required | List all connected users |
| POST | `/api/messages/send` | ✅ Required | Send message to specific user |
| GET | `/api/health` | ❌ Public | Health check |
| GET | `/api/user/me` | ✅ Required | Get current user info |

#### Authentication Flow

1. Frontend makes HTTP GET request to `/api/ws` with JWT token in query parameter
2. Auth middleware validates the JWT and extracts user info
3. If valid, the connection is upgraded to WebSocket
4. Client is registered in the connection manager
5. All future messages are routed through the established WebSocket

### Frontend (React/TypeScript)

#### Key Features

**1. WebSocket Connection**
- Automatically connects when user logs in
- Passes JWT token as query parameter
- Handles connection status (disconnected, connecting, connected)
- Auto-reconnects on disconnect

**2. Active Users List**
- Fetches list of connected users via REST API
- Refreshes every 5 seconds
- Shows user name and email
- Highlights selected user

**3. Chat Interface**
- Select a user to start chatting
- Messages filtered by sender/recipient
- Shows timestamp for each message
- Visual distinction between sent/received messages
- Real-time message delivery via WebSocket

**4. Message Sending**
- Messages sent via REST API (`POST /api/messages/send`)
- Backend delivers to recipient via their WebSocket connection
- Local copy added to sender's message list
- Loading state while sending

## Message Flow

### Sending a Message

```
1. User types message and clicks "Send"
2. Frontend → POST /api/messages/send
   {
     "to": "recipient-user-id",
     "content": "Hello!"
   }
3. Backend validates JWT token
4. Backend looks up recipient's WebSocket connection
5. Backend sends message through recipient's WebSocket
6. Recipient's frontend receives message via WebSocket
7. Message added to recipient's chat UI
```

### Receiving a Message

```
1. WebSocket receives message from server
2. Message parsed as JSON
3. Added to messages array with timestamp
4. UI filters messages to show only conversation with selected user
5. Message displayed in chat interface
```

## Data Structures

### ChatMessage (Frontend)
```typescript
interface ChatMessage {
  type: string;        // "chat"
  from: string;        // Sender user ID
  name: string;        // Sender name
  email: string;       // Sender email
  content: string;     // Message text
  timestamp?: number;  // Local timestamp
}
```

### ActiveUser (Frontend)
```typescript
interface ActiveUser {
  id: string;      // User ID
  name: string;    // Display name
  email: string;   // Email address
}
```

### SendMessageRequest (Backend)
```go
type SendMessageRequest struct {
  To      string `json:"to"`      // Recipient user ID
  Content string `json:"content"` // Message text
}
```

## Security

### Authentication
- ✅ All endpoints require valid JWT token (except `/api/health`)
- ✅ WebSocket connections authenticated via query parameter
- ✅ Token validated using Azure AD JWKS
- ✅ User context extracted from token claims

### Authorization
- Users can only send messages when authenticated
- Users can only see other connected users
- No message history stored (ephemeral chat)

### CORS
- Configured to allow all origins in development
- Should be restricted in production

## Connection Management

### Registration
1. User connects to WebSocket
2. Client struct created with user info
3. Send channel initialized (256 message buffer)
4. Client added to manager's clients map
5. Read and write pumps started

### Cleanup
1. WebSocket connection closed
2. Client unregistered from manager
3. Send channel closed
4. User removed from active users list

### Heartbeat
- No explicit ping/pong implemented
- Connections rely on TCP keepalive
- Could add heartbeat for more robust connection management

## Configuration

### Environment Variables

**Backend:**
```bash
AZURE_TENANT_ID=cab08f14-2b61-43ee-8ebe-16acd8e371bf
AZURE_CLIENT_ID=0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2
PORT=8080
```

**Frontend:**
```bash
VITE_API_URL=http://localhost:8080/api
VITE_WS_URL=ws://localhost:8080/api/ws
VITE_AUTH_CLIENT_ID=0129a6d1-4c8d-4a3a-afc8-d2d47ce9cae2
VITE_AUTH_TENANT_ID=cab08f14-2b61-43ee-8ebe-16acd8e371bf
```

## Testing the System

### Prerequisites
1. Backend API running on port 8080
2. Frontend running on port 5173
3. Valid Azure AD authentication configured
4. At least 2 users logged in (to test messaging)

### Test Steps

**1. Start Backend**
```bash
cd services/api
go run cmd/api/main.go
```

**2. Start Frontend**
```bash
cd services/ui
yarn dev
```

**3. Test Chat**
1. Open browser window 1 → Login as User A
2. Open browser window 2 (incognito) → Login as User B
3. Both users should see each other in "Active Users" list
4. User A selects User B and sends a message
5. User B should receive the message in real-time
6. User B can reply, User A receives it instantly

### Expected Behavior

**✅ Successful Connection:**
- Connection status shows "connected" (green dot)
- Other user appears in "Active Users" list
- Can select user and see chat interface

**✅ Successful Message:**
- Message appears immediately in sender's chat
- Message received in real-time by recipient
- Timestamp shown on each message
- Different styling for sent vs received

**❌ Common Issues:**
- **"disconnected"** - Check WebSocket URL, backend running
- **No active users** - Other users not logged in or WebSocket not connected
- **"User not connected"** - Recipient disconnected before message sent
- **401 Unauthorized** - JWT token expired, need to re-login

## Scaling Considerations

### Current Limitations
- ✅ All connections stored in memory
- ✅ Single server instance
- ❌ No message persistence
- ❌ No chat history
- ❌ No read receipts
- ❌ No typing indicators

### Production Improvements
1. **Redis for connection tracking** - Share state across multiple servers
2. **Message queue** - Buffer messages for offline users
3. **Database** - Store chat history
4. **Load balancer with sticky sessions** - Route users to same server
5. **Kubernetes with service mesh** - Distributed WebSocket connections
6. **Rate limiting** - Prevent spam/abuse
7. **Message encryption** - End-to-end encryption for privacy

## Code Quality

### Best Practices Applied
- ✅ Clean separation of concerns
- ✅ Type-safe interfaces
- ✅ Error handling
- ✅ Graceful disconnection
- ✅ Resource cleanup
- ✅ Logging for debugging
- ✅ Thread-safe connection management
- ✅ Buffered channels to prevent blocking

## Summary

This implementation demonstrates:
1. **WebSocket authentication** with JWT tokens
2. **Real-time bidirectional communication** between clients
3. **Targeted message delivery** to specific users
4. **Connection management** with in-memory tracking
5. **Clean architecture** with separate concerns
6. **Production-ready patterns** (buffering, error handling, cleanup)

The system is fully functional for development and can be extended for production use with the improvements listed above.

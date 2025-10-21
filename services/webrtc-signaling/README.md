# WebRTC Signaling Service

A lightweight WebRTC signaling server for peer-to-peer video chat rooms.

## Features

- 🎥 WebRTC signaling for video/audio chat
- 🏠 Room-based architecture
- 👥 Multiple participants per room
- 🔌 WebSocket-based real-time communication
- 🚀 Lightweight and scalable
- 🔒 CORS-enabled for secure cross-origin requests

## Architecture

This service implements a **signaling server** - the coordination layer for WebRTC connections:

1. **Room Management**: Create and join virtual rooms
2. **Signaling**: Exchange SDP offers/answers between peers
3. **ICE Candidate Exchange**: Share network traversal information
4. **Presence**: Track who's in each room

**Note**: This is a P2P (peer-to-peer) implementation. Each client connects directly to other clients. For rooms with 5+ participants, consider implementing an SFU (Selective Forwarding Unit) media server.

## API Endpoints

### REST API

```bash
# Health check
GET /health

# List all rooms
GET /api/rooms

# Create a room
POST /api/rooms
Body: { "name": "Room Name" }

# Get room details
GET /api/rooms/:roomId
```

### WebSocket Events

**Client -> Server:**
- `join-room`: Join a room with username
- `leave-room`: Leave current room
- `webrtc-offer`: Send WebRTC offer to peer
- `webrtc-answer`: Send WebRTC answer to peer
- `ice-candidate`: Send ICE candidate to peer

**Server -> Client:**
- `joined-room`: Confirmation of room join with participant list
- `user-joined`: New user joined the room
- `user-left`: User left the room
- `webrtc-offer`: Received offer from peer
- `webrtc-answer`: Received answer from peer
- `ice-candidate`: Received ICE candidate from peer
- `error`: Error message

## Local Development

```bash
# Install dependencies
npm install

# Run in development mode (with auto-reload)
npm run dev

# Run in production mode
npm start
```

## Deployment

```bash
# Generate environment configuration
./env.sh

# Deploy to Azure Container Apps
./deploy.sh
```

## Environment Variables

```bash
# Server
PORT=3000
NODE_ENV=production

# CORS
ALLOWED_ORIGINS=https://yourdomain.com,https://another.com

# Logging
LOG_LEVEL=info
```

## Client Integration

See the example client implementation in `services/ui/src/pages/VideoChat.tsx` for how to integrate with your frontend.

Basic flow:
1. Connect to signaling server via Socket.IO
2. Create/join a room
3. When `user-joined` event fires, initiate WebRTC connection
4. Exchange offers, answers, and ICE candidates via signaling server
5. WebRTC peer connection establishes directly between clients

## STUN/TURN Configuration

This service handles signaling only. Clients need STUN/TURN servers for NAT traversal:

**Free STUN servers** (good for most connections):
```javascript
{
  iceServers: [
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' }
  ]
}
```

**TURN servers** (needed for ~20% of connections behind strict NATs):
- Deploy your own: [coturn](https://github.com/coturn/coturn)
- Use a service: Twilio, Xirsys, Metered

## Scaling Considerations

**Current (P2P)**: Good for 2-4 participants
- Each peer connects to every other peer
- Bandwidth: N*(N-1) connections
- CPU: Encoding/decoding for each peer

**For 5+ participants**: Consider SFU (Selective Forwarding Unit)
- Clients send once, server forwards to others
- Better bandwidth efficiency
- Options: mediasoup, Janus, Jitsi

## Security Notes

- Always use HTTPS (required for getUserMedia)
- Validate room access/authentication as needed
- Consider rate limiting for production
- Monitor for abuse (room creation, bandwidth)

## Monitoring

Health check endpoint provides basic metrics:
```bash
curl https://your-service/health
```

Returns:
```json
{
  "status": "healthy",
  "rooms": 3,
  "users": 12,
  "timestamp": "2025-10-21T10:30:00Z"
}
```

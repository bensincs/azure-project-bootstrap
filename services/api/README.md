# Go API Service

A high-performance Go HTTP API service with WebSocket support, JWT authentication, and realtime event streaming.

## Project Structure

```
services/api/
├── cmd/
│   └── api/
│       └── main.go          # Application entry point
├── internal/
│   ├── config/
│   │   └── config.go        # Configuration management with Viper
│   ├── events/
│   │   ├── manager.go       # WebSocket event manager
│   │   └── types.go         # Event type definitions
│   ├── handlers/
│   │   ├── chat.go          # WebSocket chat handlers
│   │   ├── health.go        # Health check handlers
│   │   └── user.go          # User endpoints
│   ├── middleware/
│   │   ├── auth.go          # JWT authentication
│   │   └── cors.go          # CORS middleware
│   └── models/
│       ├── health.go        # Data models
│       └── user.go          # User models
├── .env.example            # Example environment configuration
├── go.mod                  # Go module definition
├── Dockerfile              # Multi-stage Docker build
└── deploy.sh               # Azure deployment script
```

## Configuration

The API uses [Viper](https://github.com/spf13/viper) for configuration management, supporting both `.env` files and environment variables.

### Setup

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Update `.env` with your Azure AD credentials:
   ```env
   PORT=8080
   AZURE_TENANT_ID=your-tenant-id-here
   AZURE_CLIENT_ID=your-client-id-here
   SKIP_TOKEN_VERIFICATION=false
   ```

### Configuration Priority

Viper loads configuration in this order (later sources override earlier ones):
1. `.env` file
2. Environment variables

This allows you to:
- Use `.env` for local development
- Override with environment variables in production (Container Apps, CI/CD)

## Endpoints

### Public Endpoints
- `GET /api/health` - Health check endpoint

### Authenticated Endpoints (require JWT Bearer token)
- `GET /api/user/me` - Get current user information
- `GET /api/ws?token=<jwt>` - WebSocket connection for realtime events
- `GET /api/users/active` - Get list of currently connected users
- `POST /api/messages/send` - Send a message to a specific user

## Running Locally

```bash
# Make sure .env is configured
go run cmd/api/main.go
```

The API will be available at `http://localhost:8080`.

## Building Docker Image

```bash
docker build -t api:latest .
docker run -p 8080:8080 api:latest
```

## Deployment

The `deploy.sh` script automatically reads your `.env` file and sets those values as environment variables in Azure Container Apps.

### Deploy to Azure

```bash
./deploy.sh dev
```

This will:
1. Build the Docker image for linux/amd64
2. Push to Azure Container Registry
3. Read environment variables from `.env`
4. Update the Container App with the new image and environment variables

### What Gets Deployed

All variables from your `.env` file are automatically set in the Container App:
- `PORT`
- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`
- `SKIP_TOKEN_VERIFICATION`

**Note:** Make sure your `.env` file is configured before deploying!

For more details on deployment with environment variables, see [DEPLOYMENT.md](../../DEPLOYMENT.md).

## Development

Go version: 1.23

The project follows standard Go project layout:
- `cmd/` - Application entry points
- `internal/` - Private application code

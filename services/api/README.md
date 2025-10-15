# Go API Service

A simple Go HTTP API service with proper project structure.

## Project Structure

```
services/api/
├── cmd/
│   └── api/
│       └── main.go          # Application entry point
├── internal/
│   ├── handlers/
│   │   └── health.go        # HTTP request handlers
│   └── models/
│       └── health.go        # Data models
├── go.mod                   # Go module definition
├── Dockerfile              # Multi-stage Docker build
└── deploy.sh               # Azure deployment script
```

## Endpoints

- `GET /api/health` - Health check endpoint

## Running Locally

```bash
go run cmd/api/main.go
```

The API will be available at `http://localhost:8080`.

## Building Docker Image

```bash
docker build -t api:latest .
docker run -p 8080:8080 api:latest
```

## Deployment

Use the `deploy.sh` script to build and deploy to Azure Container Apps:

```bash
./deploy.sh dev
```

## Development

Go version: 1.23

The project follows standard Go project layout:
- `cmd/` - Application entry points
- `internal/` - Private application code

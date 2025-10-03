# .NET API Service

A simple .NET 9 Web API with minimal endpoints.

## Endpoints

- `GET /` - Root endpoint with service info
- `GET /health` - Health check endpoint
- `GET /api/hello` - Hello world endpoint
- `GET /api/hello/{name}` - Hello with name parameter
- `GET /swagger` - Swagger UI (development only)

## Running Locally

```bash
dotnet restore
dotnet run
```

The API will be available at `http://localhost:5000` (or the port specified in `launchSettings.json`).

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

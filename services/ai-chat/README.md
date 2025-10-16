# AI Chat Service

A FastAPI service for AI chat functionality using Semantic Kernel and Azure OpenAI, managed with `uv`.

## Features

- 🚀 FastAPI framework
- 🤖 Semantic Kernel for AI chat agent
- 💬 GPT-4 mini (gpt-4o-mini) for chat responses
- 📦 Dependency management with `uv`
- 🔐 Azure AD JWT authentication
- � In-memory chat history per user
- �🐳 Docker containerization
- ☁️ Azure Container Apps deployment
- 🏥 Health check endpoint

## API Endpoints

### Health Check
- **URL**: `/ai-chat/health`
- **Method**: GET
- **Authentication**: None
- **Response**:
```json
{
  "status": "healthy",
  "service": "ai-chat",
  "environment": "dev",
  "version": "v1"
}
```

### Get Current User
- **URL**: `/ai-chat/user/me`
- **Method**: GET
- **Authentication**: Required (Azure AD JWT Bearer token)
- **Response**:
```json
{
  "id": "user-object-id",
  "email": "user@example.com",
  "name": "User Name",
  "preferred_username": "user@example.com",
  "tenant_id": "tenant-id",
  "roles": [],
  "groups": [],
  "issued_at": "2025-10-16T12:00:00",
  "expires_at": "2025-10-16T13:00:00"
}
```

### Send Chat Message
- **URL**: `/ai-chat/chat`
- **Method**: POST
- **Authentication**: Required (Azure AD JWT Bearer token)
- **Request Body**:
```json
{
  "message": "Hello, how are you?"
}
```
- **Response**:
```json
{
  "message": "I'm doing well, thank you! How can I assist you today?",
  "timestamp": "2025-10-16T12:00:00"
}
```

### Get Chat History
- **URL**: `/ai-chat/chat/history`
- **Method**: GET
- **Authentication**: Required (Azure AD JWT Bearer token)
- **Response**:
```json
[
  {
    "role": "user",
    "content": "Hello, how are you?",
    "timestamp": "2025-10-16T12:00:00"
  },
  {
    "role": "assistant",
    "content": "I'm doing well, thank you! How can I assist you today?",
    "timestamp": "2025-10-16T12:00:01"
  }
]
```

### Clear Chat History
- **URL**: `/ai-chat/chat/history`
- **Method**: DELETE
- **Authentication**: Required (Azure AD JWT Bearer token)
- **Response**:
```json
{
  "message": "Chat history cleared"
}
```

## Local Development

### Prerequisites

- Python 3.11+
- [uv](https://github.com/astral-sh/uv) package manager
- Docker (for containerization)
- Azure AD tenant (for JWT authentication)
- Azure OpenAI resource with GPT-4 mini deployment

### Setup

1. **Install uv** (if not already installed):
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

2. **Install dependencies**:
```bash
cd services/ai-chat
uv pip install -r pyproject.toml
```

3. **Configure environment variables**:
```bash
cp .env.example .env
# Edit .env with your settings:
# - Azure AD tenant ID and client ID
# - Azure OpenAI endpoint, API key, and deployment name
```

4. **Run the service**:
```bash
uv run python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

5. **Test the health endpoint** (no auth required):
```bash
curl http://localhost:8000/ai-chat/health
```

6. **Test the chat endpoint** (requires JWT token):
```bash
# Get a token from your Azure AD app
TOKEN="your-jwt-token-here"

# Send a chat message
curl -X POST http://localhost:8000/ai-chat/chat \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello!"}'

# Get chat history
curl http://localhost:8000/ai-chat/chat/history \
  -H "Authorization: Bearer $TOKEN"
```

## Chat Features

### Semantic Kernel Integration

The service uses Microsoft's Semantic Kernel to:
- Manage conversation context and history
- Interface with Azure OpenAI GPT-4 mini
- Provide a simple, extensible AI agent architecture

### Per-User Chat History

- Each authenticated user has their own chat history
- History is maintained in-memory (resets on service restart)
- System message sets the assistant's behavior
- All user messages and assistant responses are tracked

### GPT-4 Mini Configuration

- **Model**: gpt-4o-mini (cost-effective, fast responses)
- **Max Tokens**: 1000
- **Temperature**: 0.7 (balanced creativity and consistency)

## Authentication

This service validates **Azure AD JWT tokens** with proper signature verification using JWKS.

### How it works:

1. **JWKS Fetching**: Fetches public keys from Azure AD's JWKS endpoint
2. **Signature Verification**: Validates RS256 JWT signature using the public key
3. **Claims Validation**: Verifies issuer, audience, and expiration
4. **User Extraction**: Extracts user information from validated claims

### Configuration:

Set these in your `.env` file:

```bash
AZURE_TENANT_ID=your-azure-tenant-id
AZURE_CLIENT_ID=your-azure-client-id
SKIP_TOKEN_VERIFICATION=false  # Set to true for development only
```

### Protected Endpoints:

- `/ai-chat/user/me` - Requires valid Azure AD JWT Bearer token

### Development Mode:

For local development **without real Azure AD tokens**, set:
```bash
SKIP_TOKEN_VERIFICATION=true
```

This will skip signature verification and accept any JWT token. You can generate test tokens with:
```bash
uv run python generate_test_token.py
```

⚠️ **WARNING**: Never use `SKIP_TOKEN_VERIFICATION=true` in production!

### Production Mode:

With `SKIP_TOKEN_VERIFICATION=false` (default), the service will:
- ✅ Fetch JWKS from Azure AD
- ✅ Verify RS256 signature
- ✅ Validate issuer matches your tenant
- ✅ Validate audience matches your client ID
- ✅ Check token expiration

This is the same validation logic as the Go API service.

## Docker

### Build the image:
```bash
docker build -t ai-chat-service .
```

### Run the container:
```bash
docker run -p 8000:8000 ai-chat-service
```

### Test:
```bash
curl http://localhost:8000/ai-chat/health
```

## Deployment

### Deploy to Azure Container Apps

The service can be deployed to Azure Container Apps using the provided deployment script:

```bash
./deploy.sh dev
```

**Note**: Before deploying, ensure:
1. You have Azure CLI installed and authenticated
2. Your Terraform infrastructure is set up with the required outputs:
   - `resource_group_name`
   - `container_registry_name`
   - `ai_chat_service_name` (or the script will use a default name)
3. The Container App resource exists in your infrastructure

### Environment Variables

Create a `.env` file in the service directory to set environment variables:

```bash
# Application Settings
APP_NAME="AI Chat Service"
ENVIRONMENT=dev
DEBUG=false
LOG_LEVEL=info

# API Settings
API_VERSION=v1

# Azure AD JWT Authentication
AZURE_TENANT_ID=your-tenant-id-here
AZURE_CLIENT_ID=your-client-id-here
SKIP_TOKEN_VERIFICATION=false  # Set to true ONLY for development/testing
```

**Important**:
- Set `AZURE_TENANT_ID` and `AZURE_CLIENT_ID` to your Azure AD values
- The `SKIP_TOKEN_VERIFICATION` flag should ONLY be set to `true` for local development
- Never use `SKIP_TOKEN_VERIFICATION=true` in production environments

The deployment script will automatically load and apply these variables.

## Project Structure

```
ai-chat/
├── app/
│   ├── __init__.py
│   └── main.py          # FastAPI application
├── Dockerfile           # Container configuration
├── deploy.sh           # Deployment script
├── pyproject.toml      # Python dependencies
└── README.md           # This file
```

## Dependencies

- **FastAPI**: Modern, fast web framework for building APIs
- **Uvicorn**: ASGI server for running FastAPI applications
- **uv**: Fast Python package installer and resolver
- **PyJWT[crypto]**: JSON Web Token implementation with cryptographic support
- **cryptography**: Cryptographic recipes for JWT RS256 verification
- **httpx**: Async HTTP client for fetching JWKS
- **pydantic-settings**: Settings management using Pydantic

## Development Notes

- The service is mounted at the `/ai-chat` path
- All endpoints are prefixed with `/ai-chat` (e.g., `/ai-chat/health`)
- The Dockerfile uses `uv` for dependency management
- The service runs on port 8000 by default

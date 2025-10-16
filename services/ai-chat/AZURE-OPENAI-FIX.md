# Azure OpenAI Integration Fix

## Problem

The original implementation used `AzureAIAgentClient`, which requires an **Azure AI Foundry project** (not just Azure OpenAI). This caused a 404 error:

```
azure.core.exceptions.ResourceNotFoundError: (404) Resource not found
```

## Solution

Changed to use `AzureOpenAIChatClient` which works directly with **Azure OpenAI** resources.

## Changes Made

### Before (Azure AI Foundry - Requires additional setup):
```python
from agent_framework.azure import AzureAIAgentClient
from azure.identity.aio import DefaultAzureCredential

credential = DefaultAzureCredential()
agent_client = AzureAIAgentClient(async_credential=credential)
```

### After (Azure OpenAI - Works with existing setup):
```python
from agent_framework.azure import AzureOpenAIChatClient
from azure.identity.aio import AzureCliCredential

credential = AzureCliCredential()
chat_client = AzureOpenAIChatClient(
    endpoint=settings.azure_openai_endpoint,
    credential=credential,
    ai_model_id=settings.azure_openai_deployment_name,
)
```

## Configuration Required

Only your existing Azure OpenAI settings are needed:

```bash
AZURE_OPENAI_ENDPOINT=https://<your-resource>.openai.azure.com/
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4o-mini
```

## Authentication

Ensure you're logged in with Azure CLI:

```bash
az login
```

The service will use your Azure CLI credentials to authenticate with Azure OpenAI.

## What You Don't Need

- ❌ Azure AI Foundry project
- ❌ Azure AI Project endpoint
- ❌ Additional Azure resources

## What Works Now

- ✅ Direct Azure OpenAI integration
- ✅ Thread-based conversation management
- ✅ All existing endpoints functional
- ✅ Works with your current Azure setup

## Testing

Start the service:
```bash
cd services/ai-chat
uv run python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Test the chat endpoint:
```bash
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"message": "Hello!"}'
```

## Alternative: Azure AI Foundry

If you want to use Azure AI Foundry (for advanced features like tool calling, code interpreter, etc.), you would need to:

1. Create an Azure AI Hub
2. Create an Azure AI Project
3. Deploy a model in the project
4. Use `AzureAIAgentClient` with the project endpoint

But for basic chat with conversation history, `AzureOpenAIChatClient` is simpler and works with your existing setup.

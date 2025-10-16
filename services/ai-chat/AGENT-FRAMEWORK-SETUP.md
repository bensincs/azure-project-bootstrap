# Microsoft Agent Framework Setup

This service now uses the **Microsoft Agent Framework** with **thread-based conversation management** and **Azure OpenAI** for AI chat functionality.

## Key Features

- **Thread-based conversations**: Uses Agent Framework's native `AgentThread` for persistent conversation state
- **Automatic context management**: The framework maintains conversation history automatically
- **Serializable threads**: Thread state can be serialized and stored (in-memory for now, ready for database integration)
- **Azure OpenAI integration**: Works directly with your existing Azure OpenAI resource

## Requirements

- Python 3.12 or later (required by agent-framework)
- Azure OpenAI resource with a deployed model (e.g., `gpt-4o-mini`)
- Azure CLI installed and authenticated

## Environment Variables

Add the following environment variables to your `.env` file:

```bash
# Azure OpenAI Configuration (required)
AZURE_OPENAI_ENDPOINT=https://<your-resource>.openai.azure.com/
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4o-mini
```

## Authentication

The Agent Framework uses **Azure CLI credentials** for authentication. Make sure you're logged in:

```bash
az login
```

Ensure you have access to the Azure AI project configured in your environment variables.

## Installation

The required packages are already in `pyproject.toml`:

```bash
cd services/ai-chat
uv pip install --prerelease=allow agent-framework azure-identity
```

Note: The `--prerelease=allow` flag is required as the Agent Framework is currently in beta.

## Running the Service

```bash
cd services/ai-chat
uv run python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Key Changes from Semantic Kernel

1. **Thread-based conversations**: Uses `AgentThread` instead of manual history management
2. **Automatic persistence**: Threads are serialized and can be stored/reloaded
3. **Agent reuse**: Single agent instance is reused across requests for efficiency
4. **Azure AI Project**: Requires Azure AI Project endpoint instead of just OpenAI endpoint
5. **Authentication**: Uses Azure CLI credentials via `DefaultAzureCredential`
6. **Simpler API**: More straightforward agent creation and interaction

## How Threads Work

- Each user gets their own `AgentThread` that maintains conversation state
- Threads are automatically updated when messages are sent
- Threads are serialized to JSON and stored in-memory (ready for database integration)
- The framework handles all conversation context management automatically

## API Endpoints

All existing endpoints remain the same:

- `POST /chat` - Send a message and get a response
- `POST /chat/stream` - Send a message and stream the response
- `GET /chat/history` - Get chat history for the current user (from thread)
- `DELETE /chat/history` - Clear chat history (deletes thread)

## Production Considerations

The current implementation stores serialized threads in-memory. For production:

1. **Add database storage**: Store serialized thread JSON in PostgreSQL, MongoDB, etc.
2. **Add Redis caching**: Cache active threads for faster access
3. **Implement cleanup**: Add TTL or periodic cleanup for old threads
4. **Add error handling**: Handle thread deserialization failures gracefully

Example for database storage:
```python
# In _save_thread method
serialized = await thread.serialize()
await db.save_thread(user_id, json.dumps(serialized))

# In _get_or_create_thread method
thread_data = await db.load_thread(user_id)
if thread_data:
    thread = await agent.deserialize_thread(json.loads(thread_data))
```

## Resources

- [Microsoft Agent Framework Quick Start](https://learn.microsoft.com/en-us/agent-framework/tutorials/quick-start?pivots=programming-language-python)
- [Persisted Conversations with Threads](https://learn.microsoft.com/en-us/agent-framework/tutorials/agents/persisted-conversation?pivots=programming-language-python)
- [Azure AI Agent Examples](https://github.com/microsoft/agent-framework/blob/main/python/samples/getting_started/agents/azure_ai/README.md)

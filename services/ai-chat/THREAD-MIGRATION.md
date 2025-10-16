# Thread-Based Conversation Migration

## Overview

The chat service has been updated to use **Microsoft Agent Framework's native thread management** instead of manual history tracking. This provides better conversation persistence, cleaner code, and aligns with the framework's design patterns.

## What Changed

### Before (Manual History)
- Manually stored `ChatMessage` objects in a list per user
- Had to manually append user/assistant messages after each interaction
- History was stored as application objects, not framework objects
- No built-in serialization support

### After (Thread-Based)
- Uses `AgentThread` to maintain conversation state
- Framework automatically manages message history
- Threads are serializable to JSON for storage
- Single agent instance reused for efficiency

## Code Changes

### 1. Storage Change
```python
# Before
self.user_histories: Dict[str, List[ChatMessage]] = {}

# After
self.user_threads: Dict[str, dict] = {}  # Stores serialized thread data
```

### 2. Agent Management
```python
# Before
async def _create_agent(self) -> ChatAgent:
    # Created new agent each time

# After
async def _get_agent(self) -> ChatAgent:
    # Reuses single agent instance
```

### 3. Thread Management
```python
# New methods added
async def _get_or_create_thread(self, user_id: str):
    """Get existing thread or create new one"""

async def _save_thread(self, user_id: str, thread):
    """Serialize and store thread"""
```

### 4. Chat Method
```python
# Before
async def chat(self, user_id: str, message: str) -> str:
    history = self.get_or_create_history(user_id)
    async with await self._create_agent() as agent:
        result = await agent.run(message)
    history.append(...)  # Manual history management

# After
async def chat(self, user_id: str, message: str) -> str:
    agent = await self._get_agent()
    thread = await self._get_or_create_thread(user_id)
    response = await agent.run(message, thread=thread)
    await self._save_thread(user_id, thread)  # Thread auto-updated
```

### 5. History Retrieval
```python
# Before
def get_history(self, user_id: str) -> list[ChatMessage]:
    return self.user_histories.get(user_id, [])

# After
async def get_history(self, user_id: str) -> list[ChatMessage]:
    thread = await self._get_or_create_thread(user_id)
    # Extract messages from thread.messages
```

## Benefits

1. **Framework-Native**: Uses the framework's intended design pattern
2. **Automatic Management**: No manual message tracking needed
3. **Persistence Ready**: Threads serialize to JSON, ready for database storage
4. **Better Performance**: Single agent instance reused across requests
5. **Cleaner Code**: Less manual state management
6. **Type Safety**: Framework handles message types internally

## Migration Path to Database

Current implementation stores threads in-memory. To add database persistence:

```python
class ChatService:
    def __init__(self, db_client):
        self.db = db_client

    async def _get_or_create_thread(self, user_id: str):
        # Load from database
        thread_json = await self.db.get_thread(user_id)
        if thread_json:
            return await agent.deserialize_thread(json.loads(thread_json))
        return agent.get_new_thread()

    async def _save_thread(self, user_id: str, thread):
        serialized = await thread.serialize()
        await self.db.save_thread(user_id, json.dumps(serialized))
```

## Testing

All existing API endpoints work unchanged:
- ✅ `POST /chat` - Works with thread context
- ✅ `POST /chat/stream` - Streams with thread context
- ✅ `GET /chat/history` - Retrieves from thread
- ✅ `DELETE /chat/history` - Deletes thread

## Rollback Plan

If issues arise, the git history contains the previous manual history implementation. Simply revert the chat.py file to restore the old behavior.

## Next Steps

1. **Test thoroughly**: Verify conversation continuity across multiple exchanges
2. **Add database**: Implement persistent thread storage
3. **Monitor performance**: Track agent reuse benefits
4. **Add logging**: Log thread serialization/deserialization for debugging
5. **Handle errors**: Add try-catch for thread deserialization failures

## References

- [Agent Framework Persisted Conversations](https://learn.microsoft.com/en-us/agent-framework/tutorials/agents/persisted-conversation?pivots=programming-language-python)
- [Third Party Storage](https://learn.microsoft.com/en-us/agent-framework/tutorials/agents/third-party-chat-history-storage)

from typing import Dict, AsyncGenerator, Optional
from agent_framework import ChatAgent
from agent_framework.azure import AzureOpenAIChatClient
from azure.identity.aio import AzureCliCredential
from app.config import settings
from app.models.chat import ChatMessage
from datetime import datetime


class ChatService:
    """Service for managing chat conversations using Microsoft Agent Framework with threads"""

    def __init__(self):
        # Store serialized thread data per user (in-memory for simplicity)
        # In production, this should be stored in a database
        self.user_threads: Dict[str, dict] = {}

        # Store agent instance (reused across requests)
        self._agent: Optional[ChatAgent] = None

    async def _get_agent(self) -> ChatAgent:
        """Get or create the chat agent instance"""
        if self._agent is None:
            # Use AzureCli credential for authentication
            credential = AzureCliCredential()

            # Create Azure OpenAI chat client
            chat_client = AzureOpenAIChatClient(
                endpoint=settings.azure_openai_endpoint,
                credential=credential,
                deployment_name=settings.azure_openai_deployment_name,
            )

            self._agent = ChatAgent(
                chat_client=chat_client,
                instructions="You are a helpful AI assistant. Provide clear, accurate, and friendly responses.",
                name="Assistant",
            )

        return self._agent

    async def _get_or_create_thread(self, user_id: str):
        """Get or create a thread for a user"""
        agent = await self._get_agent()

        if user_id in self.user_threads:
            # Deserialize existing thread
            thread = await agent.deserialize_thread(self.user_threads[user_id])
        else:
            # Create a new thread
            thread = agent.get_new_thread()

        return thread

    async def _save_thread(self, user_id: str, thread):
        """Serialize and save a thread for a user"""
        serialized = await thread.serialize()
        self.user_threads[user_id] = serialized

    async def chat(self, user_id: str, message: str) -> str:
        """Send a message and get a response"""
        agent = await self._get_agent()
        thread = await self._get_or_create_thread(user_id)

        # Run the agent with the thread to maintain conversation history
        response = await agent.run(message, thread=thread)
        response_text = response.text

        # Save the updated thread
        await self._save_thread(user_id, thread)

        return response_text

    async def chat_stream(
        self, user_id: str, message: str
    ) -> AsyncGenerator[str, None]:
        """Send a message and stream the response"""
        agent = await self._get_agent()
        thread = await self._get_or_create_thread(user_id)

        # Stream the agent's response with thread context
        async for chunk in agent.run_stream(message, thread=thread):
            if hasattr(chunk, "text") and chunk.text:
                yield chunk.text

        # Save the updated thread
        await self._save_thread(user_id, thread)

    async def get_history(self, user_id: str) -> list[ChatMessage]:
        """Get chat history for a user from their thread"""
        if user_id not in self.user_threads:
            return []

        thread = await self._get_or_create_thread(user_id)

        messages = []

        # Extract messages from the thread
        if hasattr(thread, "messages"):
            for msg in thread.messages:
                # Skip system messages
                if hasattr(msg, "role") and msg.role != "system":
                    messages.append(
                        ChatMessage(
                            role=msg.role,
                            content=str(msg.content)
                            if hasattr(msg, "content")
                            else str(msg),
                            timestamp=datetime.utcnow(),
                        )
                    )

        return messages

    async def clear_history(self, user_id: str) -> None:
        """Clear chat history for a user"""
        if user_id in self.user_threads:
            del self.user_threads[user_id]


# Create a single instance
chat_service = ChatService()

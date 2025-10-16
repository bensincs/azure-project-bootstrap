from typing import Dict
from semantic_kernel import Kernel
from semantic_kernel.connectors.ai.open_ai import AzureChatCompletion
from semantic_kernel.contents import ChatHistory
from app.config import settings
from app.models.chat import ChatMessage
from datetime import datetime


class ChatService:
    """Service for managing chat conversations using Semantic Kernel"""

    def __init__(self):
        # Store chat histories per user (in-memory for simplicity)
        self.user_histories: Dict[str, ChatHistory] = {}

        # Initialize Semantic Kernel
        self.kernel = Kernel()

        # Add Azure OpenAI chat completion service
        self.service_id = "chat"
        self.kernel.add_service(
            AzureChatCompletion(
                service_id=self.service_id,
                deployment_name=settings.azure_openai_deployment_name,
                endpoint=settings.azure_openai_endpoint,
                api_key=settings.azure_openai_api_key,
                api_version=settings.azure_openai_api_version,
            )
        )

    def get_or_create_history(self, user_id: str) -> ChatHistory:
        """Get or create chat history for a user"""
        if user_id not in self.user_histories:
            history = ChatHistory()
            # Add system message to set the assistant's behavior
            history.add_system_message(
                "You are a helpful AI assistant. Provide clear, accurate, and friendly responses."
            )
            self.user_histories[user_id] = history

        return self.user_histories[user_id]

    async def chat(self, user_id: str, message: str) -> str:
        """Send a message and get a response"""
        # Get user's chat history
        history = self.get_or_create_history(user_id)

        # Add user message to history
        history.add_user_message(message)

        # Get chat completion service
        chat_service = self.kernel.get_service(service_id=self.service_id)

        # Get response from the model
        response = await chat_service.get_chat_message_content(
            chat_history=history,
            settings=chat_service.instantiate_prompt_execution_settings(
                service_id=self.service_id,
                max_completion_tokens=1000,
            ),
        )

        # Add assistant response to history
        history.add_assistant_message(str(response))

        return str(response)

    def get_history(self, user_id: str) -> list[ChatMessage]:
        """Get chat history for a user"""
        if user_id not in self.user_histories:
            return []

        history = self.user_histories[user_id]
        messages = []

        for message in history.messages:
            # Skip system messages in the returned history
            if message.role.value != "system":
                messages.append(
                    ChatMessage(
                        role=message.role.value,
                        content=str(message.content),
                        timestamp=datetime.utcnow(),
                    )
                )

        return messages

    def clear_history(self, user_id: str) -> None:
        """Clear chat history for a user"""
        if user_id in self.user_histories:
            del self.user_histories[user_id]


# Create a single instance
chat_service = ChatService()

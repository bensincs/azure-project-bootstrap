from pydantic import BaseModel, Field
from typing import List
from datetime import datetime


class ChatMessage(BaseModel):
    """A single chat message"""

    role: str = Field(..., description="Role: 'user' or 'assistant'")
    content: str = Field(..., description="Message content")
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class ChatRequest(BaseModel):
    """Request to send a chat message"""

    message: str = Field(..., description="User message", min_length=1)


class ChatResponse(BaseModel):
    """Response from the chat agent"""

    message: str = Field(..., description="Assistant response")
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class ChatHistory(BaseModel):
    """Chat history for a user"""

    user_id: str
    messages: List[ChatMessage] = []
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

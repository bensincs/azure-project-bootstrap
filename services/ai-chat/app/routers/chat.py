from fastapi import APIRouter, Depends
from app.models.chat import ChatRequest, ChatResponse, ChatMessage
from app.models.user import User
from app.middleware.auth import get_current_user
from app.services.chat import chat_service
from typing import List

router = APIRouter(prefix="/chat", tags=["chat"])


@router.post("", response_model=ChatResponse)
async def send_message(
    request: ChatRequest, current_user: User = Depends(get_current_user)
):
    """Send a message to the chat agent"""
    response_text = await chat_service.chat(current_user.id, request.message)

    return ChatResponse(message=response_text)


@router.get("/history", response_model=List[ChatMessage])
async def get_history(current_user: User = Depends(get_current_user)):
    """Get chat history for the current user"""
    return chat_service.get_history(current_user.id)


@router.delete("/history")
async def clear_history(current_user: User = Depends(get_current_user)):
    """Clear chat history for the current user"""
    chat_service.clear_history(current_user.id)
    return {"message": "Chat history cleared"}

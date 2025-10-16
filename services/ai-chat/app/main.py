from fastapi import FastAPI
from fastapi.responses import JSONResponse
from app.config import settings
from app.routers import user

# Create the main FastAPI app
app = FastAPI(title=settings.app_name)

# Create a sub-application for ai-chat
ai_chat_app = FastAPI(title="AI Chat API")


@ai_chat_app.get("/health")
async def health():
    """Health check endpoint"""
    return JSONResponse(
        content={
            "status": "healthy",
            "service": "ai-chat",
            "environment": settings.environment,
            "version": settings.api_version
        },
        status_code=200
    )


# Include routers
ai_chat_app.include_router(user.router)

# Mount the ai-chat app at /ai-chat
app.mount("/ai-chat", ai_chat_app)


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": settings.app_name,
        "environment": settings.environment,
        "endpoints": [
            "/ai-chat/health",
            "/ai-chat/user/me"
        ]
    }

import logging
from fastapi import APIRouter, Depends
from app.models.user import User
from app.middleware.auth import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/user", tags=["user"])


@router.get("/me")
async def get_user_me(current_user: User = Depends(get_current_user)) -> User:
    """
    Get current authenticated user information

    Returns user details from the validated JWT token.
    Requires a valid Azure AD JWT token in the Authorization header.
    """
    logger.info(f"User info retrieved for: {current_user.email} ({current_user.id})")
    return current_user

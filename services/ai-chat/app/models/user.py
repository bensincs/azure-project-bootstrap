from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class User(BaseModel):
    """User model representing an authenticated user from Azure AD JWT"""

    id: str  # Object ID (oid claim)
    email: str  # Email address
    name: str  # Display name
    preferred_username: str  # Preferred username
    tenant_id: str  # Azure AD tenant ID
    roles: list[str] = []  # App roles
    groups: list[str] = []  # Group memberships
    issued_at: datetime  # Token issued at time
    expires_at: datetime  # Token expiration time


class UserClaims(BaseModel):
    """JWT claims from Azure AD token"""

    oid: str  # Object ID
    email: Optional[str] = None
    preferred_username: Optional[str] = None
    name: Optional[str] = None
    tid: str  # Tenant ID
    roles: list[str] = []
    groups: list[str] = []
    aud: str  # Audience (client ID)
    iss: str  # Issuer
    iat: int  # Issued at (unix timestamp)
    exp: int  # Expiration time (unix timestamp)

    def to_user(self) -> User:
        """Convert UserClaims to User model"""
        return User(
            id=self.oid,
            email=self.email or self.preferred_username or "",
            name=self.name or "",
            preferred_username=self.preferred_username or "",
            tenant_id=self.tid,
            roles=self.roles,
            groups=self.groups,
            issued_at=datetime.fromtimestamp(self.iat),
            expires_at=datetime.fromtimestamp(self.exp),
        )

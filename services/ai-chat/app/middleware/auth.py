import logging
from typing import Dict
import jwt
from jwt.algorithms import RSAAlgorithm
import httpx
from fastapi import HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.config import settings
from app.models.user import User, UserClaims

logger = logging.getLogger(__name__)

# HTTP Bearer security scheme
security = HTTPBearer()

# Cache for JWKS keys
_jwks_cache: Dict[str, any] = {}


async def get_jwks() -> Dict:
    """Fetch JWKS from Azure AD"""
    if _jwks_cache:
        return _jwks_cache
    
    jwks_url = settings.get_jwks_url()
    logger.info(f"Fetching JWKS from: {jwks_url}")
    
    async with httpx.AsyncClient() as client:
        response = await client.get(jwks_url)
        response.raise_for_status()
        jwks = response.json()
        
        # Cache the keys
        for key in jwks.get("keys", []):
            kid = key.get("kid")
            if kid:
                _jwks_cache[kid] = key
        
        logger.info(f"Cached {len(_jwks_cache)} JWKS keys")
        return _jwks_cache


def get_public_key(token: str, jwks: Dict) -> str:
    """Extract public key from JWKS for the given token"""
    # Decode header to get kid
    unverified_header = jwt.get_unverified_header(token)
    kid = unverified_header.get("kid")
    
    if not kid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing 'kid' in header"
        )
    
    # Find the key in JWKS
    jwk = jwks.get(kid)
    if not jwk:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Public key not found for kid: {kid}"
        )
    
    # Convert JWK to PEM format
    public_key = RSAAlgorithm.from_jwk(jwk)
    return public_key


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> User:
    """
    Validate JWT token against Azure AD and return User object
    
    This validates:
    - Token signature using JWKS from Azure AD
    - Token expiration
    - Issuer (Azure AD tenant)
    - Audience (your client ID)
    
    For development, set SKIP_TOKEN_VERIFICATION=true in .env
    """
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authorization header"
        )
    
    token = credentials.credentials
    
    try:
        # Development mode - skip verification
        if settings.skip_token_verification:
            logger.warning("⚠️  SKIP_TOKEN_VERIFICATION is enabled - not validating signature!")
            decoded = jwt.decode(
                token, 
                options={"verify_signature": False, "verify_exp": False},
                algorithms=["RS256"]
            )
            logger.info(f"Token decoded (no verification). Claims: {list(decoded.keys())}")
        else:
            # Production mode - full validation
            logger.info("Validating token with Azure AD JWKS")
            
            # Fetch JWKS
            jwks = await get_jwks()
            
            # Get public key for this token
            public_key = get_public_key(token, jwks)
            
            # Decode and validate token
            decoded = jwt.decode(
                token,
                public_key,
                algorithms=["RS256"],
                audience=settings.azure_client_id,
                options={
                    "verify_signature": True,
                    "verify_exp": True,
                    "verify_aud": True,
                }
            )
            
            # Validate issuer (accept both v1.0 and v2.0)
            iss = decoded.get("iss", "")
            expected_v2 = settings.get_issuer()
            expected_v1 = settings.get_issuer_v1()
            
            if iss not in [expected_v2, expected_v1]:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail=f"Invalid issuer. Expected {expected_v2} or {expected_v1}, got {iss}"
                )
            
            logger.info(f"Token validated successfully. Issuer: {iss}")
        
        # Convert to UserClaims and User
        user_claims = UserClaims(
            oid=decoded.get("oid", "unknown"),
            email=decoded.get("email"),
            preferred_username=decoded.get("preferred_username"),
            name=decoded.get("name"),
            tid=decoded.get("tid", "unknown"),
            roles=decoded.get("roles", []),
            groups=decoded.get("groups", []),
            aud=decoded.get("aud", ""),
            iss=decoded.get("iss", ""),
            iat=decoded.get("iat", 0),
            exp=decoded.get("exp", 0)
        )
        
        user = user_claims.to_user()
        logger.info(f"User authenticated: {user.email or user.preferred_username} ({user.id})")
        return user
        
    except jwt.ExpiredSignatureError:
        logger.error("Token has expired")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired"
        )
    except jwt.InvalidAudienceError as e:
        logger.error(f"Invalid audience: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token audience. Expected: {settings.azure_client_id}"
        )
    except jwt.InvalidTokenError as e:
        logger.error(f"Invalid token: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {str(e)}"
        )
    except httpx.HTTPError as e:
        logger.error(f"Failed to fetch JWKS: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to validate token - could not fetch JWKS"
        )
    except Exception as e:
        logger.error(f"Unexpected error during authentication: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Authentication error: {str(e)}"
        )

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables or .env file"""
    
    # Application settings
    app_name: str = "AI Chat Service"
    environment: str = "dev"
    debug: bool = False
    log_level: str = "info"
    
    # API settings
    api_version: str = "v1"
    
    # Azure AD JWT Authentication
    azure_tenant_id: str = ""
    azure_client_id: str = ""
    skip_token_verification: bool = False  # Set to true ONLY for development
    
    # Add your custom settings here
    # Example:
    # openai_api_key: str = ""
    # database_url: str = ""
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore"  # Ignore extra fields in .env
    )
    
    def get_issuer(self) -> str:
        """Get the expected JWT issuer (Azure AD v2.0 endpoint)"""
        return f"https://login.microsoftonline.com/{self.azure_tenant_id}/v2.0"
    
    def get_issuer_v1(self) -> str:
        """Get the expected JWT issuer (Azure AD v1.0 endpoint)"""
        return f"https://sts.windows.net/{self.azure_tenant_id}/"
    
    def get_jwks_url(self) -> str:
        """Get the JWKS URL for Azure AD"""
        return f"https://login.microsoftonline.com/{self.azure_tenant_id}/discovery/v2.0/keys"


# Create a single instance to be imported throughout the app
settings = Settings()

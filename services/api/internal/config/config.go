package config

import (
	"fmt"
	"os"
)

// Config holds the application configuration
type Config struct {
	AzureTenantID         string
	AzureClientID         string
	Port                  string
	SkipTokenVerification bool // For development only
}

// Load reads configuration from environment variables
func Load() (*Config, error) {
	tenantID := os.Getenv("AZURE_TENANT_ID")
	if tenantID == "" {
		return nil, fmt.Errorf("AZURE_TENANT_ID environment variable is required")
	}

	clientID := os.Getenv("AZURE_CLIENT_ID")
	if clientID == "" {
		return nil, fmt.Errorf("AZURE_CLIENT_ID environment variable is required")
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	skipVerification := os.Getenv("SKIP_TOKEN_VERIFICATION") == "true"
	if skipVerification {
		fmt.Println("⚠️  WARNING: Token signature verification is DISABLED - for development only!")
	}

	return &Config{
		AzureTenantID:         tenantID,
		AzureClientID:         clientID,
		Port:                  port,
		SkipTokenVerification: skipVerification,
	}, nil
}

// GetJWKSURL returns the Azure AD JWKS URL for token validation
func (c *Config) GetJWKSURL() string {
	return fmt.Sprintf("https://login.microsoftonline.com/%s/discovery/v2.0/keys", c.AzureTenantID)
}

// GetIssuer returns the expected token issuer
func (c *Config) GetIssuer() string {
	return fmt.Sprintf("https://login.microsoftonline.com/%s/v2.0", c.AzureTenantID)
}

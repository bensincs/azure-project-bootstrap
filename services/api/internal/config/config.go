package config

import (
	"fmt"
	"log"

	"github.com/spf13/viper"
)

// Config holds the application configuration
type Config struct {
	AzureTenantID         string
	AzureClientID         string
	Port                  string
	SkipTokenVerification bool // For development only
}

// Load reads configuration from .env file and environment variables
func Load() (*Config, error) {
	// Set up Viper to read from .env file
	viper.SetConfigName(".env")
	viper.SetConfigType("env")
	viper.AddConfigPath(".")

	// Allow environment variables to override .env file
	viper.AutomaticEnv()

	// Read the .env file (if it exists)
	if err := viper.ReadInConfig(); err != nil {
		// .env file is optional if all env vars are set
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("error reading config file: %w", err)
		}
		log.Println("⚠️  No .env file found, using environment variables only")
	} else {
		log.Printf("✅ Loaded configuration from: %s\n", viper.ConfigFileUsed())
	}

	// Read required configuration
	tenantID := viper.GetString("AZURE_TENANT_ID")
	if tenantID == "" {
		return nil, fmt.Errorf("AZURE_TENANT_ID is required (set in .env or environment)")
	}

	clientID := viper.GetString("AZURE_CLIENT_ID")
	if clientID == "" {
		return nil, fmt.Errorf("AZURE_CLIENT_ID is required (set in .env or environment)")
	}

	port := viper.GetString("PORT")
	if port == "" {
		port = "8080"
	}

	skipVerification := viper.GetBool("SKIP_TOKEN_VERIFICATION")
	if skipVerification {
		log.Println("⚠️  WARNING: Token signature verification is DISABLED - for development only!")
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

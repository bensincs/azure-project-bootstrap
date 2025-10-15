package middleware

import (
	"context"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"strings"
	"sync"
	"time"

	"api-service/internal/config"
	"api-service/internal/models"

	"github.com/golang-jwt/jwt/v5"
)

// contextKey is a custom type for context keys to avoid collisions
type contextKey string

const (
	// UserContextKey is the key for storing user in context
	UserContextKey contextKey = "user"
)

// JWK represents a JSON Web Key
type JWK struct {
	Kid string   `json:"kid"`
	Kty string   `json:"kty"`
	Use string   `json:"use"`
	N   string   `json:"n"`
	E   string   `json:"e"`
	X5c []string `json:"x5c"`
}

// JWKSet represents a set of JSON Web Keys
type JWKSet struct {
	Keys []JWK `json:"keys"`
}

// AuthMiddleware handles JWT authentication
type AuthMiddleware struct {
	config     *config.Config
	jwks       map[string]*rsa.PublicKey
	jwksMutex  sync.RWMutex
	lastUpdate time.Time
}

// NewAuthMiddleware creates a new authentication middleware
func NewAuthMiddleware(cfg *config.Config) *AuthMiddleware {
	am := &AuthMiddleware{
		config: cfg,
		jwks:   make(map[string]*rsa.PublicKey),
	}

	// Load JWKS on initialization
	if err := am.refreshJWKS(); err != nil {
		log.Printf("Warning: Failed to load JWKS on startup: %v", err)
	}

	return am
}

// Middleware wraps an http.Handler with JWT authentication
func (am *AuthMiddleware) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Extract token from Authorization header
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, "Missing authorization header", http.StatusUnauthorized)
			return
		}

		// Check for Bearer token
		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			http.Error(w, "Invalid authorization header format", http.StatusUnauthorized)
			return
		}

		tokenString := parts[1]

		// Parse and validate token
		user, err := am.validateToken(tokenString)
		if err != nil {
			log.Printf("Token validation failed: %v", err)
			http.Error(w, fmt.Sprintf("Invalid token: %v", err), http.StatusUnauthorized)
			return
		}

		// Add user to context
		ctx := context.WithValue(r.Context(), UserContextKey, user)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// validateToken validates and parses a JWT token
func (am *AuthMiddleware) validateToken(tokenString string) (*models.User, error) {
	// Skip verification mode for development/debugging
	if am.config.SkipTokenVerification {
		log.Printf("⚠️  Skipping token signature verification (development mode)")
		parser := jwt.NewParser(jwt.WithoutClaimsValidation())
		token, _, err := parser.ParseUnverified(tokenString, jwt.MapClaims{})
		if err != nil {
			return nil, fmt.Errorf("failed to parse token: %w", err)
		}

		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			return nil, fmt.Errorf("invalid token claims")
		}

		userClaims, err := am.mapClaimsToUserClaims(claims)
		if err != nil {
			return nil, fmt.Errorf("failed to map claims: %w", err)
		}

		return userClaims.ToUser(), nil
	}

	// Refresh JWKS if needed (cache for 1 hour)
	if time.Since(am.lastUpdate) > time.Hour {
		if err := am.refreshJWKS(); err != nil {
			log.Printf("Failed to refresh JWKS: %v", err)
		}
	}

	// Parse token without validation first to inspect claims for debugging
	unverifiedToken, _, err := new(jwt.Parser).ParseUnverified(tokenString, jwt.MapClaims{})
	if err == nil {
		if claims, ok := unverifiedToken.Claims.(jwt.MapClaims); ok {
			log.Printf("Token claims (unverified): iss=%v, aud=%v, kid=%v", claims["iss"], claims["aud"], unverifiedToken.Header["kid"])
		}
	}

	// Parse token with validation
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		// Verify signing method
		if _, ok := token.Method.(*jwt.SigningMethodRSA); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}

		// Get key ID from token header
		kid, ok := token.Header["kid"].(string)
		if !ok {
			return nil, fmt.Errorf("kid header not found")
		}

		log.Printf("Looking for public key with kid: %s", kid)

		// Get public key from JWKS
		am.jwksMutex.RLock()
		publicKey, exists := am.jwks[kid]
		am.jwksMutex.RUnlock()

		if !exists {
			// Try refreshing JWKS if key not found
			log.Printf("Public key not found for kid: %s, refreshing JWKS...", kid)
			if err := am.refreshJWKS(); err != nil {
				return nil, fmt.Errorf("failed to refresh JWKS: %w", err)
			}
			am.jwksMutex.RLock()
			publicKey, exists = am.jwks[kid]
			am.jwksMutex.RUnlock()

			if !exists {
				return nil, fmt.Errorf("public key not found for kid: %s after refresh", kid)
			}
		}

		log.Printf("Found public key for kid: %s", kid)
		return publicKey, nil
	})

	if err != nil {
		return nil, fmt.Errorf("failed to parse token: %w", err)
	}

	if !token.Valid {
		return nil, fmt.Errorf("invalid token")
	}

	// Extract claims
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, fmt.Errorf("invalid token claims")
	}

	// Validate issuer - Azure AD can use different issuer formats
	iss, ok := claims["iss"].(string)
	if !ok {
		return nil, fmt.Errorf("issuer claim not found")
	}

	// Accept both v2.0 and v1.0 issuer formats
	expectedIssuerV2 := am.config.GetIssuer()
	expectedIssuerV1 := fmt.Sprintf("https://sts.windows.net/%s/", am.config.AzureTenantID)

	if iss != expectedIssuerV2 && iss != expectedIssuerV1 {
		return nil, fmt.Errorf("invalid issuer: expected %s or %s, got %s", expectedIssuerV2, expectedIssuerV1, iss)
	}

	// Validate audience (client ID)
	aud, ok := claims["aud"].(string)
	if !ok || aud != am.config.AzureClientID {
		return nil, fmt.Errorf("invalid audience: expected %s, got %s", am.config.AzureClientID, aud)
	}

	// Convert claims to UserClaims
	userClaims, err := am.mapClaimsToUserClaims(claims)
	if err != nil {
		return nil, fmt.Errorf("failed to map claims: %w", err)
	}

	return userClaims.ToUser(), nil
}

// mapClaimsToUserClaims converts jwt.MapClaims to UserClaims
func (am *AuthMiddleware) mapClaimsToUserClaims(claims jwt.MapClaims) (*models.UserClaims, error) {
	userClaims := &models.UserClaims{}

	// Extract required claims
	if oid, ok := claims["oid"].(string); ok {
		userClaims.Oid = oid
	}

	if email, ok := claims["email"].(string); ok {
		userClaims.Email = email
	}

	if preferredUsername, ok := claims["preferred_username"].(string); ok {
		userClaims.PreferredUsername = preferredUsername
	}

	if name, ok := claims["name"].(string); ok {
		userClaims.Name = name
	}

	if tid, ok := claims["tid"].(string); ok {
		userClaims.Tid = tid
	}

	if aud, ok := claims["aud"].(string); ok {
		userClaims.Aud = aud
	}

	if iss, ok := claims["iss"].(string); ok {
		userClaims.Iss = iss
	}

	// Extract timestamps
	if iat, ok := claims["iat"].(float64); ok {
		userClaims.Iat = int64(iat)
	}

	if exp, ok := claims["exp"].(float64); ok {
		userClaims.Exp = int64(exp)
	}

	// Extract optional array claims
	if roles, ok := claims["roles"].([]interface{}); ok {
		userClaims.Roles = make([]string, len(roles))
		for i, role := range roles {
			if roleStr, ok := role.(string); ok {
				userClaims.Roles[i] = roleStr
			}
		}
	}

	if groups, ok := claims["groups"].([]interface{}); ok {
		userClaims.Groups = make([]string, len(groups))
		for i, group := range groups {
			if groupStr, ok := group.(string); ok {
				userClaims.Groups[i] = groupStr
			}
		}
	}

	return userClaims, nil
}

// refreshJWKS fetches and caches the JWKS from Azure AD
func (am *AuthMiddleware) refreshJWKS() error {
	jwksURL := am.config.GetJWKSURL()
	log.Printf("Fetching JWKS from: %s", jwksURL)

	resp, err := http.Get(jwksURL)
	if err != nil {
		return fmt.Errorf("failed to fetch JWKS: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("JWKS endpoint returned status: %d", resp.StatusCode)
	}

	var jwkSet JWKSet
	if err := json.NewDecoder(resp.Body).Decode(&jwkSet); err != nil {
		return fmt.Errorf("failed to decode JWKS: %w", err)
	}

	log.Printf("Received %d keys from JWKS endpoint", len(jwkSet.Keys))

	// Convert JWKs to RSA public keys
	newJWKS := make(map[string]*rsa.PublicKey)
	for i, jwk := range jwkSet.Keys {
		if jwk.Kty != "RSA" {
			log.Printf("Skipping non-RSA key %d (type: %s)", i, jwk.Kty)
			continue
		}

		log.Printf("Processing JWK %d: kid=%s, use=%s, n_len=%d, e_len=%d", i, jwk.Kid, jwk.Use, len(jwk.N), len(jwk.E))

		publicKey, err := am.jwkToRSAPublicKey(jwk)
		if err != nil {
			log.Printf("Failed to convert JWK kid=%s to RSA public key: %v", jwk.Kid, err)
			continue
		}

		newJWKS[jwk.Kid] = publicKey
		log.Printf("Successfully loaded public key for kid=%s", jwk.Kid)
	}

	if len(newJWKS) == 0 {
		return fmt.Errorf("no valid RSA keys found in JWKS")
	}

	// Update cached JWKS
	am.jwksMutex.Lock()
	am.jwks = newJWKS
	am.lastUpdate = time.Now()
	am.jwksMutex.Unlock()

	log.Printf("Refreshed JWKS: loaded %d keys", len(newJWKS))
	for kid := range newJWKS {
		log.Printf("  - kid: %s", kid)
	}
	return nil
}

// jwkToRSAPublicKey converts a JWK to an RSA public key
func (am *AuthMiddleware) jwkToRSAPublicKey(jwk JWK) (*rsa.PublicKey, error) {
	// Decode the modulus - try RawURLEncoding first, then RawStdEncoding
	nBytes, err := base64.RawURLEncoding.DecodeString(jwk.N)
	if err != nil {
		// Try standard base64 encoding
		nBytes, err = base64.RawStdEncoding.DecodeString(jwk.N)
		if err != nil {
			// Try with padding
			nBytes, err = base64.URLEncoding.DecodeString(jwk.N)
			if err != nil {
				nBytes, err = base64.StdEncoding.DecodeString(jwk.N)
				if err != nil {
					return nil, fmt.Errorf("failed to decode modulus with any base64 encoding: %w", err)
				}
			}
		}
	}

	// Decode the exponent - try RawURLEncoding first, then RawStdEncoding
	eBytes, err := base64.RawURLEncoding.DecodeString(jwk.E)
	if err != nil {
		// Try standard base64 encoding
		eBytes, err = base64.RawStdEncoding.DecodeString(jwk.E)
		if err != nil {
			// Try with padding
			eBytes, err = base64.URLEncoding.DecodeString(jwk.E)
			if err != nil {
				eBytes, err = base64.StdEncoding.DecodeString(jwk.E)
				if err != nil {
					return nil, fmt.Errorf("failed to decode exponent with any base64 encoding: %w", err)
				}
			}
		}
	}

	// Convert bytes to big.Int
	n := new(big.Int).SetBytes(nBytes)

	// Convert exponent bytes to int
	var e int
	for _, b := range eBytes {
		e = e*256 + int(b)
	}

	log.Printf("Created RSA public key: n_bits=%d, e=%d", n.BitLen(), e)

	return &rsa.PublicKey{
		N: n,
		E: e,
	}, nil
}

// GetUserFromContext extracts the user from the request context
func GetUserFromContext(ctx context.Context) (*models.User, bool) {
	user, ok := ctx.Value(UserContextKey).(*models.User)
	return user, ok
}

package middleware

import (
	"net/http"
	"strings"
)

// CORSConfig holds CORS configuration
type CORSConfig struct {
	AllowedOrigins   []string
	AllowedMethods   []string
	AllowedHeaders   []string
	ExposedHeaders   []string
	AllowCredentials bool
}

// DefaultCORSConfig returns a permissive CORS configuration for development
func DefaultCORSConfig() *CORSConfig {
	return &CORSConfig{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: false,
	}
}

// ProductionCORSConfig returns a more restrictive CORS configuration
func ProductionCORSConfig(allowedOrigins []string) *CORSConfig {
	return &CORSConfig{
		AllowedOrigins:   allowedOrigins,
		AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
	}
}

// CORSMiddleware handles CORS headers
type CORSMiddleware struct {
	config *CORSConfig
}

// NewCORSMiddleware creates a new CORS middleware
func NewCORSMiddleware(config *CORSConfig) *CORSMiddleware {
	if config == nil {
		config = DefaultCORSConfig()
	}
	return &CORSMiddleware{
		config: config,
	}
}

// Middleware wraps an http.Handler with CORS support
func (cm *CORSMiddleware) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")

		// Check if origin is allowed
		if cm.isOriginAllowed(origin) {
			w.Header().Set("Access-Control-Allow-Origin", origin)
		} else if len(cm.config.AllowedOrigins) == 1 && cm.config.AllowedOrigins[0] == "*" {
			w.Header().Set("Access-Control-Allow-Origin", "*")
		}

		// Set other CORS headers
		if cm.config.AllowCredentials {
			w.Header().Set("Access-Control-Allow-Credentials", "true")
		}

		if len(cm.config.AllowedMethods) > 0 {
			w.Header().Set("Access-Control-Allow-Methods", strings.Join(cm.config.AllowedMethods, ", "))
		}

		if len(cm.config.AllowedHeaders) > 0 {
			w.Header().Set("Access-Control-Allow-Headers", strings.Join(cm.config.AllowedHeaders, ", "))
		}

		if len(cm.config.ExposedHeaders) > 0 {
			w.Header().Set("Access-Control-Expose-Headers", strings.Join(cm.config.ExposedHeaders, ", "))
		}

		// Handle preflight requests
		if r.Method == http.MethodOptions {
			w.Header().Set("Access-Control-Max-Age", "86400") // 24 hours
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// isOriginAllowed checks if the origin is in the allowed list
func (cm *CORSMiddleware) isOriginAllowed(origin string) bool {
	for _, allowedOrigin := range cm.config.AllowedOrigins {
		if allowedOrigin == "*" || allowedOrigin == origin {
			return true
		}
		// Support wildcard subdomains like *.example.com
		if strings.HasPrefix(allowedOrigin, "*.") {
			domain := allowedOrigin[2:]
			if strings.HasSuffix(origin, domain) {
				return true
			}
		}
	}
	return false
}

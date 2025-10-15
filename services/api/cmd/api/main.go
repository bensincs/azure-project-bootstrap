package main

import (
	"log"
	"net/http"

	"api-service/internal/config"
	"api-service/internal/events"
	"api-service/internal/handlers"
	"api-service/internal/middleware"
)

const (
	serviceName = "api-service"
	version     = "1.0.0"
)

func main() {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	log.Printf("✅ Configuration loaded")
	log.Printf("   Tenant ID: %s", cfg.AzureTenantID)
	log.Printf("   Client ID: %s", cfg.AzureClientID)

	// Initialize event manager
	eventManager := events.NewManager()
	handlers.EventManager = eventManager
	go eventManager.Run()
	log.Printf("🎯 Event manager started")

	// Initialize middleware
	corsMiddleware := middleware.NewCORSMiddleware(middleware.DefaultCORSConfig())
	authMiddleware := middleware.NewAuthMiddleware(cfg)

	// Initialize handlers
	healthHandler := handlers.NewHealthHandler(serviceName, version)
	userHandler := handlers.NewUserHandler()

	// Set up routes with CORS
	http.Handle("/api/health", corsMiddleware.Middleware(healthHandler))
	http.Handle("/api/user/me", corsMiddleware.Middleware(authMiddleware.Middleware(userHandler)))

	// Chat endpoints
	// WebSocket endpoint - Browser WebSocket API cannot send custom Authorization headers,
	// so we extract the JWT token from the query parameter and inject it into the header
	// before passing the request to the auth middleware.
	http.HandleFunc("/api/ws", func(w http.ResponseWriter, r *http.Request) {
		token := r.URL.Query().Get("token")
		if token != "" {
			r.Header.Set("Authorization", "Bearer "+token)
		}
		authHandler := authMiddleware.Middleware(http.HandlerFunc(handlers.HandleWebSocket))
		authHandler.ServeHTTP(w, r)
	})
	http.Handle("/api/users/active", corsMiddleware.Middleware(authMiddleware.Middleware(http.HandlerFunc(handlers.GetActiveUsers))))
	http.Handle("/api/messages/send", corsMiddleware.Middleware(authMiddleware.Middleware(http.HandlerFunc(handlers.SendMessage))))

	// Start server
	log.Printf("🚀 %s v%s starting on port %s", serviceName, version, cfg.Port)
	log.Printf("📍 Endpoints:")
	log.Printf("   GET /api/health - Health Check (public)")
	log.Printf("   GET /api/user/me - Get Current User (authenticated)")
	log.Printf("   GET /api/ws - WebSocket Connection (authenticated)")
	log.Printf("   GET /api/users/active - Get Active Users (authenticated)")
	log.Printf("   POST /api/messages/send - Send Chat Message (authenticated)")

	if err := http.ListenAndServe(":"+cfg.Port, nil); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}

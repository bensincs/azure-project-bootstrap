package main

import (
	"log"
	"net/http"
	"os"

	"api-service/internal/handlers"
)

const (
	serviceName = "api-service"
	version     = "1.0.0"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Initialize handlers
	healthHandler := handlers.NewHealthHandler(serviceName, version)

	// Set up routes
	http.Handle("/api/health", healthHandler)

	// Start server
	log.Printf("🚀 %s v%s starting on port %s", serviceName, version, port)
	log.Printf("📍 Endpoints:")
	log.Printf("   GET /api/health - Health Check")

	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}

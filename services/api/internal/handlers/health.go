package handlers

import (
	"encoding/json"
	"log"
	"net/http"

	"api-service/internal/models"
)

// HealthHandler handles health check requests
type HealthHandler struct {
	serviceName string
	version     string
}

// NewHealthHandler creates a new health handler
func NewHealthHandler(serviceName, version string) *HealthHandler {
	return &HealthHandler{
		serviceName: serviceName,
		version:     version,
	}
}

// ServeHTTP handles the health check endpoint
func (h *HealthHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	response := models.HealthResponse{
		Status:  "healthy",
		Service: h.serviceName,
		Version: h.version,
	}

	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Printf("Error encoding health response: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	log.Printf("Health check from %s", r.RemoteAddr)
}

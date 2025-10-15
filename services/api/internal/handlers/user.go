package handlers

import (
	"encoding/json"
	"log"
	"net/http"

	"api-service/internal/middleware"
	"api-service/internal/models"
)

// UserHandler handles user-related requests
type UserHandler struct{}

// NewUserHandler creates a new user handler
func NewUserHandler() *UserHandler {
	return &UserHandler{}
}

// ServeHTTP handles the /api/user/me endpoint
func (h *UserHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// Only allow GET requests
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Get user from context (populated by auth middleware)
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		log.Printf("User not found in context")
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// Return user information
	w.Header().Set("Content-Type", "application/json")

	if err := json.NewEncoder(w).Encode(user); err != nil {
		log.Printf("Error encoding user response: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	log.Printf("User info retrieved for: %s (%s)", user.Email, user.ID)
}

// UserResponse is an optional wrapper if you want to add metadata
type UserResponse struct {
	User *models.User `json:"user"`
}

package handlers

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/gorilla/websocket"

	"api-service/internal/events"
	"api-service/internal/middleware"
	"api-service/internal/models"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		// Allow all origins in development
		// In production, validate the origin
		return true
	},
}

// EventManager is the global event manager
var EventManager *events.Manager

// HandleWebSocket handles WebSocket connections
// The auth middleware must be applied before this handler to set user in context
func HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	// Get user from context (set by auth middleware)
	userInterface := r.Context().Value(middleware.UserContextKey)
	if userInterface == nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	user, ok := userInterface.(*models.User)
	if !ok {
		http.Error(w, "Invalid user context", http.StatusInternalServerError)
		return
	}

	// Upgrade HTTP connection to WebSocket
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("Failed to upgrade WebSocket connection: %v", err)
		return
	}

	// Create a new client
	client := &events.Client{
		ID:    user.ID,
		Name:  user.Name,
		Email: user.Email,
		Conn:  conn,
	}

	// Initialize the send channel
	client.InitSendChannel(256)

	// Register the client
	EventManager.RegisterClient(client)

	// Start the client's pumps
	client.Start()

	log.Printf("WebSocket connected: %s (%s)", user.Name, user.Email)
}

// GetActiveUsers returns all currently connected users
func GetActiveUsers(w http.ResponseWriter, r *http.Request) {
	users := EventManager.GetActiveUsers()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"users": users,
		"count": len(users),
	})
}

// SendMessageRequest represents a message send request
type SendMessageRequest struct {
	To      string `json:"to"`
	Content string `json:"content"`
}

// SendMessage sends a message to a specific user
func SendMessage(w http.ResponseWriter, r *http.Request) {
	// Get sender from context
	userInterface := r.Context().Value(middleware.UserContextKey)
	if userInterface == nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	sender, ok := userInterface.(*models.User)
	if !ok {
		http.Error(w, "Invalid user context", http.StatusInternalServerError)
		return
	}

	// Parse request body
	var req SendMessageRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	if req.To == "" || req.Content == "" {
		http.Error(w, "Missing 'to' or 'content' field", http.StatusBadRequest)
		return
	}

	// Create and send chat event
	event := events.NewChatEvent(sender.ID, sender.Name, sender.Email, req.Content)
	sent := EventManager.SendEventToUser(req.To, event)
	if !sent {
		http.Error(w, "User not connected or unreachable", http.StatusNotFound)
		return
	}

	log.Printf("Message sent from %s to %s", sender.Name, req.To)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": "Message sent",
	})
}

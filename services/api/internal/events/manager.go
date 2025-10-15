package events

import (
	"encoding/json"
	"log"
	"sync"

	"github.com/gorilla/websocket"
)

// Client represents a connected WebSocket client
type Client struct {
	ID      string          // User ID from JWT
	Name    string          // User display name
	Email   string          // User email
	Conn    *websocket.Conn // WebSocket connection
	send    chan []byte     // Buffered channel for outbound messages
	manager *Manager        // Reference to the manager
}

// InitSendChannel initializes the send channel
func (c *Client) InitSendChannel(size int) {
	c.send = make(chan []byte, size)
}

// SetManager sets the manager reference
func (c *Client) SetManager(m *Manager) {
	c.manager = m
}

// Manager manages all active WebSocket connections and event distribution
type Manager struct {
	clients    map[string]*Client // User ID -> Client
	register   chan *Client       // Register requests
	unregister chan *Client       // Unregister requests
	mu         sync.RWMutex       // Protect clients map
}

// NewManager creates a new event manager
func NewManager() *Manager {
	return &Manager{
		clients:    make(map[string]*Client),
		register:   make(chan *Client),
		unregister: make(chan *Client),
	}
}

// Run starts the manager's main loop
func (m *Manager) Run() {
	for {
		select {
		case client := <-m.register:
			m.registerClient(client)
		case client := <-m.unregister:
			m.unregisterClient(client)
		}
	}
}

// registerClient registers a new client
func (m *Manager) registerClient(client *Client) {
	m.mu.Lock()
	m.clients[client.ID] = client
	m.mu.Unlock()

	log.Printf("Client connected: %s (%s)", client.Name, client.ID)
	log.Printf("Active connections: %d", len(m.clients))

	// Send a welcome message to the newly connected client
	welcomeEvent := NewUserJoinedEvent(client.ID, client.Name, client.Email)
	welcomeBytes, err := json.Marshal(welcomeEvent)
	if err == nil {
		select {
		case client.send <- welcomeBytes:
			log.Printf("Sent welcome message to %s", client.Name)
		default:
			log.Printf("Failed to send welcome message to %s (channel full)", client.Name)
		}
	}

	// Notify all clients that a user joined
	m.BroadcastEvent(NewUserJoinedEvent(client.ID, client.Name, client.Email))
}

// unregisterClient unregisters a client
func (m *Manager) unregisterClient(client *Client) {
	m.mu.Lock()
	if _, ok := m.clients[client.ID]; ok {
		delete(m.clients, client.ID)
		close(client.send)
	}
	m.mu.Unlock()

	log.Printf("Client disconnected: %s (%s)", client.Name, client.ID)
	log.Printf("Active connections: %d", len(m.clients))

	// Notify all clients that a user left
	m.BroadcastEvent(NewUserLeftEvent(client.ID, client.Name, client.Email))
}

// RegisterClient queues a client for registration
func (m *Manager) RegisterClient(client *Client) {
	client.SetManager(m)
	m.register <- client
}

// UnregisterClient queues a client for unregistration
func (m *Manager) UnregisterClient(client *Client) {
	m.unregister <- client
}

// GetActiveUsers returns a list of all connected users
func (m *Manager) GetActiveUsers() []map[string]string {
	m.mu.RLock()
	defer m.mu.RUnlock()

	users := make([]map[string]string, 0, len(m.clients))
	for _, client := range m.clients {
		users = append(users, map[string]string{
			"id":    client.ID,
			"name":  client.Name,
			"email": client.Email,
		})
	}
	return users
}

// SendEventToUser sends an event to a specific user
func (m *Manager) SendEventToUser(userID string, event *Event) bool {
	m.mu.RLock()
	client, exists := m.clients[userID]
	m.mu.RUnlock()

	if !exists {
		return false
	}

	eventBytes, err := json.Marshal(event)
	if err != nil {
		log.Printf("Failed to marshal event: %v", err)
		return false
	}

	select {
	case client.send <- eventBytes:
		return true
	default:
		// Channel is full, close the connection
		m.UnregisterClient(client)
		return false
	}
}

// BroadcastEvent sends an event to all connected clients
func (m *Manager) BroadcastEvent(event *Event) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	eventBytes, err := json.Marshal(event)
	if err != nil {
		log.Printf("Failed to marshal event: %v", err)
		return
	}

	for _, client := range m.clients {
		select {
		case client.send <- eventBytes:
		default:
			// Channel is full, close the connection
			go m.UnregisterClient(client)
		}
	}
}

// Start begins the client's read and write pumps
func (c *Client) Start() {
	go c.writePump()
	go c.readPump()
}

// readPump handles incoming messages from the WebSocket
func (c *Client) readPump() {
	defer func() {
		log.Printf("readPump ending for client %s (%s)", c.Name, c.ID)
		c.manager.UnregisterClient(c)
		c.Conn.Close()
	}()

	log.Printf("readPump started for client %s (%s)", c.Name, c.ID)

	for {
		_, _, err := c.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket error for %s: %v", c.Name, err)
			} else {
				log.Printf("WebSocket closed normally for %s", c.Name)
			}
			break
		}
		// We don't expect clients to send messages through WebSocket
		// All actions should go through REST API
	}
}

// writePump handles outgoing messages to the WebSocket
func (c *Client) writePump() {
	defer c.Conn.Close()

	log.Printf("writePump started for client %s (%s)", c.Name, c.ID)

	for message := range c.send {
		log.Printf("Sending message to %s: %s", c.Name, string(message))
		if err := c.Conn.WriteMessage(websocket.TextMessage, message); err != nil {
			log.Printf("Write error for %s: %v", c.Name, err)
			return
		}
		log.Printf("Message sent successfully to %s", c.Name)
	}

	log.Printf("writePump ended for client %s (channel closed)", c.Name)
}

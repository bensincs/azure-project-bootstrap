package chat

import (
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

// Message represents a chat message
type Message struct {
	From    string `json:"from"`
	To      string `json:"to"`
	Content string `json:"content"`
	Type    string `json:"type"` // "chat", "system"
}

// Manager manages all active WebSocket connections
type Manager struct {
	clients    map[string]*Client // User ID -> Client
	register   chan *Client       // Register requests
	unregister chan *Client       // Unregister requests
	broadcast  chan *Message      // Broadcast messages to all clients
	mu         sync.RWMutex       // Protect clients map
}

// NewManager creates a new connection manager
func NewManager() *Manager {
	return &Manager{
		clients:    make(map[string]*Client),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		broadcast:  make(chan *Message),
	}
}

// RegisterClient registers a new client
func (m *Manager) RegisterClient(client *Client) {
	client.SetManager(m)
	m.register <- client
}

// Run starts the manager's main loop
func (m *Manager) Run() {
	for {
		select {
		case client := <-m.register:
			m.mu.Lock()
			m.clients[client.ID] = client
			m.mu.Unlock()
			log.Printf("✅ Client connected: %s (%s)", client.Name, client.ID)
			log.Printf("📊 Active connections: %d", len(m.clients))

		case client := <-m.unregister:
			m.mu.Lock()
			if _, ok := m.clients[client.ID]; ok {
				delete(m.clients, client.ID)
				close(client.send)
				log.Printf("❌ Client disconnected: %s (%s)", client.Name, client.ID)
				log.Printf("📊 Active connections: %d", len(m.clients))
			}
			m.mu.Unlock()

		case message := <-m.broadcast:
			m.mu.RLock()
			for _, client := range m.clients {
				select {
				case client.send <- []byte(message.Content):
				default:
					// Client's send buffer is full, disconnect
					close(client.send)
					delete(m.clients, client.ID)
				}
			}
			m.mu.RUnlock()
		}
	}
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

// SendToUser sends a message to a specific user
func (m *Manager) SendToUser(userID string, message []byte) bool {
	m.mu.RLock()
	client, exists := m.clients[userID]
	m.mu.RUnlock()

	if !exists {
		return false
	}

	select {
	case client.send <- message:
		return true
	default:
		// Buffer full, disconnect client
		m.unregister <- client
		return false
	}
}

// readPump pumps messages from the WebSocket connection to the hub
func (c *Client) readPump() {
	defer func() {
		c.manager.unregister <- c
		c.Conn.Close()
	}()

	for {
		_, _, err := c.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket error: %v", err)
			}
			break
		}
		// We don't process messages from client in this implementation
		// All messages are sent via REST API
	}
}

// writePump pumps messages from the hub to the WebSocket connection
func (c *Client) writePump() {
	defer func() {
		c.Conn.Close()
	}()

	for {
		message, ok := <-c.send
		if !ok {
			// Manager closed the channel
			c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
			return
		}

		w, err := c.Conn.NextWriter(websocket.TextMessage)
		if err != nil {
			return
		}
		w.Write(message)

		// Add queued messages to the current WebSocket message
		n := len(c.send)
		for i := 0; i < n; i++ {
			w.Write([]byte{'\n'})
			w.Write(<-c.send)
		}

		if err := w.Close(); err != nil {
			return
		}
	}
}

// Start starts the client's read and write pumps
func (c *Client) Start() {
	go c.writePump()
	go c.readPump()
}

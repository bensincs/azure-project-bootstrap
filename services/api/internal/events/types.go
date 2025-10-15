package events

// EventType represents the type of event being sent
type EventType string

const (
	EventTypeChat       EventType = "chat"
	EventTypeUserJoined EventType = "user_joined"
	EventTypeUserLeft   EventType = "user_left"
	// Add more event types as needed
)

// Event represents a generic event that can be sent through WebSocket
type Event struct {
	Type    EventType              `json:"type"`
	Payload map[string]interface{} `json:"payload"`
}

// ChatEvent represents a chat message event
type ChatEvent struct {
	From    string `json:"from"`
	Name    string `json:"name"`
	Email   string `json:"email"`
	Content string `json:"content"`
}

// UserEvent represents a user join/leave event
type UserEvent struct {
	UserID string `json:"user_id"`
	Name   string `json:"name"`
	Email  string `json:"email"`
}

// NewChatEvent creates a new chat event
func NewChatEvent(from, name, email, content string) *Event {
	return &Event{
		Type: EventTypeChat,
		Payload: map[string]interface{}{
			"from":    from,
			"name":    name,
			"email":   email,
			"content": content,
		},
	}
}

// NewUserJoinedEvent creates a new user joined event
func NewUserJoinedEvent(userID, name, email string) *Event {
	return &Event{
		Type: EventTypeUserJoined,
		Payload: map[string]interface{}{
			"user_id": userID,
			"name":    name,
			"email":   email,
		},
	}
}

// NewUserLeftEvent creates a new user left event
func NewUserLeftEvent(userID, name, email string) *Event {
	return &Event{
		Type: EventTypeUserLeft,
		Payload: map[string]interface{}{
			"user_id": userID,
			"name":    name,
			"email":   email,
		},
	}
}

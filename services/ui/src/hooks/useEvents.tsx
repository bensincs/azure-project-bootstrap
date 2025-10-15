import React, {
  createContext,
  useContext,
  useEffect,
  useRef,
  useCallback,
} from "react";
import { useAuth } from "./useAuth";

export type EventType = "chat" | "user_joined" | "user_left";

export interface BaseEvent {
  type: EventType;
  payload: Record<string, any>;
}

export interface ChatEvent extends BaseEvent {
  type: "chat";
  payload: {
    from: string;
    name: string;
    email: string;
    content: string;
  };
}

export interface UserEvent extends BaseEvent {
  type: "user_joined" | "user_left";
  payload: {
    user_id: string;
    name: string;
    email: string;
  };
}

export type Event = ChatEvent | UserEvent;

type EventHandler<T extends Event = Event> = (event: T) => void;

type ConnectionStatus = "disconnected" | "connecting" | "connected";

interface EventsContextValue {
  connectionStatus: ConnectionStatus;
  subscribe: (type: EventType, handler: EventHandler) => () => void;
  reconnect: () => void;
}

const EventsContext = createContext<EventsContextValue | undefined>(undefined);

interface EventsProviderProps {
  children: React.ReactNode;
}

export const EventsProvider: React.FC<EventsProviderProps> = ({ children }) => {
  const { user } = useAuth();
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimeoutRef = useRef<number | undefined>(undefined);
  const reconnectAttempts = useRef(0);
  const maxReconnectAttempts = 5;
  const wsUrl = import.meta.env.VITE_WS_URL || "ws://localhost:8080/api/ws";

  const handlersRef = useRef<Map<EventType, Set<EventHandler>>>(new Map());
  const [connectionStatus, setConnectionStatus] = React.useState<ConnectionStatus>("disconnected");

  const connect = useCallback(() => {
    if (!user || wsRef.current?.readyState === WebSocket.OPEN) {
      return;
    }

    console.log("Attempting WebSocket connection...");
    setConnectionStatus("connecting");

    const websocket = new WebSocket(`${wsUrl}?token=${user.access_token}`);

    websocket.onopen = () => {
      console.log("✅ WebSocket connected successfully");
      reconnectAttempts.current = 0;
      setConnectionStatus("connected");
    };

    websocket.onmessage = (event) => {
      try {
        const data: Event = JSON.parse(event.data);
        console.log("📩 Received event:", data);

        const handlers = handlersRef.current.get(data.type);
        if (handlers) {
          handlers.forEach((handler) => {
            try {
              handler(data);
            } catch (error) {
              console.error("Error in event handler:", error);
            }
          });
        }
      } catch (error) {
        console.error("Failed to parse event:", error);
      }
    };

    websocket.onerror = (error) => {
      console.error("❌ WebSocket error:", error);
      setConnectionStatus("disconnected");
    };

    websocket.onclose = () => {
      console.log("WebSocket disconnected");
      setConnectionStatus("disconnected");
      wsRef.current = null;

      if (reconnectAttempts.current < maxReconnectAttempts) {
        const delay = Math.min(
          1000 * Math.pow(2, reconnectAttempts.current),
          30000
        );
        reconnectAttempts.current++;
        console.log(
          `Reconnecting in ${delay}ms (attempt ${reconnectAttempts.current})`
        );

        reconnectTimeoutRef.current = window.setTimeout(() => {
          connect();
        }, delay);
      } else {
        console.error("Max reconnection attempts reached");
      }
    };

    wsRef.current = websocket;
  }, [user, wsUrl]);

  const subscribe = useCallback(
    (type: EventType, handler: EventHandler): (() => void) => {
      if (!handlersRef.current.has(type)) {
        handlersRef.current.set(type, new Set());
      }

      const handlers = handlersRef.current.get(type)!;
      handlers.add(handler);

      return () => {
        handlers.delete(handler);
        if (handlers.size === 0) {
          handlersRef.current.delete(type);
        }
      };
    },
    []
  );

  useEffect(() => {
    if (!user) {
      setConnectionStatus("disconnected");
      return;
    }

    connect();

    return () => {
      if (reconnectTimeoutRef.current) {
        clearTimeout(reconnectTimeoutRef.current);
      }
      if (wsRef.current) {
        wsRef.current.close();
        wsRef.current = null;
      }
    };
  }, [user, connect]);

  const value: EventsContextValue = {
    connectionStatus,
    subscribe,
    reconnect: connect,
  };

  return (
    <EventsContext.Provider value={value}>{children}</EventsContext.Provider>
  );
};

export const useEvents = (): EventsContextValue => {
  const context = useContext(EventsContext);
  if (!context) {
    throw new Error("useEvents must be used within an EventsProvider");
  }
  return context;
};

import type { Notification } from "../hooks/useNotifications";

interface NotificationToastProps {
  notification: Notification;
  onDismiss: (id: string) => void;
}

const typeStyles = {
  info: "bg-blue-500 border-blue-600",
  success: "bg-green-500 border-green-600",
  warning: "bg-yellow-500 border-yellow-600",
  error: "bg-red-500 border-red-600",
};

export function NotificationToast({
  notification,
  onDismiss,
}: NotificationToastProps) {
  const style = typeStyles[notification.type || "info"];

  return (
    <div
      className={`${style} text-white px-4 py-3 rounded-lg shadow-lg border-l-4 mb-3 animate-slide-in flex items-start justify-between`}
    >
      <div className="flex-1">
        {notification.title && (
          <h4 className="font-semibold mb-1">{notification.title}</h4>
        )}
        <p className="text-sm">{notification.message}</p>
        <p className="text-xs opacity-75 mt-1">
          {new Date(notification.timestamp).toLocaleTimeString()}
        </p>
      </div>
      <button
        onClick={() => onDismiss(notification.id)}
        className="ml-4 text-white hover:text-gray-200 focus:outline-none"
        aria-label="Dismiss notification"
      >
        <svg
          className="w-5 h-5"
          fill="none"
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth="2"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
  );
}

interface NotificationContainerProps {
  notifications: Notification[];
  onDismiss: (id: string) => void;
  isConnected: boolean;
}

export function NotificationContainer({
  notifications,
  onDismiss,
  isConnected,
}: NotificationContainerProps) {
  return (
    <div className="fixed top-4 right-4 z-50 w-96 max-w-full">
      {/* Connection Status */}
      <div
        className={`mb-3 px-3 py-2 rounded-lg text-sm ${
          isConnected
            ? "bg-green-100 text-green-800 border border-green-300"
            : "bg-yellow-100 text-yellow-800 border border-yellow-300"
        }`}
      >
        <div className="flex items-center">
          <div
            className={`w-2 h-2 rounded-full mr-2 ${
              isConnected ? "bg-green-500 animate-pulse" : "bg-yellow-500"
            }`}
          />
          {isConnected ? "Connected" : "Disconnected"}
        </div>
      </div>

      {/* Notifications */}
      {notifications.map((notification) => (
        <NotificationToast
          key={notification.id}
          notification={notification}
          onDismiss={onDismiss}
        />
      ))}
    </div>
  );
}

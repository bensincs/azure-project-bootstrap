import { useEffect, useRef, useState } from "react";
import type { CSSProperties, PointerEvent as ReactPointerEvent } from "react";
import type { Notification } from "../hooks/useNotifications";

interface NotificationToastProps {
  notification: Notification;
  onDismiss: (id: string) => void;
}

const typeStyles: Record<NonNullable<Notification["type"]>, { container: string; accent: string }> = {
  info: {
    container:
      "border-sky-400/50 bg-sky-500/10 text-sky-100 shadow-[0_0_35px_rgba(56,189,248,0.35)]",
    accent: "bg-sky-400",
  },
  success: {
    container:
      "border-emerald-400/50 bg-emerald-500/10 text-emerald-100 shadow-[0_0_35px_rgba(52,211,153,0.35)]",
    accent: "bg-emerald-400",
  },
  warning: {
    container:
      "border-amber-400/50 bg-amber-500/10 text-amber-100 shadow-[0_0_35px_rgba(251,191,36,0.35)]",
    accent: "bg-amber-400",
  },
  error: {
    container:
      "border-rose-400/50 bg-rose-500/10 text-rose-100 shadow-[0_0_35px_rgba(251,113,133,0.35)]",
    accent: "bg-rose-400",
  },
};

export function NotificationToast({
  notification,
  onDismiss,
}: NotificationToastProps) {
  const style = typeStyles[notification.type ?? "info"];

  return (
    <div
      className={`relative mb-4 flex items-center justify-between gap-4 overflow-hidden rounded-3xl border px-5 py-4 backdrop-blur animate-slide-in ${style.container}`}
    >
      <span className={`h-10 w-1 rounded-full ${style.accent}`} />
      <div className="flex-1">
        {notification.title && (
          <h4 className="text-sm font-semibold uppercase tracking-[0.25em]">
            {notification.title}
          </h4>
        )}
        <p className="mt-1 text-sm">{notification.message}</p>
        <p className="mt-2 text-[10px] uppercase tracking-[0.35em] opacity-60">
          {new Date(notification.timestamp).toLocaleTimeString()}
        </p>
      </div>
      <button
        onClick={() => onDismiss(notification.id)}
        className="ml-1 flex h-8 w-8 items-center justify-center rounded-full border border-white/20 bg-black/20 text-xs uppercase tracking-[0.35em] transition hover:border-white/40 hover:text-white"
        aria-label="Dismiss notification"
      >
        ✕
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
  const containerRef = useRef<HTMLDivElement>(null);
  const [position, setPosition] = useState<{ x: number; y: number } | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const dragState = useRef<{
    pointerId: number;
    offsetX: number;
    offsetY: number;
    width: number;
    height: number;
  } | null>(null);

  useEffect(() => {
    const clamp = (value: number, min: number, max: number) =>
      Math.min(Math.max(value, min), max);

    const handlePointerMove = (event: PointerEvent) => {
      if (!dragState.current) return;

      const { offsetX, offsetY, width, height } = dragState.current;
      const x = clamp(
        event.clientX - offsetX,
        12,
        Math.max(12, window.innerWidth - width - 12)
      );
      const y = clamp(
        event.clientY - offsetY,
        12,
        Math.max(12, window.innerHeight - height - 12)
      );

      setPosition({ x, y });
    };

    const handlePointerUp = (event: PointerEvent) => {
      if (dragState.current?.pointerId !== event.pointerId) return;

      dragState.current = null;
      setIsDragging(false);
      containerRef.current?.releasePointerCapture?.(event.pointerId);
    };

    window.addEventListener("pointermove", handlePointerMove);
    window.addEventListener("pointerup", handlePointerUp);
    window.addEventListener("pointercancel", handlePointerUp);

    return () => {
      window.removeEventListener("pointermove", handlePointerMove);
      window.removeEventListener("pointerup", handlePointerUp);
      window.removeEventListener("pointercancel", handlePointerUp);
    };
  }, []);

  const handlePointerDown = (event: ReactPointerEvent<HTMLDivElement>) => {
    if (!containerRef.current) return;

    const rect = containerRef.current.getBoundingClientRect();
    dragState.current = {
      pointerId: event.pointerId,
      offsetX: event.clientX - rect.left,
      offsetY: event.clientY - rect.top,
      width: rect.width,
      height: rect.height,
    };
    setIsDragging(true);
    containerRef.current.setPointerCapture?.(event.pointerId);
    event.preventDefault();
  };

  const containerStyle: CSSProperties = position
    ? { top: position.y, left: position.x }
    : { bottom: 24, right: 24 };

  return (
    <div
      ref={containerRef}
      style={containerStyle}
      className="fixed z-50 w-[420px] max-w-full text-xs text-slate-200"
    >
      <div
        data-drag-handle
        onPointerDown={handlePointerDown}
        className={`mb-4 flex items-center justify-between rounded-3xl border border-white/10 bg-white/10 px-4 py-3 backdrop-blur transition select-none ${
          isDragging ? "cursor-grabbing" : "cursor-grab"
        }`}
      >
        <div className="flex items-center gap-3">
          <span
            className={`h-2.5 w-2.5 rounded-full ${
              isConnected ? "bg-emerald-400 animate-pulse" : "bg-amber-400"
            }`}
          />
          <span className="tracking-[0.35em] uppercase">
            {isConnected ? "Link Stable" : "Link Lost"}
          </span>
        </div>
        <span className="rounded-full border border-white/10 px-3 py-1 text-[10px] uppercase tracking-[0.35em] text-slate-300">
          WS
        </span>
      </div>

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

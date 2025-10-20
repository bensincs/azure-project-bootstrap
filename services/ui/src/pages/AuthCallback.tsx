import { useEffect, useRef, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useAuth } from "../hooks/useAuth";
import AnimatedBackground from "../components/AnimatedBackground";
import { LoginButton } from "../components/LoginButton";

type CallbackStatus = "processing" | "success" | "error";

export const AuthCallback = () => {
  const { userManager } = useAuth();
  const navigate = useNavigate();
  const hasProcessed = useRef(false);
  const [searchParams] = useSearchParams();
  const [status, setStatus] = useState<CallbackStatus>("processing");
  const [message, setMessage] = useState(
    "We are finalizing your sign-in with Microsoft…"
  );
  const [errorDetail, setErrorDetail] = useState<string | null>(null);

  useEffect(() => {
    const errorFromQuery =
      searchParams.get("error_description") ||
      searchParams.get("error") ||
      searchParams.get("message");

    if (errorFromQuery) {
      setStatus("error");
      setMessage("We couldn't finish signing you in.");
      setErrorDetail(errorFromQuery);
      hasProcessed.current = true;
    }
  }, [searchParams]);

  useEffect(() => {
    // Prevent double-processing in React Strict Mode
    if (hasProcessed.current) return;
    hasProcessed.current = true;

    userManager
      .signinRedirectCallback()
      .then((user) => {
        setStatus("success");
        setMessage("Authentication complete. Redirecting you now…");

        const storedReturnUrl = sessionStorage.getItem("launchpad:returnUrl");
        const stateReturnUrl =
          typeof user?.state === "object" && user?.state
            ? (user.state as { returnUrl?: string }).returnUrl
            : undefined;

        const destination =
          stateReturnUrl && stateReturnUrl.startsWith("/")
            ? stateReturnUrl
            : storedReturnUrl && storedReturnUrl.startsWith("/")
            ? storedReturnUrl
            : "/app";

        sessionStorage.removeItem("launchpad:returnUrl");

        setTimeout(() => {
          navigate(destination, { replace: true });
        }, 900);
      })
      .catch((error) => {
        console.error("Authentication callback error:", error);
        setStatus("error");
        setMessage("We couldn't finish signing you in.");
        setErrorDetail(error?.message || "Unknown error");
      });
  }, [userManager, navigate]);

  return (
    <div className="relative min-h-screen overflow-hidden">
      <AnimatedBackground />
      <div className="relative z-10 flex min-h-screen items-center justify-center px-6">
        <div className="ui-panel max-w-xl text-center">
          <div className="mx-auto flex h-20 w-20 items-center justify-center rounded-2xl border border-white/10 bg-white/5">
            {status === "processing" && (
              <div className="h-10 w-10 animate-spin rounded-full border-2 border-cyan-400/70 border-t-transparent" />
            )}
            {status === "success" && (
              <span className="text-3xl" role="img" aria-label="success">
                ✅
              </span>
            )}
            {status === "error" && (
              <span className="text-3xl" role="img" aria-label="error">
                ⚠️
              </span>
            )}
          </div>
          <h1 className="mt-8 text-3xl font-semibold text-white">
            {status === "processing"
              ? "Completing sign-in"
              : status === "success"
              ? "You're authenticated"
              : "We hit a snag"}
          </h1>
          <p className="mt-4 text-sm text-slate-300">{message}</p>

          {status === "error" && errorDetail && (
            <div className="mt-6 rounded-2xl border border-red-500/30 bg-red-500/10 px-4 py-3 text-left text-sm text-red-200">
              <p className="text-xs uppercase tracking-[0.3em] text-red-300">
                Technical details
              </p>
              <p className="mt-1 leading-relaxed">{errorDetail}</p>
            </div>
          )}

          {status === "error" && (
            <div className="mt-6 flex flex-col items-center gap-3">
              <LoginButton
                variant="plain"
                label="Try signing in again"
                className="justify-center"
              />
              <button
                className="text-xs text-slate-400 underline decoration-dotted underline-offset-4 transition hover:text-slate-200"
                onClick={() => navigate("/")}
              >
                Back to start
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

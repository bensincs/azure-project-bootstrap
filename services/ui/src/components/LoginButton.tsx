import { useAuth } from "../hooks/useAuth";

interface LoginButtonProps {
  className?: string;
  label?: string;
}

const baseButtonStyles =
  "inline-flex items-center justify-center rounded-full bg-cyan-500 px-5 py-2 text-sm font-semibold text-slate-950 transition hover:bg-cyan-400 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan-400 disabled:cursor-not-allowed disabled:opacity-60";

export const LoginButton = ({
  className = "",
  label,
}: LoginButtonProps) => {
  const { userManager, user, isLoading } = useAuth();

  const buttonClassName = `${baseButtonStyles} ${className}`.trim();

  const handleLogin = () => {
    const params = new URLSearchParams(window.location.search);
    const requestedReturnUrl = params.get("returnUrl");
    const defaultReturnPath = window.location.pathname + window.location.search;
    const returnUrl =
      requestedReturnUrl && requestedReturnUrl.startsWith("/")
        ? requestedReturnUrl
        : defaultReturnPath || "/";

    sessionStorage.setItem("launchpad:returnUrl", returnUrl);

    userManager.signinRedirect({
      state: {
        returnUrl,
      },
    });
  };

  const handleLogout = () => {
    sessionStorage.removeItem("launchpad:returnUrl");
    userManager.signoutRedirect();
  };

  if (isLoading) {
    return (
      <button className={`${buttonClassName} cursor-wait opacity-70`} disabled>
        Checking session…
      </button>
    );
  }

  if (user) {
    return (
      <div className="flex items-center gap-2">
        <span className="text-sm text-slate-200">
          {user.profile.name || user.profile.email}
        </span>
        <button
          className="inline-flex items-center justify-center rounded-full border border-white/20 px-4 py-1.5 text-xs font-semibold text-slate-200 transition hover:border-white/40 hover:text-white"
          onClick={handleLogout}
        >
          Sign out
        </button>
      </div>
    );
  }

  return (
    <button className={buttonClassName} onClick={handleLogin}>
      {label ?? "Sign in"}
    </button>
  );
};

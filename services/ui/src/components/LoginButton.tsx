import { useAuth } from "../hooks/useAuth";

export const LoginButton = () => {
  const { userManager, user, isLoading } = useAuth();

  const handleLogin = () => {
    userManager.signinRedirect();
  };

  const handleLogout = () => {
    userManager.signoutRedirect();
  };

  if (isLoading) {
    return <button disabled>Loading...</button>;
  }

  if (user) {
    return (
      <div style={{ display: "flex", gap: "10px", alignItems: "center" }}>
        <span>Hello, {user.profile.name || user.profile.email}</span>
        <button onClick={handleLogout}>Logout</button>
      </div>
    );
  }

  return <button onClick={handleLogin}>Login</button>;
};

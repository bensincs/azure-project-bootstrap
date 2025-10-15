import { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../hooks/useAuth";

export const AuthCallback = () => {
  const { userManager } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    console.log("asdasd");
    userManager
      .signinRedirectCallback()
      .then(() => {
        console.log("asdasd");
        navigate("/");
      })
      .catch((error) => {
        console.error("Authentication callback error:", error);
        navigate("/");
      });
  }, [userManager, navigate]);

  return (
    <div
      style={{
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        height: "100vh",
        fontSize: "18px",
      }}
    >
      <p>Processing authentication...</p>
    </div>
  );
};

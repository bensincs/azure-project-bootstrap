import React, {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";
import { User, UserManager } from "oidc-client-ts";
import type { UserManagerSettings } from "oidc-client-ts";

interface AuthContextType {
  userManager: UserManager;
  user: User | null;
  isLoading: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

interface AuthProviderProps {
  config: UserManagerSettings;
  children: React.ReactNode;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({
  config,
  children,
}) => {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const userManager = useMemo(() => {
    return new UserManager({
      response_type: "code",
      ...config,
    });
  }, [config]);

  useEffect(() => {
    userManager
      .getUser()
      .then((loadedUser) => {
        setUser(loadedUser);
        setIsLoading(false);
      })
      .catch(() => {
        setIsLoading(false);
      });

    const onUserLoaded = (newUser: User) => setUser(newUser);
    const onUserUnloaded = () => setUser(null);

    userManager.events.addUserLoaded(onUserLoaded);
    userManager.events.addUserUnloaded(onUserUnloaded);

    return () => {
      userManager.events.removeUserLoaded(onUserLoaded);
      userManager.events.removeUserUnloaded(onUserUnloaded);
    };
  }, [userManager]);

  return (
    <AuthContext.Provider
      value={{
        userManager,
        user,
        isLoading,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
};

import { createContext, useContext, useState, useEffect, useCallback, ReactNode } from 'react';

export interface AccountProfile {
  id: string;
  email: string;
  full_name: string | null;
  id_type: string | null;
  profile_photo: string | null;
}

interface AuthState {
  account: AccountProfile | null;
  sessionToken: string | null;
  loading: boolean;
}

interface AuthContextValue extends AuthState {
  login: (token: string, account: AccountProfile) => void;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

const TOKEN_KEY = 'verifia_session_token';
const ACCOUNT_KEY = 'verifia_account';

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({
    account: null,
    sessionToken: null,
    loading: true,
  });

  // Restore session from localStorage on mount
  useEffect(() => {
    try {
      const token = localStorage.getItem(TOKEN_KEY);
      const accountJson = localStorage.getItem(ACCOUNT_KEY);
      if (token && accountJson) {
        const account = JSON.parse(accountJson) as AccountProfile;
        setState({ account, sessionToken: token, loading: false });
      } else {
        setState(s => ({ ...s, loading: false }));
      }
    } catch {
      setState(s => ({ ...s, loading: false }));
    }
  }, []);

  const login = useCallback((token: string, account: AccountProfile) => {
    localStorage.setItem(TOKEN_KEY, token);
    localStorage.setItem(ACCOUNT_KEY, JSON.stringify(account));
    setState({ account, sessionToken: token, loading: false });
  }, []);

  const logout = useCallback(() => {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(ACCOUNT_KEY);
    setState({ account: null, sessionToken: null, loading: false });
  }, []);

  return (
    <AuthContext.Provider value={{ ...state, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider');
  return ctx;
}

/** Returns the stored session token (for use in API client). */
export function getSessionToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

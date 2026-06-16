import {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
  useRef,
  type ReactNode,
} from 'react';
import { getChallengeHistory } from '../api/client.ts';
import { useAuth } from './AuthContext.tsx';

export interface SentChange {
  nonce: string;
  newStatus: 'REJECTED' | 'CANCELLED';
  targetEmail: string | null;
}

interface SentChangesContextValue {
  latestChange: SentChange | null;
  consumeLatestChange: () => void;
}

const SentChangesContext = createContext<SentChangesContextValue | null>(null);

const POLL_MS = 8000;

export function SentChangesProvider({ children }: { children: ReactNode }) {
  const { sessionToken } = useAuth();
  const [latestChange, setLatestChange] = useState<SentChange | null>(null);
  // Map nonce → status for previously seen challenges
  const prevStatusRef = useRef<Map<string, string>>(new Map());
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const poll = useCallback(async () => {
    if (!sessionToken) return;
    try {
      const res = await getChallengeHistory();
      for (const item of res.items) {
        const prev = prevStatusRef.current.get(item.nonce);
        if (prev === 'PENDING' && (item.status === 'REJECTED' || item.status === 'CANCELLED')) {
          setLatestChange({
            nonce: item.nonce,
            newStatus: item.status as 'REJECTED' | 'CANCELLED',
            targetEmail: item.target_email,
          });
        }
        prevStatusRef.current.set(item.nonce, item.status);
      }
    } catch {
      // network hiccup — keep polling
    }
  }, [sessionToken]);

  useEffect(() => {
    if (!sessionToken) {
      prevStatusRef.current.clear();
      return;
    }
    void poll();
    intervalRef.current = setInterval(() => { void poll(); }, POLL_MS);
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, [sessionToken, poll]);

  const consumeLatestChange = useCallback(() => {
    setLatestChange(null);
  }, []);

  return (
    <SentChangesContext.Provider value={{ latestChange, consumeLatestChange }}>
      {children}
    </SentChangesContext.Provider>
  );
}

export function useSentChanges(): SentChangesContextValue {
  const ctx = useContext(SentChangesContext);
  if (!ctx) throw new Error('useSentChanges must be used inside SentChangesProvider');
  return ctx;
}

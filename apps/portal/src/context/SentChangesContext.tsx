import {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
  useRef,
  type ReactNode,
} from 'react';
import { getChallengeHistory, type ChallengeHistoryItem } from '../api/client.ts';
import { useAuth } from './AuthContext.tsx';

export interface SentChange {
  nonce: string;
  newStatus: 'REJECTED' | 'CANCELLED' | 'USED';
  targetEmail: string | null;
  subjectFullName: string | null;
}

interface SentChangesContextValue {
  items: ChallengeHistoryItem[];
  loading: boolean;
  refresh: () => Promise<void>;
  latestChange: SentChange | null;
  consumeLatestChange: () => void;
}

const SentChangesContext = createContext<SentChangesContextValue | null>(null);

const POLL_MS = 8000;

export function SentChangesProvider({ children }: { children: ReactNode }) {
  const { sessionToken } = useAuth();
  const [items, setItems] = useState<ChallengeHistoryItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [latestChange, setLatestChange] = useState<SentChange | null>(null);
  // Map nonce → challenge status for previously seen challenges
  const prevStatusRef = useRef<Map<string, string>>(new Map());
  // Map nonce → token status to detect PENDING/IN_PROGRESS → USED transitions
  const prevTokenStatusRef = useRef<Map<string, string>>(new Map());
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const poll = useCallback(async () => {
    if (!sessionToken) return;
    try {
      const res = await getChallengeHistory();
      setItems(res.items);
      for (const item of res.items) {
        const prev = prevStatusRef.current.get(item.nonce);
        const prevToken = prevTokenStatusRef.current.get(item.nonce);
        const tokenStatus = item.token?.status ?? null;

        // USED: token completed (fires only after we've seen the item at least once)
        if (
          tokenStatus === 'USED' &&
          prevToken !== undefined &&
          prevToken !== 'USED'
        ) {
          setLatestChange({
            nonce: item.nonce,
            newStatus: 'USED',
            targetEmail: item.target_email,
            subjectFullName: item.subject?.full_name ?? null,
          });
        } else if (
          prev === 'PENDING' &&
          (item.status === 'REJECTED' || item.status === 'CANCELLED')
        ) {
          setLatestChange({
            nonce: item.nonce,
            newStatus: item.status as 'REJECTED' | 'CANCELLED',
            targetEmail: item.target_email,
            subjectFullName: item.subject?.full_name ?? null,
          });
        }

        prevStatusRef.current.set(item.nonce, item.status);
        if (tokenStatus) prevTokenStatusRef.current.set(item.nonce, tokenStatus);
      }
    } catch {
      // network hiccup — keep polling
    } finally {
      setLoading(false);
    }
  }, [sessionToken]);

  useEffect(() => {
    if (!sessionToken) {
      setItems([]);
      prevStatusRef.current.clear();
      prevTokenStatusRef.current.clear();
      return;
    }
    setLoading(true);
    void poll();
    intervalRef.current = setInterval(() => { void poll(); }, POLL_MS);
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, [sessionToken, poll]);

  const refresh = useCallback(async () => {
    setLoading(true);
    await poll();
  }, [poll]);

  const consumeLatestChange = useCallback(() => {
    setLatestChange(null);
  }, []);

  return (
    <SentChangesContext.Provider value={{ items, loading, refresh, latestChange, consumeLatestChange }}>
      {children}
    </SentChangesContext.Provider>
  );
}

export function useSentChanges(): SentChangesContextValue {
  const ctx = useContext(SentChangesContext);
  if (!ctx) throw new Error('useSentChanges must be used inside SentChangesProvider');
  return ctx;
}

import {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
  useRef,
  type ReactNode,
} from 'react';
import { getIncomingChallenges, type IncomingChallenge } from '../api/client.ts';
import { useAuth } from './AuthContext.tsx';

interface InboxContextValue {
  items: IncomingChallenge[];
  unseenCount: number;
  loading: boolean;
  markAllSeen: () => void;
  refresh: () => Promise<void>;
}

const InboxContext = createContext<InboxContextValue | null>(null);

const POLL_INTERVAL_MS = 5000;

export function InboxProvider({ children }: { children: ReactNode }) {
  const { sessionToken } = useAuth();
  const [items, setItems] = useState<IncomingChallenge[]>([]);
  const [seenNonces, setSeenNonces] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(false);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const fetchIncoming = useCallback(async () => {
    if (!sessionToken) return;
    try {
      const res = await getIncomingChallenges();
      setItems(res.items);
    } catch {
      // network hiccup — keep polling
    } finally {
      setLoading(false);
    }
  }, [sessionToken]);

  useEffect(() => {
    if (!sessionToken) {
      setItems([]);
      return;
    }
    setLoading(true);
    void fetchIncoming();
    intervalRef.current = setInterval(() => { void fetchIncoming(); }, POLL_INTERVAL_MS);
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, [sessionToken, fetchIncoming]);

  const unseenCount = items.filter((i) => !seenNonces.has(i.nonce)).length;

  const markAllSeen = useCallback(() => {
    setSeenNonces(new Set(items.map((i) => i.nonce)));
  }, [items]);

  const refresh = useCallback(async () => {
    setLoading(true);
    await fetchIncoming();
  }, [fetchIncoming]);

  return (
    <InboxContext.Provider value={{ items, unseenCount, loading, markAllSeen, refresh }}>
      {children}
    </InboxContext.Provider>
  );
}

export function useInbox(): InboxContextValue {
  const ctx = useContext(InboxContext);
  if (!ctx) throw new Error('useInbox must be used inside InboxProvider');
  return ctx;
}

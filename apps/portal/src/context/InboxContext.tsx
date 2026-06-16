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
  isOffline: boolean;
  latestNew: IncomingChallenge | null;
  consumeLatestNew: () => void;
  markAllSeen: () => void;
  refresh: () => Promise<void>;
}

const InboxContext = createContext<InboxContextValue | null>(null);

const POLL_INTERVAL_MS = 5000;
const OFFLINE_THRESHOLD = 2;

export function InboxProvider({ children }: { children: ReactNode }) {
  const { sessionToken } = useAuth();
  const [items, setItems] = useState<IncomingChallenge[]>([]);
  const [seenNonces, setSeenNonces] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(false);
  const [isOffline, setIsOffline] = useState(false);
  const [latestNew, setLatestNew] = useState<IncomingChallenge | null>(null);

  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const consecutiveFailuresRef = useRef(0);
  // Track previous nonces to detect newly arrived items
  const prevNoncesRef = useRef<Set<string>>(new Set());

  const fetchIncoming = useCallback(async () => {
    if (!sessionToken) return;
    try {
      const res = await getIncomingChallenges();
      consecutiveFailuresRef.current = 0;
      setIsOffline(false);

      // Detect newly arrived items (nonces not seen before at all)
      const incoming = res.items;
      const newItem = incoming.find(
        (i) => !prevNoncesRef.current.has(i.nonce) && !seenNonces.has(i.nonce),
      );
      if (newItem) setLatestNew(newItem);

      // Update prev nonces to current full set
      prevNoncesRef.current = new Set(incoming.map((i) => i.nonce));
      setItems(incoming);
    } catch {
      consecutiveFailuresRef.current += 1;
      if (consecutiveFailuresRef.current >= OFFLINE_THRESHOLD) {
        setIsOffline(true);
      }
    } finally {
      setLoading(false);
    }
  }, [sessionToken, seenNonces]);

  useEffect(() => {
    if (!sessionToken) {
      setItems([]);
      setIsOffline(false);
      prevNoncesRef.current = new Set();
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

  const consumeLatestNew = useCallback(() => {
    setLatestNew(null);
  }, []);

  const refresh = useCallback(async () => {
    setLoading(true);
    await fetchIncoming();
  }, [fetchIncoming]);

  return (
    <InboxContext.Provider value={{ items, unseenCount, loading, isOffline, latestNew, consumeLatestNew, markAllSeen, refresh }}>
      {children}
    </InboxContext.Provider>
  );
}

export function useInbox(): InboxContextValue {
  const ctx = useContext(InboxContext);
  if (!ctx) throw new Error('useInbox must be used inside InboxProvider');
  return ctx;
}

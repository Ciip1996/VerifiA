import { getSessionToken, type AccountProfile } from '../context/AuthContext.tsx';

const BASE_URL = import.meta.env.VITE_API_URL ?? 'http://localhost:3001';
const API_KEY = import.meta.env.VITE_VERIFIER_API_KEY ?? '';

// ─── Types ────────────────────────────────────────────────────────────────

export interface ChallengeResponse {
  nonce: string;
  verifier_id: string;
  expires_in: number;
  qr_data: string;
  deep_link: string;
  expires_at: string;
}

export interface TokenStatusResponse {
  valid: boolean;
  status: 'ACTIVE' | 'USED' | 'EXPIRED' | 'REVOKED' | 'NOT_FOUND' | 'REJECTED';
  exp?: string;
  iat?: string;
  rejection_reason?: string | null;
}

export interface BadgeInfo {
  jti: string;
  verifier: string;
  issued_at: string;
  expires_at: string;
}

export interface UserIdentity {
  full_name: string;
  curp: string | null;
  date_of_birth: string | null;
  id_type: 'INE' | 'PASSPORT';
  profile_photo: string;
  id_front_photo: string;
  id_back_photo: string | null;
  facetec_match_level: number | null;
  liveness_snapshot: string | null;
  liveness_match_score: number | null;
}

export interface ValidateResponse {
  valid: boolean;
  consumed_at?: string;
  message: string;
  badge?: BadgeInfo;
  identity?: UserIdentity | null;
}

export interface LoginResponse {
  session_token: string;
  expires_in: number;
  account: AccountProfile;
}

export interface ChallengeHistoryToken {
  status: string;
  liveness_match_score: number | null;
  liveness_snapshot: string | null;
  validated_at: string;
}

export interface ChallengeHistorySubject {
  full_name: string;
  profile_photo: string;
  id_type: string;
}

export interface ChallengeHistoryItem {
  nonce: string;
  status: string;
  target_email: string | null;
  rejection_reason: string | null;
  created_at: string;
  expires_at: string;
  token: ChallengeHistoryToken | null;
  subject: ChallengeHistorySubject | null;
}

export interface ChallengeHistoryResponse {
  items: ChallengeHistoryItem[];
  page: number;
  limit: number;
}

// ─── HTTP helper ──────────────────────────────────────────────────────────

async function apiFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const sessionToken = getSessionToken();
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    'X-API-Key': API_KEY,
    ...(init?.headers as Record<string, string> ?? {}),
  };
  if (sessionToken) {
    headers['Authorization'] = `Bearer ${sessionToken}`;
  }

  const res = await fetch(`${BASE_URL}${path}`, { ...init, headers });

  if (!res.ok) {
    const body = await res.json().catch(() => ({ error: res.statusText }));
    throw new Error((body as { error: string }).error ?? `HTTP ${res.status}`);
  }

  return res.json() as Promise<T>;
}

// ─── Auth ─────────────────────────────────────────────────────────────────

export async function login(email: string, password: string): Promise<LoginResponse> {
  return apiFetch<LoginResponse>('/api/v1/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  });
}

export async function getMe(): Promise<AccountProfile> {
  return apiFetch<AccountProfile>('/api/v1/auth/me');
}

// ─── Challenges ───────────────────────────────────────────────────────────

export async function createChallenge(opts?: { targetEmail?: string }): Promise<ChallengeResponse> {
  const sessionToken = getSessionToken();
  const verifier_id = sessionToken ? (JSON.parse(localStorage.getItem('verifia_account') ?? '{}').email ?? API_KEY) : API_KEY;
  return apiFetch<ChallengeResponse>('/api/v1/challenges', {
    method: 'POST',
    body: JSON.stringify({
      verifier_id,
      ...(opts?.targetEmail ? { target_email: opts.targetEmail } : {}),
    }),
  });
}

export async function getChallengeHistory(page = 1): Promise<ChallengeHistoryResponse> {
  return apiFetch<ChallengeHistoryResponse>(`/api/v1/challenges/history?page=${page}&limit=20`);
}

// ─── Tokens ───────────────────────────────────────────────────────────────

export async function getTokenStatus(nonce: string): Promise<TokenStatusResponse> {
  return apiFetch<TokenStatusResponse>(`/api/v1/tokens/verify/${nonce}`);
}

export async function validateToken(nonce: string): Promise<ValidateResponse> {
  return apiFetch<ValidateResponse>(`/api/v1/tokens/validate/${nonce}`, {
    method: 'POST',
  });
}

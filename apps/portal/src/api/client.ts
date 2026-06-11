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

export interface IncomingChallengeRequester {
  full_name: string | null;
  email: string;
  profile_photo: string | null;
}

export interface IncomingChallenge {
  nonce: string;
  requester: IncomingChallengeRequester;
  expires_at: string;
  created_at: string;
}

export interface IncomingChallengesResponse {
  items: IncomingChallenge[];
}

export interface AccountSearchResult {
  id: string;
  email: string;
  full_name: string | null;
  profile_photo: string | null;
  id_type: string | null;
  date_of_birth: string | null;
  facetec_match_level: number | null;
  is_self: boolean;
}

export interface PublicProfile {
  id: string;
  email: string;
  full_name: string | null;
  date_of_birth: string | null;
  id_type: string | null;
  profile_photo: string | null;
  id_front_photo: string | null;
  facetec_match_level: number | null;
}

export interface AccountDetails {
  id: string;
  email: string;
  full_name: string | null;
  curp: string | null;
  date_of_birth: string | null;
  id_type: string | null;
  profile_photo: string | null;
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

export async function cancelChallenge(nonce: string): Promise<void> {
  await apiFetch<{ success: boolean }>(`/api/v1/challenges/${nonce}/cancel`, { method: 'PATCH' });
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

// ─── Incoming challenges ──────────────────────────────────────────────────

export async function getIncomingChallenges(): Promise<IncomingChallengesResponse> {
  return apiFetch<IncomingChallengesResponse>('/api/v1/challenges/incoming');
}

export async function rejectChallenge(nonce: string): Promise<void> {
  await apiFetch<{ success: boolean }>(`/api/v1/challenges/${nonce}/reject`, { method: 'PATCH' });
}

export async function sendInvite(nonce: string, email: string): Promise<void> {
  await apiFetch<void>('/api/v1/challenges/send-invite', {
    method: 'POST',
    body: JSON.stringify({ nonce, email }),
  });
}

// ─── Accounts ─────────────────────────────────────────────────────────────

export async function searchAccounts(q: string): Promise<{ results: AccountSearchResult[] }> {
  return apiFetch<{ results: AccountSearchResult[] }>(
    `/api/v1/accounts/search?q=${encodeURIComponent(q)}`,
  );
}

export async function getPublicProfile(id: string): Promise<PublicProfile> {
  return apiFetch<PublicProfile>(`/api/v1/accounts/${id}/public-profile`);
}

export async function getMeDetails(): Promise<AccountDetails> {
  return apiFetch<AccountDetails>('/api/v1/auth/me');
}

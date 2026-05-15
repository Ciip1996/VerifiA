const BASE_URL = import.meta.env.VITE_API_URL ?? 'http://localhost:3001';
const API_KEY = import.meta.env.VITE_VERIFIER_API_KEY ?? '';

export interface ChallengeResponse {
  nonce: string;
  expires_in: number;
  qr_data: string;
  deep_link: string;
  expires_at: string;
}

export interface TokenStatusResponse {
  valid: boolean;
  status: 'ACTIVE' | 'USED' | 'EXPIRED' | 'REVOKED' | 'NOT_FOUND';
  exp?: string;
  iat?: string;
}

export interface ValidateResponse {
  valid: boolean;
  consumed_at?: string;
  message: string;
}

async function apiFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE_URL}${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      'X-API-Key': API_KEY,
      ...(init?.headers ?? {}),
    },
  });

  if (!res.ok) {
    const body = await res.json().catch(() => ({ error: res.statusText }));
    throw new Error((body as { error: string }).error ?? `HTTP ${res.status}`);
  }

  return res.json() as Promise<T>;
}

/**
 * Create a new challenge (called by the portal to generate the QR code).
 */
export async function createChallenge(): Promise<ChallengeResponse> {
  return apiFetch<ChallengeResponse>('/api/v1/challenges', {
    method: 'POST',
    body: JSON.stringify({ verifier_id: API_KEY }),
  });
}

/**
 * Poll token status (non-destructive).
 */
export async function getTokenStatus(nonce: string): Promise<TokenStatusResponse> {
  return apiFetch<TokenStatusResponse>(`/api/v1/tokens/verify/${nonce}`);
}

/**
 * Validate and consume a token.
 */
export async function validateToken(nonce: string): Promise<ValidateResponse> {
  return apiFetch<ValidateResponse>(`/api/v1/tokens/validate/${nonce}`, {
    method: 'POST',
  });
}

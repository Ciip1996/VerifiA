// VerifiA — Shared TypeScript types
// Used by both backend (Node.js) and portal (React/Vite)

// ─── Challenge ────────────────────────────────────────────────────────────

export interface CreateChallengeRequest {
  verifier_id: string;
}

export interface ChallengeResponse {
  nonce: string;
  expires_in: number;
  qr_data: string;
  deep_link: string;
  expires_at: string;
}

// ─── App Attest ───────────────────────────────────────────────────────────

export interface RegisterAttestRequest {
  attestation_object: string; // base64url
  client_data_json: string;   // base64url
  challenge: string;          // 32-byte hex nonce
}

export interface RegisterAttestResponse {
  registered: boolean;
  device_id: string;
}

// ─── Token Issue ──────────────────────────────────────────────────────────

export interface PasskeyAssertionPayload {
  id: string;
  raw_id: string;
  authenticator_data: string; // base64url
  client_data_json: string;   // base64url
  signature: string;          // base64url
  user_handle?: string;
}

export interface IssueTokenRequest {
  nonce: string;
  app_attest_assertion: string; // base64url CBOR
  device_id: string;
  facetec_session_id: string;
  passkey_assertion: PasskeyAssertionPayload;
}

export interface BadgeDisplay {
  jti: string;
  verifier: string;
  issued_at: string;
  expires_at: string;
}

export interface IssueTokenResponse {
  token: string; // JWT ES256
  expires_in: number;
  expires_at: string;
  badge_display: BadgeDisplay;
}

// ─── Token Verify / Validate ──────────────────────────────────────────────

export type TokenStatus = 'ACTIVE' | 'USED' | 'EXPIRED' | 'REVOKED' | 'NOT_FOUND';

export interface TokenStatusResponse {
  valid: boolean;
  status: TokenStatus;
  exp?: string;
  iat?: string;
}

export interface ValidateTokenResponse {
  valid: boolean;
  consumed_at?: string;
  message: string;
}

// ─── Error response ───────────────────────────────────────────────────────

export interface ApiError {
  error: string;
  code?: string;
}

// ─── JWT Claims ───────────────────────────────────────────────────────────

export interface VerifiaBadgeClaims {
  iss: string;     // JWT issuer (backend URL)
  sub: string;     // subject (passkey user handle)
  aud: string;     // audience (verifier_id / API key)
  exp: number;     // expiration (unix seconds)
  iat: number;     // issued at (unix seconds)
  jti: string;     // JWT ID (UUID, unique per token)
  nonce: string;   // challenge nonce (links to Challenge record)
  device_id: string;
}

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
  liveness_match_score?: number | null; // 3D-vs-3D score from verification liveness session
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

export type TokenStatus = 'ACTIVE' | 'USED' | 'EXPIRED' | 'REVOKED' | 'NOT_FOUND' | 'REJECTED';

export interface TokenStatusResponse {
  valid: boolean;
  status: TokenStatus;
  exp?: string;
  iat?: string;
  rejection_reason?: string | null;
}

// ─── Identity ──────────────────────────────────────────────────────────────

export interface UserIdentity {
  full_name: string;
  curp: string | null;
  date_of_birth: string | null;
  id_type: 'INE' | 'PASSPORT';
  profile_photo: string;          // base64 JPEG — selfie at registration (FaceTec audit trail)
  id_front_photo: string;         // base64 JPEG — front face of Mexican ID
  id_back_photo: string | null;   // base64 JPEG — back of INE (null for passport)
  facetec_match_level: number | null;   // 0–100 FaceTec 2D-vs-3D face-vs-ID score (at registration)
  liveness_snapshot: string | null;     // base64 JPEG — selfie captured at verification time
  liveness_match_score: number | null;  // 0–100 FaceTec 3D-vs-3D score (live face vs. registration enrollment)
}

export interface ValidateTokenResponse {
  valid: boolean;
  consumed_at?: string;
  message: string;
  badge?: {
    jti: string;
    verifier: string;
    issued_at: string;
    expires_at: string;
  };
  identity?: UserIdentity | null;
}

// ─── Profile Registration ─────────────────────────────────────────────────

export interface RegisterProfileRequest {
  device_id: string;
  full_name: string;
  curp?: string;
  date_of_birth?: string;
  id_type: 'INE' | 'PASSPORT';
  profile_photo: string;        // base64 JPEG selfie
  id_front_photo: string;       // base64 JPEG
  id_back_photo?: string;       // base64 JPEG (INE only)
  facetec_match_level?: number;
  enrollment_ref_id?: string;   // FaceTec externalDatabaseRefID from /enrollment-3d at registration
}

export interface RegisterProfileResponse {
  registered: boolean;
  profile_id: string;
}

// ─── Account Auth ─────────────────────────────────────────────────────────

export interface SetPasswordRequest {
  device_id: string;
  email: string;
  password: string;
}

export interface SetPasswordResponse {
  registered: boolean;
  account_id: string;
  session_token: string;
  expires_in: number;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface AccountProfile {
  id: string;
  email: string;
  full_name: string | null;
  curp?: string | null;
  date_of_birth?: string | null;
  id_type: string | null;
  profile_photo: string | null;
}

export interface LoginResponse {
  session_token: string;
  expires_in: number;
  account: AccountProfile;
}

// ─── Challenge History ────────────────────────────────────────────────────

export interface ChallengeHistoryItem {
  nonce: string;
  status: string;                // PENDING | USED | EXPIRED | REJECTED
  target_email: string | null;
  rejection_reason: string | null;
  created_at: string;
  expires_at: string;
  token: {
    status: string;
    liveness_match_score: number | null;
    liveness_snapshot: string | null;
    validated_at: string;
  } | null;
  subject: {
    full_name: string;
    profile_photo: string;
    id_type: string;
  } | null;
}

export interface ChallengeHistoryResponse {
  items: ChallengeHistoryItem[];
  page: number;
  limit: number;
}

export interface IncomingChallenge {
  nonce: string;
  verifier_id: string;
  created_at: string;
  expires_at: string;
  requester: {
    email: string;
    full_name: string | null;
    profile_photo: string | null;
  } | null;
}

export interface IncomingChallengesResponse {
  items: IncomingChallenge[];
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

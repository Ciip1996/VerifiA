# VerifiA — Complete Codebase Reference

> This document is the authoritative reference for any AI agent, developer, or reviewer
> to quickly understand the entire VerifiA system: what it does, how it works, where every
> piece lives, and how all parts connect.

---

## What Is VerifiA?

VerifiA is a **real-time cryptographic identity verification system** built as a cybersecurity thesis at ITESM. It lets one person (the **verifier**) request that another person (the **subject**) prove their identity on-demand, with a tamper-proof result.

**Non-technical summary:** Imagine a bouncer at a club who needs to verify your ID in real time. With VerifiA, the bouncer opens a web portal, generates a QR code, and the person scans it with their phone. The phone runs a liveness check (face scan), verifies the phone is genuine, and signs a cryptographic badge. The bouncer's portal instantly shows a green confirmation with the person's face, name, and ID. The badge is single-use and expires in 5 minutes.

**Technical summary:** The portal creates a nonce-backed challenge. The mobile app scans the deep link, runs three verification layers (Apple App Attest device integrity, FaceTec liveness + ID photo match, FIDO2 Passkey signing), and submits proofs to the backend. The backend validates all proofs and issues an ES256 JWT badge. The portal polls for and consumes the badge, displaying the verified identity.

---

## Monorepo Layout

```
VerifiA/
├── apps/
│   ├── backend/          Node 20 + Express + Prisma + PostgreSQL
│   ├── portal/           React 18 + Vite + TypeScript (verifier web UI)
│   └── mobile/           Flutter 3.x + Dart + Swift native channels (holder iOS app)
├── packages/
│   └── shared/           Shared TypeScript types (used by backend + portal)
├── docs/
│   └── api-spec.yaml     OpenAPI 3.0 spec
├── .github/
│   └── workflows/ci.yml  GitHub Actions CI/CD
├── CLAUDE.md             AI agent workspace rules
└── CODEBASE.md           ← this file
```

Root `package.json` defines npm workspaces across all three apps and shared package.

**Key root scripts:**
| Script | What it does |
|---|---|
| `npm install` | Install all workspace dependencies |
| `npm run dev:backend` | Start backend API on port 3001 |
| `npm run dev:portal` | Start portal Vite dev server on port 5173 |
| `npm run typecheck` | TypeScript check shared + backend + portal |
| `npm run lint` | ESLint backend + portal |
| `npm run test:backend` | Run Vitest backend tests (needs Postgres) |

---

## The Verification Flow (End to End)

```
┌─────────────┐          ┌─────────────┐          ┌──────────────┐
│   Portal    │          │   Backend   │          │  Mobile App  │
│ (Verifier)  │          │  (API)      │          │  (Subject)   │
└──────┬──────┘          └──────┬──────┘          └──────┬───────┘
       │  POST /challenges       │                        │
       │ ──────────────────────► │                        │
       │  {nonce, qr_data, ttl}  │                        │
       │ ◄────────────────────── │                        │
       │                         │                        │
       │  [Displays QR code]     │                        │
       │                         │   Scans QR / deep link │
       │                         │ ◄───────────────────── │
       │                         │                        │
       │                         │  [Layer 1] App Attest  │
       │                         │  POST /app-attest/reg  │
       │                         │ ◄───────────────────── │
       │                         │                        │
       │                         │  [Layer 2] FaceTec     │
       │                         │  liveness + ID match   │
       │                         │  (validated on device) │
       │                         │                        │
       │                         │  [Layer 3] Passkey     │
       │                         │  FIDO2 assertion       │
       │                         │                        │
       │                         │  POST /tokens/issue    │
       │                         │  {nonce, attest, face, │
       │                         │   passkey, score}      │
       │                         │ ◄───────────────────── │
       │                         │  {token: JWT ES256}    │
       │                         │ ────────────────────── │
       │                         │                        │
       │  POST /tokens/validate  │                        │
       │ ──────────────────────► │                        │
       │  {valid, identity}      │                        │
       │ ◄────────────────────── │                        │
       │                         │                        │
       │  [Shows result: name,   │                        │
       │   face, ID, score]      │                        │
```

---

## packages/shared

**Path:** `packages/shared/src/index.ts`

Shared TypeScript types used by both the backend and the portal. Never contains logic — only type definitions.

| Type/Interface | Purpose |
|---|---|
| `CreateChallengeRequest` | `{ verifier_id }` — portal → backend to create QR |
| `ChallengeResponse` | `{ nonce, qr_data, deep_link, expires_in, expires_at }` |
| `RegisterAttestRequest` | App Attest attestation payload (base64url CBOR + challenge) |
| `RegisterAttestResponse` | `{ registered, device_id }` |
| `IssueTokenRequest` | All three proof payloads + nonce |
| `IssueTokenResponse` | `{ token: JWT, expires_in, badge_display }` |
| `ValidateTokenResponse` | `{ valid, identity: UserIdentity, badge, message }` |
| `UserIdentity` | Full extracted identity: name, CURP, DOB, id type, photos, face scores |
| `TokenStatus` | `'ACTIVE' | 'USED' | 'EXPIRED' | 'REVOKED' | 'NOT_FOUND' | 'REJECTED'` |
| `AccountProfile` | Logged-in account info (email, full_name, id_type, profile_photo) |
| `LoginRequest` / `LoginResponse` | Auth credentials and session token |
| `SetPasswordRequest` / `SetPasswordResponse` | Link mobile device to account |
| `ChallengeHistoryItem` | Sent challenge row with subject info and token outcome |
| `ChallengeHistoryResponse` | Paginated history |
| `VerifiaBadgeClaims` | JWT payload shape: iss, sub, aud, exp, iat, jti, nonce, device_id |
| `PasskeyAssertionPayload` | FIDO2 assertion fields (base64url encoded) |

---

## apps/backend

**Stack:** Node.js 20, Express, Prisma 5, PostgreSQL (Neon in production), TypeScript, Vitest.
**Dev command:** `npm run dev` (uses `tsx --watch`)
**Production:** Deployed as Vercel serverless functions via `apps/backend/vercel.json`.

### Environment Variables

| Variable | Description |
|---|---|
| `DATABASE_URL` | Pooled PostgreSQL URL (pgBouncer — runtime use) |
| `DIRECT_URL` | Direct PostgreSQL URL (Prisma migrations only) |
| `JWT_PRIVATE_KEY_PEM` | ES256 ECDSA P-256 private key (PEM, `\n` literals) |
| `JWT_PUBLIC_KEY_PEM` | ES256 public key (PEM) |
| `TOKEN_TTL_SECONDS` | Badge token lifetime (default: 300 = 5 min) |
| `CHALLENGE_TTL_SECONDS` | QR challenge lifetime (default: 600 = 10 min) |
| `APPLE_TEAM_ID` | Apple Developer Team ID (for App Attest RP ID) |
| `APPLE_BUNDLE_ID` | iOS bundle ID `com.verifia.verifiaMobile` |
| `VERIFIA_SKIP_ATTEST` | `true` in dev/CI — skips App Attest cryptographic verification |
| `FACETEC_BASE_URL` | FaceTec Managed Testing API base URL |
| `FACETEC_DEVICE_KEY_IDENTIFIER` | FaceTec device key |
| `FACETEC_PUBLIC_FHD_KEY` | FaceTec FHD key |
| `FACETEC_SERVER_SESSION_TOKEN_ENCRYPTION_SECRET` | FaceTec session secret |
| `RESEND_API_KEY` | Resend email API key (challenge email invitations) |
| `PORT` | HTTP port (default: 3001) |
| `NODE_ENV` | `development` | `production` | `test` |
| `CORS_ORIGIN` | Allowed CORS origin (portal URL) |
| `API_BASE_URL` | Public-facing backend URL (used in shared links) |
| `JWT_ISSUER` | JWT `iss` claim value |

### Database Models (Prisma)

**File:** `apps/backend/prisma/schema.prisma`

| Model | Table | Purpose |
|---|---|---|
| `Account` | `accounts` | Web account (email + password hash). Created from mobile after onboarding. Links to `UserProfile` via `device_id`. |
| `Challenge` | `challenges` | QR verification request. Status: `PENDING → IN_PROGRESS → USED / EXPIRED / REJECTED / CANCELLED`. Holds `target_email` for directed challenges, `account_id` for authenticated creators. |
| `Token` | `tokens` | Issued ES256 JWT badge. Status: `ACTIVE → USED / EXPIRED / REVOKED`. Stores raw JWT, liveness snapshot (base64 JPEG), and liveness match score. Single-use via `jti`. |
| `UserProfile` | `user_profiles` | Registered identity from onboarding. Stores full name, CURP, DOB, ID type, selfie photo, ID front/back photos, FaceTec match scores, FaceTec enrollment ref. |
| `AppAttestKey` | `app_attest_keys` | One entry per device. Stores Apple ECDSA public key for per-request assertion verification. |
| `PasskeyCredential` | `passkey_credentials` | FIDO2 credential. Stores COSE-encoded public key bytes and sign count (cloning detection). |
| `PasskeyRegistrationChallenge` | `passkey_registration_challenges` | Short-lived nonce for FIDO2 registration ceremony. |
| `AuditLog` | `audit_logs` | Immutable security event log. Actions: `APP_ATTEST_REGISTER`, `TOKEN_ISSUED`, `TOKEN_VALIDATED`, `TOKEN_REJECTED`, etc. |

### API Routes

**Entry point:** `apps/backend/src/index.ts` — mounts all routers under `/api/v1/`.

#### Auth (`apps/backend/src/routes/auth.ts`)

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/api/v1/auth/set-password` | None | Links a mobile device to an email+password account after onboarding. Requires `device_id` that already has a `UserProfile`. Issues a 7-day session JWT. |
| `POST` | `/api/v1/auth/login` | None | Email + password login. Returns session JWT + `AccountProfile`. |
| `GET` | `/api/v1/auth/me` | Session JWT | Returns the authenticated account's profile and linked `UserProfile`. |

#### Challenges (`apps/backend/src/routes/challenges.ts`)

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/api/v1/challenges` | Session JWT | Create a QR challenge. Optionally set `target_email` to direct at a specific user. Returns `nonce`, `qr_data` (deep link string for QR), `expires_in`. |
| `GET` | `/api/v1/challenges/incoming` | Session JWT | Challenges targeted at the caller's email with status `PENDING` or `IN_PROGRESS`. Used by mobile Recibidas tab. |
| `GET` | `/api/v1/challenges/history` | Session JWT | All challenges created by the caller, with subject info and token outcome. Used by mobile/portal Enviadas tab. |
| `POST` | `/api/v1/challenges/send-invite` | Session JWT | Send a Resend email invitation to an unregistered email with a deep link. |
| `PATCH` | `/api/v1/challenges/:nonce/start` | None | Transitions challenge `PENDING → IN_PROGRESS`. Called when recipient opens the verification flow. Idempotent. |
| `PATCH` | `/api/v1/challenges/:nonce/reject` | Session JWT | Recipient rejects an incoming challenge (`PENDING → REJECTED`). |
| `PATCH` | `/api/v1/challenges/:nonce/cancel` | Session JWT | Sender cancels a challenge (`PENDING` or `IN_PROGRESS → CANCELLED`). |

#### App Attest (`apps/backend/src/routes/app-attest.ts`)

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/api/v1/app-attest/challenge` | None | Returns a 32-byte hex nonce for the attestation ceremony. |
| `POST` | `/api/v1/app-attest/register` | None | Verifies Apple App Attest attestation object, extracts device public key, and stores in `AppAttestKey`. `VERIFIA_SKIP_ATTEST=true` bypasses crypto. |

#### Tokens (`apps/backend/src/routes/tokens.ts`)

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/api/v1/tokens/issue` | None | Core issuance endpoint. Validates: (1) challenge nonce not used/expired, (2) App Attest assertion cryptographically matches registered device key, (3) FaceTec liveness session valid, (4) FIDO2 Passkey assertion valid. Issues ES256 JWT badge. |
| `POST` | `/api/v1/tokens/validate` | API Key Header | Portal consumes the token. Verifies JWT signature, marks as `USED`, returns full `UserIdentity`. Single-use. |

#### Profiles (`apps/backend/src/routes/profiles.ts`)

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/api/v1/profiles/register` | None | Saves FaceTec onboarding result: name, CURP, DOB, ID type, selfie, ID photos, match score. Called from mobile after onboarding. |
| `GET` | `/api/v1/profiles/:deviceId` | Session JWT | Fetches a `UserProfile` by device ID. |
| `GET` | `/api/v1/profiles/search` | Session JWT | Search users by name/email for directed challenges. |

#### Passkeys (`apps/backend/src/routes/passkeys.ts`)

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/api/v1/passkeys/register/challenge` | None | Returns a FIDO2 registration challenge (random nonce). |
| `POST` | `/api/v1/passkeys/register` | None | Completes FIDO2 registration: verifies attestation, stores `PasskeyCredential`. |

#### Accounts (`apps/backend/src/routes/accounts.ts`)

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/api/v1/accounts/:id/profile` | Session JWT | Public profile view by account ID (for verifier portal user search). |

#### Health

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/health` | None | Returns `{ status: "ok" }`. |

### Services

**`apps/backend/src/services/`**

| File | Purpose |
|---|---|
| `db.ts` | Exports singleton Prisma client. |
| `app-attest.ts` | `verifyAppAttest()` — full CBOR decode, X.509 chain verify, RP ID hash check, aaguid check, nonce OID extension verify. `verifyAppAttestAssertion()` — ECDSA P-256 signature verification of per-request assertions. Both have dev-mode short circuits. |
| `facetec.ts` | `verifyFaceTecSession()` — validates liveness session against FaceTec Managed Testing API. Stub-friendly: if FaceTec returns a non-critical error in dev, it logs and continues. |
| `passkeys.ts` | `verifyPasskeyAssertion()` — FIDO2 assertion verification (client data hash, signature over `authData || clientDataHash`, sign count replay protection). |

### Middleware

**`apps/backend/src/middleware/`**

| File | Purpose |
|---|---|
| `error-handler.ts` | Catches all errors. `AppError(status, message, code)` → structured JSON `{ error, code }`. Unhandled errors become 500s. |
| `require-account.ts` | Validates `Authorization: Bearer <session_token>` (7-day account JWT). Attaches `req.account` with `{ id, email, device_id }`. |
| `require-api-key.ts` | Validates `X-API-Key` header against `VITE_VERIFIER_API_KEY`. Used for token validation endpoint. |

### Utils

**`apps/backend/src/utils/`**

| File | Purpose |
|---|---|
| `jwt.ts` | `signBadgeToken()` — signs ES256 badge JWT with all `VerifiaBadgeClaims`. `verifyBadgeToken()` — verifies and decodes. `loadPem()` — normalizes literal `\n` in env var PEM strings to real newlines. Two JWT types: badge (5-min TTL, `iss=https://api.verifia.dev`) and account session (7-day, `iss=verifia-account`). |

---

## apps/portal

**Stack:** React 18, Vite, TypeScript. No external UI library — all styled with inline CSS-in-JS using a dark theme with CSS variables.
**Dev command:** `npm run dev` (Vite on port 5173)
**Production:** Vercel static hosting.

### Environment Variables

| Variable | Description |
|---|---|
| `VITE_API_URL` | Backend URL (`http://localhost:3001` dev / Vercel URL prod) |
| `VITE_VERIFIER_API_KEY` | API key for token validation (`X-API-Key` header) |

### Routing (`apps/portal/src/App.tsx`)

All routes under `/` are protected by `AuthGuard` (redirects to `/login` if no session token).

| Route | Component | Description |
|---|---|---|
| `/login` | `LoginPage` | Email + password login (public) |
| `/` | `VerifierPage` | QR challenge generation (default page) |
| `/solicitudes` | `SolicitudesPage` | Sent and received verification requests |
| `/buscar` | `SearchPage` | Search for users by name/email |
| `/buscar/:accountId` | `PublicProfilePage` | Public profile view of another user |
| `/perfil` | `ProfilePage` | Current user's own profile |

### Pages

**`apps/portal/src/pages/`**

| File | What it does |
|---|---|
| `LoginPage.tsx` | Email + password form. Calls `login()` API, stores session token in `AuthContext`. Spanish error code mapping. Password show/hide toggle. |
| `VerifierPage.tsx` | Core verifier flow. Form to optionally target a user by email. Generates QR (using `QRGenerator`). Countdown ring showing TTL. Share button (navigator.share API + formatted message). Download QR as PNG (hidden canvas). Polls `GET /tokens/validate` every 2s after QR shown. Shows `BadgeValidator` on success. |
| `SolicitudesPage.tsx` | Two tabs: Recibidas (incoming challenges to this user) and Enviadas (sent challenges). Incoming tab: shows pending challenges, can verify (links to mobile QR deep link) or cancel. Enviadas tab: history list with status chips. Detail drawer (`VerificationDetailDrawer`) shows subject photos, ID type, liveness score with animated gauge. Photos are clickable (opens `PhotoLightbox`). Cancel button for PENDING/IN_PROGRESS challenges. Manual refresh button. `ConfirmDialog` replaces native `window.confirm`. |
| `SearchPage.tsx` | Search users by name or email. Results show avatars. Clicking a result navigates to `PublicProfilePage`. |
| `PublicProfilePage.tsx` | Shows another user's public profile (name, photo, ID type). Has "Solicitar verificación" button that creates a directed challenge and redirects to the QR flow. |
| `ProfilePage.tsx` | Current user's profile: name, email, CURP, DOB, ID type, profile photo. "Reintentar" button on load failure. |

### Components

**`apps/portal/src/components/`**

| File | Purpose |
|---|---|
| `Layout.tsx` | Root layout. Sidebar navigation on desktop, top bar + bottom nav on mobile. Displays three animated banner types: offline strip (red), new incoming challenge (dismisses after 6s), sent challenge status change (dismisses after 6s). Reads `InboxContext` and `SentChangesContext`. |
| `QRGenerator.tsx` | Renders QR code SVG from a data string using `qrcode` library. |
| `BadgeValidator.tsx` | Success state after token validated. Shows verified identity card with face photo, liveness snapshot, name, scores. |
| `IdentityCard.tsx` | Displays a `UserIdentity` object: full name, ID type chip, CURP, DOB, photos, match score gauge. |
| `PhotoLightbox.tsx` | Full-screen image overlay with mouse-wheel zoom and Escape-key close. |

### Contexts

**`apps/portal/src/context/`**

| File | State held | Update mechanism |
|---|---|---|
| `AuthContext.tsx` | `sessionToken`, `account: AccountProfile`, `loading` | `login()` / `logout()` functions. Token persisted in `localStorage`. |
| `InboxContext.tsx` | `items: IncomingChallenge[]`, `unseenCount`, `isOffline`, `latestNew` | Polls `GET /challenges/incoming` every 10s. `latestNew` fires when a new challenge appears (triggers banner). `markAllSeen()` clears unseen count. |
| `SentChangesContext.tsx` | `latestChange: ChallengeHistoryItem | null` | Polls `GET /challenges/history` every 8s. Fires `latestChange` on status transitions (PENDING → REJECTED / CANCELLED / USED). `consumeLatestChange()` clears after reading. |

### API Client

**`apps/portal/src/api/client.ts`** — typed `fetch` wrapper with session token injection.

Key methods: `login`, `getProfile`, `createChallenge`, `validateToken`, `getIncomingChallenges`, `getChallengeHistory`, `cancelChallenge`, `searchUsers`, `getPublicProfile`.

---

## apps/mobile

**Stack:** Flutter 3.x, Dart. iOS only (iPhone). Native Swift MethodChannels for security-sensitive hardware operations.
**Run on device:** `flutter run -d <device-id> --dart-define=VERIFIA_API_URL=<url> --dart-define=VERIFIA_SKIP_ATTEST=true`

### Entry Point (`apps/mobile/lib/main.dart`)

1. Initializes App Attest key registration (`_initAppAttest()`) — calls `AppAttestService.registerIfNeeded()` on physical device.
2. Initializes deep link handler (`_initDeepLinks()`) — listens for `verifia://badge?nonce=…&verifier=…` URIs.
3. Runs `VerifiAApp` — MaterialApp with dark theme.
4. `HomeScreen` is shown when session token exists; `OnboardingScreen` when not yet registered.

### Screens

**`apps/mobile/lib/screens/`**

| File | Purpose |
|---|---|
| `home_screen.dart` | Main scaffold with 4 bottom-nav tabs: QR Scanner, Crear QR, Solicitudes, Buscar. Starts `InboxService` and `SentChallengesService` polling. Shows animated in-app banners: new incoming challenge (blue), rejected/cancelled sent challenge (red), verified sent challenge (green → taps to `VerificationDetailScreen`). Shows red offline strip when either service can't reach the backend. |
| `qr_scanner_screen.dart` | Camera QR scanner using `mobile_scanner`. Parses `verifia://badge?nonce=…&verifier=…` deep link. On scan, pushes `PresenceChallengeScreen`. Camera is released when tab is inactive. |
| `create_challenge_screen.dart` | Form to create a QR challenge (open or targeted at email). Displays generated QR with live countdown ring. Share sheet (PNG export via `qr_flutter`) and copy-link button. Email invite button for unregistered targets. QR fades to 25% opacity on expiry. |
| `incoming_validations_screen.dart` | Two-tab screen: Recibidas (`_ReceivedTab`) and Enviadas (`_SentTab`). Recibidas: shows `PENDING` and `IN_PROGRESS` challenges with "Verificar" / "Retomar" buttons and a live countdown progress bar. Enviadas: shows sent challenge history with status chips and cancel button for PENDING/IN_PROGRESS. Completed (USED) cards tap to `VerificationDetailScreen`. |
| `presence_challenge_screen.dart` | The verification execution flow for the recipient. Steps: 1) Show challenge details, 2) call `/start`, 3) launch `LivenessScreen`, 4) assemble all proofs, 5) call `POST /tokens/issue`, 6) show `BadgeScreen`. |
| `badge_screen.dart` | Success screen shown after token issuance. Displays QR of the JWT, countdown timer, and badge display (verifier name, expiry). |
| `liveness_screen.dart` | Real FaceTec liveness check — uses `FaceTecChannel` (Swift) to run the SDK session. Returns `session_id` and `match_score`. |
| `liveness_mock_screen.dart` | Dev/simulator fallback liveness screen. Uses device camera + MLKit face detection for a simple head-turn challenge. Returns mock session data. |
| `onboarding_screen.dart` | New user registration flow: FaceTec Photo ID Match (scan face + ID card), extract OCR data, store `UserProfile` on backend, then prompt to set email/password. |
| `set_password_screen.dart` | Collect email + password to link mobile device to a web account. Calls `POST /auth/set-password`. |
| `account_profile_screen.dart` | Current user's profile: name, photos, CURP, DOB, ID type. |
| `user_search_screen.dart` | Search registered users by name/email. Results tap to `PublicUserProfileScreen`. |
| `public_user_profile_screen.dart` | Another user's public profile with "Solicitar verificación" button. |
| `verification_detail_screen.dart` | Detail view of a completed sent challenge: subject photos (selfie, ID front/back), name, ID type, liveness score gauge, validated timestamp. |

### Services

**`apps/mobile/lib/services/`**

| File | Purpose |
|---|---|
| `api_service.dart` | All HTTP calls via Dio. Reads `VERIFIA_API_URL` dart-define (default: `https://verifia-backend.vercel.app`). Stores/reads session token from `FlutterSecureStorage`. Key models: `IncomingChallenge` (with `status` field), `SentChallenge`. |
| `app_attest_service.dart` | Manages Apple App Attest lifecycle. `registerIfNeeded()` — generates Secure Enclave key, attests with Apple, registers with backend. `generateAssertion()` — per-request ECDSA assertion. Uses `VERIFIA_SKIP_ATTEST` dart-define; if `true`, returns hardcoded `SKIP_ATTEST_ASSERTION` / `SKIP_ATTEST_DEVICE` stubs. Keys persisted in `FlutterSecureStorage`. Auto re-registers on Secure Enclave key invalidation. |
| `facetec_service.dart` | Wrapper around `FaceTecChannel` (Swift). `runLiveness()` — calls Swift channel, returns `{ sessionId, matchScore }`. Falls back to mock screen in simulator. |
| `inbox_service.dart` | Singleton `ChangeNotifier`. Polls `GET /challenges/incoming` every 10s. Exposes `items`, `unseenCount`, `isOffline`, `latestNew`. `markAllSeen()`. |
| `sent_challenges_service.dart` | Singleton `ChangeNotifier`. Polls `GET /challenges/history` every 8s. Detects status transitions: `→ USED` (verified), `PENDING → REJECTED`, `PENDING → CANCELLED`. Exposes `latestChange` via `consumeLatestChange()`. `updateStatus()` for optimistic local updates. |
| `passkey_service.dart` | FIDO2 Passkey wrapper. `registerIfNeeded()` — registers credential, stores `credentialId` in secure storage. `authenticate()` — generates assertion for a challenge nonce. Uses `PasskeyChannel` (Swift). Currently stubbed for devices without Passkey support. |
| `feedback_service.dart` | `HapticFeedback` + audio cues. `FeedbackService.incoming()` — medium impact haptic. `FeedbackService.sent()` — light haptic. |

### iOS Native Channels (Swift)

**`apps/mobile/ios/Runner/`**

All channels use `FlutterMethodChannel` with the scheme `com.verifia.app/<name>`.

| File | Channel | Methods |
|---|---|---|
| `AppAttestChannel.swift` | `com.verifia.app/app_attest` | `isSupported` → bool. `generateKey` → keyId String. `attestKey(key_id, challenge)` → attestation base64. `generateAssertion(key_id, challenge)` → assertion base64. Uses `DCAppAttestService` (iOS 14+). |
| `FaceTecChannel.swift` | `com.verifia.app/facetec` | `initialize(deviceKeyId, publicFhdKey)`. `startLiveness(sessionToken)` → `{ sessionId, faceScan, auditTrailImage, lowQualityAuditTrailImage }`. Wraps FaceTec iOS SDK. |
| `LivenessChannel.swift` | `com.verifia.app/liveness` | `startSession(nonce)` → `{ session_id, face_scan, audit_trail_image, match_score }`. Uses device camera + MLKit face detection for head-turn liveness. Used as FaceTec fallback / mock. |
| `PasskeyChannel.swift` | `com.verifia.app/passkey` | `register(challenge, userId)` → `{ credentialId, attestationObject, clientDataJSON }`. `authenticate(challenge, credentialId)` → `{ id, rawId, authenticatorData, clientDataJSON, signature }`. Uses `ASAuthorizationController` (FIDO2). |
| `BiometricsChannel.swift` | `com.verifia.app/biometrics` | `authenticate(reason)` → bool. Uses `LAContext` for Face ID / Touch ID confirmation steps. |
| `AppDelegate.swift` | — | Registers all 5 MethodChannels on `FlutterViewController`. |
| `SceneDelegate.swift` | — | Scene lifecycle management. No `UIMainStoryboardFile` (would cause blank Flutter UI). |

---

## CI/CD

**File:** `.github/workflows/ci.yml`

### Triggers

- Push to `main` or `develop`
- Pull request targeting `main`

### Jobs

| Job | Runs on | Trigger | What it does |
|---|---|---|---|
| `backend` | ubuntu-latest | Every push/PR | Spins up Postgres 16 service, runs `npm ci`, `prisma generate`, `prisma migrate deploy`, `tsc --noEmit`, `vitest` (with `VERIFIA_SKIP_ATTEST=true`). |
| `portal` | ubuntu-latest | Every push/PR | `npm ci`, `tsc --noEmit`, `vite build`. |
| `shared` | ubuntu-latest | Every push/PR | `npm ci`, `tsc --noEmit`. |
| `flutter` | macos-latest | Every push/PR | `flutter pub get`, `flutter analyze --no-fatal-infos`, `flutter test`. |
| `deploy-backend` | ubuntu-latest | Push to `main` only | Needs `backend` job. Runs `prisma migrate deploy` against production DB, then `vercel deploy --prod` from repo root. |
| `deploy-portal` | ubuntu-latest | Push to `main` only | Needs `portal` job. Runs `vercel deploy --prod` from repo root. |
| `testflight` | macos-latest | Push to `main` only | Needs `flutter` job. Installs cert + provisioning profile from secrets, runs `fastlane beta` to build IPA and upload to TestFlight. |

### Required GitHub Secrets

| Secret | Used by |
|---|---|
| `JWT_PRIVATE_KEY_PEM` / `JWT_PUBLIC_KEY_PEM` | Backend tests |
| `DIRECT_URL_PROD` | Production Prisma migration |
| `VERCEL_TOKEN` | Both Vercel deploys |
| `VERCEL_ORG_ID` | Both Vercel deploys |
| `VERCEL_PROJECT_ID_BACKEND` | Backend deploy |
| `VERCEL_PROJECT_ID_PORTAL` | Portal deploy |
| `CERTIFICATE_BASE64` | TestFlight — Apple distribution cert (P12, base64) |
| `CERTIFICATE_PASSWORD` | TestFlight — P12 password |
| `PROVISIONING_PROFILE_BASE64` | TestFlight — App Store provisioning profile |
| `PROVISIONING_PROFILE_NAME` | TestFlight — profile name string |
| `ASC_KEY_ID` | TestFlight — App Store Connect API key ID |
| `ASC_ISSUER_ID` | TestFlight — App Store Connect issuer |
| `ASC_KEY_CONTENT` | TestFlight — App Store Connect API private key |
| `VERIFIA_API_URL_PROD` | TestFlight — production backend URL baked into IPA |

---

## Security Architecture

### Three Verification Layers

All three must pass for a badge token to be issued. Each has a dev bypass via `VERIFIA_SKIP_ATTEST=true`.

```
Layer 1: Apple App Attest
  - Proves the request comes from a genuine, unmodified copy of VerifiA
    on a real Apple device.
  - Not fakeable from scripts or emulators.
  - Dev bypass: mobile sends "SKIP_ATTEST_ASSERTION"; backend accepts without lookup.

Layer 2: FaceTec Liveness + Photo ID Match
  - Liveness: proves a live human face is present (anti-spoofing, anti-injection).
  - Registration match: selfie vs. ID card photo (2D-vs-3D FaceTec score).
  - Verification match: live face vs. enrolled 3D model (3D-vs-3D FaceTec score).
  - Score stored as 0–100 integer (always a multiple of 10; FaceTec returns 0–10 matchLevel).

Layer 3: FIDO2 Passkey
  - Binds the token to the user's device Secure Enclave key.
  - Sign count prevents credential cloning/replay.
  - Currently stubbed; full implementation uses ASAuthorizationController.
```

### JWT Types

Two ES256 JWTs in use, same key pair, different issuers:

| Type | Issuer | TTL | Purpose |
|---|---|---|---|
| Badge token | `https://api.verifia.dev` | 5 min | Ephemeral proof of verification. Single-use. |
| Account session | `verifia-account` | 7 days | Portal/mobile authentication. |

### App Attest Environments

Apple issues different AAGUIDs per distribution:
- **Simulator / Debug / TestFlight:** `appattestdevelop`
- **App Store:** `appattest\x00\x00\x00\x00\x00\x00\x00`

The backend (`app-attest.ts`) accepts both when `NODE_ENV !== 'production'`, only the production AAGUID when in production. This means App Attest with real verification requires an App Store build (not TestFlight) unless `NODE_ENV` is overridden.

---

## Key Conventions

- **TypeScript:** strict mode. All request/response shapes in `packages/shared`. Backend uses Zod for request validation.
- **Backend errors:** Always `AppError(httpStatus, humanMessage, ERROR_CODE)` → JSON `{ error, code }`.
- **Flutter state:** `InboxService` and `SentChallengesService` are singletons extending `ChangeNotifier`. Polling is started once in `HomeScreen.initState()` and runs for the app lifetime.
- **Photos:** All stored and transmitted as base64 JPEG strings. No file storage — all in PostgreSQL `TEXT` columns.
- **Deep links:** `verifia://badge?nonce=<64-hex>&verifier=<verifierId>`. Handled by `app_links` package + `AppDelegate` custom URL scheme registration.
- **No drive-by refactors.** Changes should be focused. See `CLAUDE.md` for full AI agent rules.

---

## Local Development Quick Start

```bash
# 1. Install all workspace dependencies
npm install

# 2. Backend
cp apps/backend/.env.example apps/backend/.env
# Edit .env: fill DATABASE_URL, JWT keys, VERIFIA_SKIP_ATTEST=true
cd apps/backend && npx prisma migrate dev && cd ../..
npm run dev:backend                    # → http://localhost:3001

# 3. Portal
cp apps/portal/.env.example apps/portal/.env
# Edit .env: VITE_API_URL=http://localhost:3001
npm run dev:portal                     # → http://localhost:5173

# 4. Mobile (simulator)
cd apps/mobile && flutter pub get
cd ios && pod install && cd ..
flutter run -d <simulator-id> \
  --dart-define=VERIFIA_API_URL=http://127.0.0.1:3001 \
  --dart-define=VERIFIA_SKIP_ATTEST=true

# 4b. Mobile (physical iPhone — use Mac LAN IP)
flutter run -d <device-id> \
  --dart-define=VERIFIA_API_URL=http://<mac-lan-ip>:3001 \
  --dart-define=VERIFIA_SKIP_ATTEST=true
```

> **Note on macOS firewall:** If the iPhone can't reach the backend, add a firewall exception for `tsx` in System Settings → Network → Firewall, or temporarily disable the firewall during local development.

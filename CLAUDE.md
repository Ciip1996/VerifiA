# VerifiA

Ephemeral cryptographic presence token for real-time identity verification (ITESM cybersecurity thesis).

**Flow:** Portal creates QR challenge → Mobile app scans `verifia://badge?nonce=…` → FaceTec liveness + App Attest + Passkey → Backend issues ES256 JWT (TTL ~5 min) → Portal validates and shows result.

## Monorepo layout

| Path | Stack | Role |
|------|-------|------|
| `apps/backend` | Node 20, Express, Prisma, PostgreSQL | REST API: challenges, tokens, app-attest |
| `apps/portal` | React 18, Vite, TypeScript | Verifier web UI (QR + polling) |
| `apps/mobile` | Flutter 3.x, Dart, Swift channels | Holder iOS app (QR scanner) |
| `packages/shared` | TypeScript | Shared API types (backend + portal) |
| `docs/api-spec.yaml` | OpenAPI | API reference |

## Commands (from repo root)

```bash
npm install                    # install all workspaces
npm run dev:backend            # API on :3001
npm run dev:portal             # portal on :5173
npm run typecheck              # shared + backend + portal
npm run lint                   # backend + portal
npm run test:backend           # vitest (needs Postgres)
```

### Backend (`apps/backend`)

```bash
cp .env.example .env           # JWT keys, DATABASE_URL, FaceTec, etc.
npx prisma migrate dev
npm run dev                    # or: npm run dev from root
npm test
```

JWT PEM in `.env` uses literal `\n` for newlines; `src/utils/jwt.ts` normalizes them via `loadPem()`.

### Portal (`apps/portal`)

```bash
cp .env.example .env           # VITE_API_URL, VITE_VERIFIER_API_KEY
npm run dev
```

### Mobile (`apps/mobile`)

```bash
flutter pub get
cd ios && pod install          # applies patch_mobile_scanner.rb
open ios/Runner.xcworkspace    # sign with Apple Development team

# Simulator (localhost API)
flutter run -d <simulator> \
  --dart-define=VERIFIA_API_URL=http://127.0.0.1:3001 \
  --dart-define=VERIFIA_SKIP_ATTEST=true

# Physical iPhone (use Mac LAN IP, same Wi‑Fi as backend)
flutter run -d <device-id> \
  --dart-define=VERIFIA_API_URL=http://<mac-lan-ip>:3001 \
  --dart-define=VERIFIA_SKIP_ATTEST=true
```

## Security layers (do not weaken casually)

1. **App Attest** — `apps/mobile/ios/Runner/AppAttestChannel.swift` + `apps/backend/src/services/app-attest.ts`
2. **FaceTec** — `apps/mobile/lib/services/facetec_service.dart` (stub until SDK wired), `apps/backend/src/services/facetec.ts`
3. **Passkeys** — `apps/mobile/lib/services/passkey_service.dart` (stub), `apps/backend/src/services/passkeys.ts`
4. **Ephemeral JWT** — `apps/backend/src/utils/jwt.ts`, single-use nonce via Prisma

`VERIFIA_SKIP_ATTEST=true` is for local dev/CI only. Never ship production with attest skipped.

## API surface (v1)

- `POST /api/v1/challenges` — portal creates nonce/QR
- `POST /api/v1/app-attest/register` — device registration
- `POST /api/v1/tokens/issue` — mobile issues badge after 3 layers
- `POST /api/v1/tokens/validate` — portal consumes token
- `GET /health`

Types: `packages/shared/src/index.ts`. Spec: `docs/api-spec.yaml`.

## Conventions

- TypeScript: strict types; shared request/response shapes live in `packages/shared`.
- Backend routes: Zod validation, `AppError` via `middleware/error-handler.ts`, Prisma in `services/db.ts`.
- Portal: env via `import.meta.env.VITE_*`; API client in `src/api/client.ts`.
- Flutter: feature code under `lib/`; native App Attest in `ios/Runner/`.
- Prefer focused diffs; no drive-by refactors or unsolicited markdown docs.
- Do not commit `.env`, keys, or `node_modules/`.
- Only create git commits when the user explicitly asks.

## iOS / mobile gotchas

- **No `UIMainStoryboardFile`** when using `SceneDelegate` — causes blank Flutter UI.
- **`mobile_scanner`**: use v7+; `ios/Podfile` runs `patch_mobile_scanner.rb` after `pod install` (Xcode 26 warnings, deprecated APIs).
- Do not call `MobileScannerController.start()` manually before `MobileScanner` attaches — use `autoStart` or let the widget initialize once; avoid wrapping `MobileScanner` in a parent that rebuilds it every frame.
- Physical device: trust developer cert in Settings; verify app needs network once.
- Package `flutter_passkeys` does not exist on pub.dev — passkeys are stubbed until Semana 3.

## CI

`.github/workflows/ci.yml`: backend (Postgres service + prisma migrate + vitest), portal (typecheck + build), shared (typecheck), Flutter analyze + test.

## Acceptance tests (M4)

See README table: TC-F01–F03 functional, TC-S01–S02 security, TC-U01 usability, KPI-01 latency &lt; 5s.

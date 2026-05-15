# VerifiA

> Token de presencia criptográfico efímero para autenticación de identidad en tiempo real.

VerifiA genera un badge digital de 2–5 minutos que prueba que una persona estuvo **físicamente presente**, superó un reto de **liveness 3D certificado** (FaceTec iBeta ISO 30107-3 L1+L2) y autorizó con **biometría del dispositivo** (Face ID via Passkeys) desde hardware Apple legítimo (App Attest).

## Arquitectura

```
Emisor (Backend) ←→ Portador (App Flutter iOS) ←→ Verificador (Portal Web)
```

**Flujo**: Portal genera QR con nonce → App escanea → FaceTec liveness → Passkey/Face ID firma → Backend emite JWT ES256 (TTL 5min) → Portal valida y muestra ✅/❌

## Monorepo

| Paquete | Tecnología | Descripción |
|---|---|---|
| `apps/backend` | Node.js + TypeScript + Express + Prisma | API REST, emisión y validación de tokens |
| `apps/portal` | React + Vite + TypeScript | Portal verificador web |
| `apps/mobile` | Flutter (Dart) + Swift MethodChannels | App iOS del portador |
| `packages/shared` | TypeScript | Tipos compartidos entre backend y portal |

## Stack de seguridad (4 capas)

1. **App Attest** — Verifica que la request viene de VerifiA legítima en dispositivo Apple real
2. **FaceTec** — Liveness 3D certificado, resiste fotos/video/máscaras 3D
3. **Passkeys + Face ID** — Firma ES256 en Secure Enclave, deepfakes arquitecturalmente irrelevantes
4. **JWT efímero** — ES256, uso único, nonce ligado al verificador, TTL 2–5 min

## Setup rápido

### Requisitos
- Node.js ≥ 20
- PostgreSQL (o Railway)
- Flutter SDK ≥ 3.x (para app móvil)
- Xcode 15+ (para iOS)

### Backend
```bash
cd apps/backend
cp .env.example .env        # completar variables
npm install
npx prisma migrate dev
npm run dev
```

### Portal
```bash
cd apps/portal
cp .env.example .env
npm install
npm run dev
```

### App móvil
```bash
cd apps/mobile
flutter pub get
# Abrir ios/Runner.xcworkspace en Xcode
# Configurar Bundle ID + Team + App Attest entitlement
flutter run --dart-define=VERIFIA_SKIP_ATTEST=false
```

## Variables de entorno

Ver `apps/backend/.env.example` y `apps/portal/.env.example` para la lista completa.

## Test cases (criterio de aceptación M4)

| ID | Tipo | Resultado esperado |
|---|---|---|
| TC-F01 | Funcional | Flujo completo → VÁLIDO |
| TC-F02 | Funcional | Token expirado → RECHAZADO |
| TC-F03 | Funcional | Nonce reutilizado → RECHAZADO |
| TC-S01 | Seguridad | JWT firma inválida → RECHAZADO |
| TC-S02 | Seguridad | Replay mismo nonce → RECHAZADO |
| TC-U01 | Usabilidad | Flujo < 120s sin entrenamiento |
| KPI-01 | Desempeño | Latencia total < 5s (LTE/Wi-Fi) |

## Tesis

Maestría en Ciberseguridad — ITESM  
Carlos Iván Ibarra Pacheco · A01646019  
Presentación final: 25 junio 2026

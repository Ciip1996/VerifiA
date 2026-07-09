---
name: QR Scan Status UX
overview: Enhance the portal's `PendingView` so that when the mobile app scans the QR the user gets a clear, animated "en proceso de verificación" transition — replacing the current subtle overlay with a proper step indicator and a prominent animated state card.
todos:
  - id: stepper
    content: Add 3-step progress bar above QR ring (Esperando → Escaneado → Verificando), updating based on pollStatus
    status: completed
  - id: scan-card
    content: Replace the QR overlay with a full animated status card for scanning and validating states (amber/green themes with spinner and descriptive text)
    status: completed
  - id: status-line
    content: Strengthen the existing status dot/label animation for better visibility during state changes
    status: completed
isProject: false
---

# QR Scan Status — Portal UX Enhancement

## What exists today

In [`apps/portal/src/pages/VerifierPage.tsx`](apps/portal/src/pages/VerifierPage.tsx) the `PendingView` already tracks three poll sub-states:

- `waiting` → QR displayed, actions visible, amber pulse dot "Esperando escaneo del QR…"
- `scanning` → small white overlay on QR with "📱 Escaneado" text
- `validating` → overlay with "✅ Validando…"

The problem: when the QR is scanned the transition is too subtle. There is no clear signal to the verifier that something is happening.

## Changes — only `PendingView` (lines 525–644)

### 1. Step progress bar (new, above the QR ring)

Three steps rendered as a horizontal stepper:

```
[1] Esperando  →  [2] Escaneado  →  [3] Verificando
```

Each step pill gets a state: `done` (teal), `active` (amber pulse for scanning, green pulse for validating), `pending` (grey).

Mapping:
- `waiting` → step 1 active
- `scanning` → step 1 done, step 2 active
- `validating` → steps 1–2 done, step 3 active

### 2. QR area — replace overlay with a status card when `pollStatus !== 'waiting'`

Instead of just blurring the QR with a small icon, render a dedicated animated card at the same size as the QR frame:

**`scanning` card** (amber theme):
- Spinning arc / animated ring in amber
- Large icon 📱
- Title "QR Escaneado" (bold, larger)
- Subtitle "Verificando identidad en el dispositivo…"
- Subtle pulsing background glow

**`validating` card** (green theme):
- Spinning arc / animated ring in green
- Animated ✅ icon
- Title "Badge recibido"
- Subtitle "Validando credenciales…"

The QR SVG is hidden (not removed) while either card is displayed.

### 3. Status label line (existing, lines 592–595)

No structural change — the existing dot + label row already updates. Increase the font weight and animate the dot with a stronger pulse so the change is noticeable.

### 4. Actions / invite card (existing)

No change — already hidden when `pollStatus !== 'waiting'`.

## File to edit

- [`apps/portal/src/pages/VerifierPage.tsx`](apps/portal/src/pages/VerifierPage.tsx) — `PendingView` JSX only (≈ lines 525–644). No other files needed.

## No backend changes needed

The backend already emits `ACTIVE` status (with `valid=false`) while the mobile is processing. The polling at 2s already triggers `scanning`. The only work is in the portal UI.

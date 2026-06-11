import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { rateLimit } from 'express-rate-limit';

import { challengesRouter } from './routes/challenges.js';
import { prisma } from './services/db.js';
import { appAttestRouter } from './routes/app-attest.js';
import { tokensRouter } from './routes/tokens.js';
import { passkeysRouter } from './routes/passkeys.js';
import { profilesRouter } from './routes/profiles.js';
import { authRouter } from './routes/auth.js';
import { accountsRouter } from './routes/accounts.js';
import { errorHandler } from './middleware/error-handler.js';

const app = express();
const PORT = process.env.PORT ?? 3001;

// ─── Security middleware ───────────────────────────────────────────────────
app.use(helmet());
app.use(
  cors({
    origin: process.env.CORS_ORIGIN ?? 'http://localhost:5173',
    methods: ['GET', 'POST', 'PATCH', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key'],
  })
);

// Global rate limiter
app.use(
  rateLimit({
    windowMs: 60 * 1000, // 1 minute
    max: 60,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Too many requests, please try again later.' },
  })
);

app.use(express.json({ limit: '20mb' }));

// ─── Health check ──────────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', version: '0.1.0', ts: new Date().toISOString() });
});

// ─── Apple App Site Association (required for Passkeys Associated Domains) ─
// Served at /.well-known/apple-app-site-association
// iOS reads this to authorize the app to create passkeys for this RP ID.
app.get('/.well-known/apple-app-site-association', (_req, res) => {
  const teamId = process.env.APPLE_TEAM_ID ?? 'TEAMID';
  const bundleId = process.env.APPLE_BUNDLE_ID ?? 'com.verifia.mobile';
  res.setHeader('Content-Type', 'application/json');
  res.json({
    webcredentials: {
      apps: [`${teamId}.${bundleId}`],
    },
  });
});

// ─── Routes ────────────────────────────────────────────────────────────────
app.use('/api/v1/auth', authRouter);
app.use('/api/v1/challenges', challengesRouter);
app.use('/api/v1/app-attest', appAttestRouter);
app.use('/api/v1/tokens', tokensRouter);
app.use('/api/v1/passkeys', passkeysRouter);
app.use('/api/v1/profile', profilesRouter);
app.use('/api/v1/accounts', accountsRouter);

// ─── Deep-link redirect page ───────────────────────────────────────────────
// GET /r/:nonce — serves an HTML page that auto-opens verifia:// in the app.
// This URL is what gets shared via WhatsApp/iMessage so it is HTTPS-clickable.
app.get('/r/:nonce', async (req, res) => {
  const { nonce } = req.params as { nonce: string };

  let deepLink: string | null = null;
  try {
    const challenge = await prisma.challenge.findUnique({
      where: { nonce },
      select: { nonce: true, verifier_id: true, exp_time: true, status: true },
    });
    if (challenge && challenge.status === 'PENDING' && challenge.exp_time > new Date()) {
      deepLink = `verifia://badge?nonce=${challenge.nonce}&verifier=${encodeURIComponent(challenge.verifier_id)}`;
    }
  } catch {
    // fall through to fallback
  }

  const expired = !deepLink;

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(`<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>VerifiA — Verificar identidad</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { background: #0f0f13; color: #e0e0e0; font-family: system-ui, -apple-system, sans-serif;
           min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 24px; }
    .card { background: #1a1a2e; border: 1px solid #2a2a3e; border-radius: 20px;
            max-width: 380px; width: 100%; padding: 36px 28px; text-align: center; }
    .logo { font-size: 2.2rem; font-weight: 800; color: #fff; margin-bottom: 8px; }
    .logo span { color: #6c63ff; }
    .subtitle { font-size: 0.85rem; color: #888; margin-bottom: 28px; }
    h2 { font-size: 1.1rem; margin-bottom: 10px; color: #fff; }
    p  { font-size: 0.88rem; color: #aaa; line-height: 1.6; margin-bottom: 20px; }
    .btn { display: block; background: #6c63ff; color: #fff; text-decoration: none;
           padding: 14px 24px; border-radius: 12px; font-weight: 700; font-size: 0.95rem;
           margin-bottom: 12px; border: none; cursor: pointer; width: 100%; }
    .btn:disabled { opacity: 0.5; cursor: not-allowed; }
    .btn-outline { background: transparent; border: 1px solid #3a3a5a; color: #aaa; font-size: 0.85rem; }
    .status { font-size: 0.78rem; color: #6c63ff; margin-top: 16px; min-height: 1.2em; }
    .expired { color: #ef4444; font-size: 0.9rem; }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">Verifi<span>A</span></div>
    <div class="subtitle">Verificación de identidad criptográfica</div>
    ${expired
      ? `<p class="expired">Este QR ya expiró o fue utilizado.<br>Solicita un nuevo código al verificador.</p>`
      : `<h2>Alguien te pide verificar tu identidad</h2>
         <p>Toca el botón para abrir la app VerifiA y completar la verificación.</p>
         <a href="${deepLink}" class="btn" id="openBtn">Abrir en VerifiA</a>
         <button class="btn btn-outline" onclick="document.getElementById('hint').style.display='block'">
           No tengo la app
         </button>
         <div id="hint" style="display:none;margin-top:16px">
           <p style="font-size:0.82rem;color:#888">
             Descarga VerifiA en el App Store, crea tu cuenta con tu INE y regresa a este enlace.
           </p>
         </div>
         <div class="status" id="status"></div>`
    }
  </div>
  ${!expired ? `<script>
    // Auto-open the app on page load
    let tried = false;
    function tryOpen() {
      if (tried) return;
      tried = true;
      const deepLink = ${JSON.stringify(deepLink)};
      window.location.href = deepLink;
      // Show hint if app didn't open after 2s
      setTimeout(() => {
        document.getElementById('status').textContent =
          '¿No se abrió la app? Toca el botón de arriba.';
      }, 2000);
    }
    window.addEventListener('load', tryOpen);
  </script>` : ''}
</body>
</html>`);
});

// ─── 404 ───────────────────────────────────────────────────────────────────
app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// ─── Global error handler ─────────────────────────────────────────────────
app.use(errorHandler);

// ─── Start ─────────────────────────────────────────────────────────────────
// Only bind to a port in non-Vercel environments (local dev, Railway, etc.)
if (!process.env.VERCEL) {
  app.listen(PORT, () => {
    console.log(`[VerifiA backend] listening on port ${PORT} (${process.env.NODE_ENV ?? 'development'})`);
  });
}

// Export for Vercel serverless runtime
export default app;

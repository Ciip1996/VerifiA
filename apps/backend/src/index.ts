import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { rateLimit } from 'express-rate-limit';

import { challengesRouter } from './routes/challenges.js';
import { appAttestRouter } from './routes/app-attest.js';
import { tokensRouter } from './routes/tokens.js';
import { errorHandler } from './middleware/error-handler.js';

const app = express();
const PORT = process.env.PORT ?? 3001;

// ─── Security middleware ───────────────────────────────────────────────────
app.use(helmet());
app.use(
  cors({
    origin: process.env.CORS_ORIGIN ?? 'http://localhost:5173',
    methods: ['GET', 'POST'],
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

app.use(express.json({ limit: '1mb' }));

// ─── Health check ──────────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', version: '0.1.0', ts: new Date().toISOString() });
});

// ─── Routes ────────────────────────────────────────────────────────────────
app.use('/api/v1/challenges', challengesRouter);
app.use('/api/v1/app-attest', appAttestRouter);
app.use('/api/v1/tokens', tokensRouter);

// ─── 404 ───────────────────────────────────────────────────────────────────
app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// ─── Global error handler ─────────────────────────────────────────────────
app.use(errorHandler);

// ─── Start ─────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`[VerifiA backend] listening on port ${PORT} (${process.env.NODE_ENV ?? 'development'})`);
});

export default app;

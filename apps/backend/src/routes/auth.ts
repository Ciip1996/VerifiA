import { Router } from 'express';
import { z } from 'zod';
import bcrypt from 'bcryptjs';
import { SignJWT, importPKCS8 } from 'jose';
import { prisma } from '../services/db.js';
import { AppError } from '../middleware/error-handler.js';
import { requireAccount } from '../middleware/account-auth.js';

export const authRouter = Router();

const ACCOUNT_ISSUER = 'verifia-account';
const ACCOUNT_TTL_SECONDS = 7 * 24 * 60 * 60; // 7 days

function loadPem(value: string | undefined, name: string): string {
  if (!value) throw new Error(`${name} not set`);
  return value.replace(/\\n/g, '\n');
}

async function issueAccountToken(accountId: string, email: string): Promise<string> {
  const privateKey = await importPKCS8(
    loadPem(process.env.JWT_PRIVATE_KEY_PEM, 'JWT_PRIVATE_KEY_PEM'),
    'ES256'
  );
  const now = Math.floor(Date.now() / 1000);
  return new SignJWT({ email })
    .setProtectedHeader({ alg: 'ES256' })
    .setIssuedAt(now)
    .setIssuer(ACCOUNT_ISSUER)
    .setSubject(accountId)
    .setExpirationTime(now + ACCOUNT_TTL_SECONDS)
    .sign(privateKey);
}

/**
 * POST /api/v1/auth/set-password
 * Called from mobile after FaceTec onboarding. Creates a web account linked to device_id.
 */
authRouter.post('/set-password', async (req, res, next) => {
  try {
    const parsed = z.object({
      device_id: z.string().min(1),
      email: z.string().email(),
      password: z.string().min(8),
    }).safeParse(req.body);

    if (!parsed.success) {
      throw new AppError(400, 'Invalid request body', 'VALIDATION_ERROR');
    }

    const { device_id, email, password } = parsed.data;

    // Verify the device has a registered profile
    const profile = await prisma.userProfile.findUnique({ where: { device_id } });
    if (!profile) {
      throw new AppError(404, 'Device profile not found. Complete onboarding first.', 'PROFILE_NOT_FOUND');
    }

    // Check if email already taken
    const existing = await prisma.account.findUnique({ where: { email } });
    if (existing && existing.device_id !== device_id) {
      throw new AppError(409, 'Email already registered to another account', 'EMAIL_TAKEN');
    }

    const password_hash = await bcrypt.hash(password, 12);

    const account = await prisma.account.upsert({
      where: { device_id },
      create: { email, password_hash, device_id },
      update: { email, password_hash },
    });

    const session_token = await issueAccountToken(account.id, account.email);

    res.status(201).json({
      registered: true,
      account_id: account.id,
      session_token,
      expires_in: ACCOUNT_TTL_SECONDS,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/v1/auth/login
 * Web/mobile login with email + password. Returns a 7-day session JWT.
 */
authRouter.post('/login', async (req, res, next) => {
  try {
    const parsed = z.object({
      email: z.string().email(),
      password: z.string().min(1),
    }).safeParse(req.body);

    if (!parsed.success) {
      throw new AppError(400, 'Invalid request body', 'VALIDATION_ERROR');
    }

    const { email, password } = parsed.data;

    const account = await prisma.account.findUnique({ where: { email } });
    if (!account) {
      // Generic error to avoid user enumeration
      throw new AppError(401, 'Credenciales incorrectas', 'INVALID_CREDENTIALS');
    }

    const valid = await bcrypt.compare(password, account.password_hash);
    if (!valid) {
      throw new AppError(401, 'Credenciales incorrectas', 'INVALID_CREDENTIALS');
    }

    // Fetch linked profile for response
    const profile = await prisma.userProfile.findUnique({
      where: { device_id: account.device_id },
    });

    const session_token = await issueAccountToken(account.id, account.email);

    res.json({
      session_token,
      expires_in: ACCOUNT_TTL_SECONDS,
      account: {
        id: account.id,
        email: account.email,
        full_name: profile?.full_name ?? null,
        id_type: profile?.id_type ?? null,
        profile_photo: profile?.profile_photo ?? null,
      },
    });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/v1/auth/me
 * Returns the authenticated account's profile. Requires Bearer session JWT.
 */
authRouter.get('/me', requireAccount, async (req, res, next) => {
  try {
    const account = await prisma.account.findUnique({
      where: { id: req.account!.id },
    });
    if (!account) {
      throw new AppError(404, 'Account not found', 'ACCOUNT_NOT_FOUND');
    }

    const profile = await prisma.userProfile.findUnique({
      where: { device_id: account.device_id },
    });

    res.json({
      id: account.id,
      email: account.email,
      full_name: profile?.full_name ?? null,
      curp: profile?.curp ?? null,
      date_of_birth: profile?.date_of_birth ?? null,
      id_type: profile?.id_type ?? null,
      profile_photo: profile?.profile_photo ?? null,
    });
  } catch (err) {
    next(err);
  }
});

import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../services/db.js';
import { AppError } from '../middleware/error-handler.js';
import { verifyAppAttest } from '../services/app-attest.js';
import { generateNonce } from '../utils/crypto.js';

export const appAttestRouter = Router();

/**
 * GET /api/v1/app-attest/challenge
 * Returns a fresh 32-byte hex nonce for App Attest key registration.
 * The nonce is stored temporarily so the backend can verify it during /register.
 * TTL: 5 minutes.
 */
appAttestRouter.get('/challenge', async (_req, res, next) => {
  try {
    const challenge = generateNonce();
    // Persist temporarily — reuse the Challenge table with a synthetic verifier_id
    await prisma.challenge.create({
      data: {
        nonce: challenge,
        verifier_id: '__attest_registration__',
        exp_time: new Date(Date.now() + 5 * 60 * 1000),
        status: 'PENDING',
      },
    });
    res.json({ challenge });
  } catch (err) {
    next(err);
  }
});

const RegisterSchema = z.object({
  attestation_object: z.string().min(1), // base64url
  client_data_json: z.string().min(1),   // base64url
  challenge: z.string().length(64),      // 32-byte hex nonce
});

/**
 * POST /api/v1/app-attest/register
 * Registers an App Attest key for a device.
 * Called once per device on first launch.
 */
appAttestRouter.post('/register', async (req, res, next) => {
  try {
    const skipAttest = process.env.VERIFIA_SKIP_ATTEST === 'true';

    const parsed = RegisterSchema.safeParse(req.body);
    if (!parsed.success) {
      throw new AppError(400, 'Invalid attestation payload', 'VALIDATION_ERROR');
    }

    const { attestation_object, client_data_json, challenge } = parsed.data;

    let deviceId: string;
    let publicKeyPem: string;

    if (skipAttest) {
      // CI / simulator mode — accept without verifying
      deviceId = `dev-${challenge.slice(0, 16)}`;
      publicKeyPem = 'SKIP_ATTEST_MODE';
    } else {
      const result = await verifyAppAttest({
        attestation_object,
        client_data_json,
        challenge,
      });
      deviceId = result.deviceId;
      publicKeyPem = result.publicKeyPem;
    }

    // Upsert — device may re-attest after rotation
    await prisma.appAttestKey.upsert({
      where: { device_id: deviceId },
      update: {
        public_key_pem: publicKeyPem,
        attestation_data: attestation_object,
      },
      create: {
        device_id: deviceId,
        public_key_pem: publicKeyPem,
        attestation_data: attestation_object,
      },
    });

    await prisma.auditLog.create({
      data: {
        action: 'APP_ATTEST_REGISTER',
        device_id: deviceId,
        result: 'SUCCESS',
      },
    });

    res.status(201).json({ registered: true, device_id: deviceId });
  } catch (err) {
    next(err);
  }
});

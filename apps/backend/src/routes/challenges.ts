import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../services/db.js';
import { generateNonce } from '../utils/crypto.js';
import { AppError } from '../middleware/error-handler.js';

export const challengesRouter = Router();

const CreateChallengeSchema = z.object({
  verifier_id: z.string().min(1).max(128),
});

/**
 * POST /api/v1/challenges
 * Creates a new challenge nonce for a verifier session.
 * The portal calls this to generate the QR code.
 */
challengesRouter.post('/', async (req, res, next) => {
  try {
    const parsed = CreateChallengeSchema.safeParse(req.body);
    if (!parsed.success) {
      throw new AppError(400, 'Invalid request body', 'VALIDATION_ERROR');
    }

    const { verifier_id } = parsed.data;
    const nonce = generateNonce();
    const ttlSeconds = parseInt(process.env.CHALLENGE_TTL_SECONDS ?? '600', 10);
    const expTime = new Date(Date.now() + ttlSeconds * 1000);

    const challenge = await prisma.challenge.create({
      data: {
        nonce,
        verifier_id,
        exp_time: expTime,
        status: 'PENDING',
      },
    });

    const deepLink = `verifia://badge?nonce=${nonce}&verifier=${encodeURIComponent(verifier_id)}`;
    const qrData = deepLink;

    res.status(201).json({
      nonce: challenge.nonce,
      verifier_id,
      expires_in: ttlSeconds,
      qr_data: qrData,
      deep_link: deepLink,
      expires_at: expTime.toISOString(),
    });
  } catch (err) {
    next(err);
  }
});

import { Router } from 'express';
import { z } from 'zod';
import { rateLimit } from 'express-rate-limit';
import { prisma } from '../services/db.js';
import { AppError } from '../middleware/error-handler.js';
import { optionalAccount } from '../middleware/account-auth.js';
import { verifyReceipt, type ReceiptRecord } from '../services/receipts.js';

export const receiptsRouter = Router();

export type ReceiptStatus = 'VALID' | 'EXPIRED' | 'INVALID' | 'NOT_FOUND';

// Dedicated, stricter rate limiter for the (unauthenticated) receipt lookups —
// these accept opaque ids / JWTs from anyone, so keep the surface tight.
const receiptLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many receipt lookups, please try again later.' },
});

receiptsRouter.use(receiptLimiter);

/** Compute VALID vs EXPIRED for a receipt row that has a real signature. */
function statusForRecord(record: ReceiptRecord): 'VALID' | 'EXPIRED' {
  return record.expires_at.getTime() > Date.now() ? 'VALID' : 'EXPIRED';
}

/**
 * Owner-only identity block — the full media set, sourced the same way
 * /tokens/validate does (UserProfile + the badge Token liveness snapshot/score).
 */
async function buildIdentity(record: ReceiptRecord) {
  if (!record.device_id) return null;
  const profile = await prisma.userProfile.findUnique({
    where: { device_id: record.device_id },
  });
  if (!profile) return null;
  const token = await prisma.token.findUnique({
    where: { jti: record.badge_jti },
    select: { liveness_snapshot: true, liveness_match_score: true },
  });
  return {
    full_name: profile.full_name,
    curp: profile.curp,
    date_of_birth: profile.date_of_birth,
    id_type: profile.id_type,
    profile_photo: profile.profile_photo,
    id_front_photo: profile.id_front_photo,
    id_back_photo: profile.id_back_photo,
    facetec_match_level: profile.facetec_match_level,
    liveness_snapshot: token?.liveness_snapshot ?? null,
    liveness_match_score: token?.liveness_match_score ?? null,
  };
}

/** The always-safe public subset — no subject_name, no nonce. */
function publicSubset(record: ReceiptRecord, status: 'VALID' | 'EXPIRED') {
  return {
    valid: status === 'VALID',
    status,
    verified_at: record.verified_at.toISOString(),
    badge_valid_from: record.badge_valid_from.toISOString(),
    badge_valid_until: record.badge_valid_until.toISOString(),
  };
}

/**
 * GET /api/v1/receipts/:id
 * Bare-id lookup (no proof of possession of the receipt JWT).
 * Returns ONLY the public subset — deliberately NO subject_name and NO nonce,
 * since the caller has not proven they hold the actual signed receipt.
 * Owner (account_id match) additionally gets subject_name + the identity block.
 */
receiptsRouter.get('/:id', optionalAccount, async (req, res, next) => {
  try {
    const { id } = req.params as { id: string };
    const record = await prisma.verificationReceipt.findUnique({ where: { id } });
    if (!record) {
      res.status(404).json({ valid: false, status: 'NOT_FOUND' as ReceiptStatus });
      return;
    }

    const status = statusForRecord(record);
    const base = publicSubset(record, status);

    const isOwner = !!req.account?.id && req.account.id === record.account_id;
    if (!isOwner) {
      res.json(base);
      return;
    }

    // Owner tier: name + full identity media.
    const identity = await buildIdentity(record);
    res.json({ ...base, subject_name: record.subject_name, identity });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/v1/receipts/verify
 * Body: { receipt_jwt }. Verifies the ES256 signature + purpose + expiry, then
 * confirms the backing row still exists. Never mutates state.
 * Because the caller submits the complete signed JWT, it is safe to return
 * subject_name here (proof of possession substitutes for auth). The identity
 * block is still gated on account ownership.
 */
const VerifySchema = z.object({ receipt_jwt: z.string().min(1) });

receiptsRouter.post('/verify', optionalAccount, async (req, res, next) => {
  try {
    const parsed = VerifySchema.safeParse(req.body);
    if (!parsed.success) {
      throw new AppError(400, 'Invalid request body', 'VALIDATION_ERROR');
    }

    const result = await verifyReceipt(parsed.data.receipt_jwt);

    // Tampered / forged / not-a-receipt / unknown → invalid (possible fraud).
    if (!result.valid && result.reason === 'invalid_signature') {
      res.json({ valid: false, status: 'INVALID' as ReceiptStatus });
      return;
    }
    if (!result.valid && (result.reason === 'not_a_receipt' || result.reason === 'not_found')) {
      res.json({ valid: false, status: 'INVALID' as ReceiptStatus });
      return;
    }

    // Expired-but-authentic: the verification genuinely happened, the 30-day
    // record simply lapsed. Return the real details so the UI can say so.
    if (!result.valid && result.reason === 'expired') {
      if (!result.record) {
        res.json({ valid: false, status: 'EXPIRED' as ReceiptStatus });
        return;
      }
      const base = { ...publicSubset(result.record, 'EXPIRED'), subject_name: result.record.subject_name };
      const isOwner = !!req.account?.id && req.account.id === result.record.account_id;
      if (!isOwner) {
        res.json(base);
        return;
      }
      const identity = await buildIdentity(result.record);
      res.json({ ...base, identity });
      return;
    }

    // Authentic and within TTL.
    const record = result.record!;
    const status = statusForRecord(record);
    const base = { ...publicSubset(record, status), subject_name: record.subject_name };
    const isOwner = !!req.account?.id && req.account.id === record.account_id;
    if (!isOwner) {
      res.json(base);
      return;
    }
    const identity = await buildIdentity(record);
    res.json({ ...base, identity });
  } catch (err) {
    next(err);
  }
});

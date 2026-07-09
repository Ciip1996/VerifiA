import { SignJWT, importPKCS8, importSPKI, jwtVerify, errors as joseErrors } from 'jose';
import { randomUUID } from 'crypto';
import type { Challenge, Token } from '@prisma/client';
import { prisma } from './db.js';

const RECEIPT_ISSUER = process.env.JWT_ISSUER ?? 'https://api.verifia.dev';
const RECEIPT_TTL_SECONDS = parseInt(process.env.RECEIPT_TTL_SECONDS ?? String(30 * 24 * 60 * 60), 10);
const RECEIPT_PURPOSE = 'verification_receipt';
const RECEIPT_AUDIENCE = 'verifia-receipt';
// Key id embedded in the receipt JWT header. There is a single key today, but
// stamping a `kid` now means a future key rotation can be distinguished by old
// clients that embed the public key as a compile-time constant.
export const RECEIPT_KID = 'v1';

/** .env stores PEM with literal \n; normalize to real newlines for jose. */
function loadPem(value: string | undefined, name: string): string {
  if (!value) throw new Error(`${name} not set`);
  return value.replace(/\\n/g, '\n');
}

export interface ReceiptRecord {
  id: string;
  jti: string;
  challenge_nonce: string;
  badge_jti: string;
  account_id: string | null;
  device_id: string | null;
  subject_name: string | null;
  issued_via: string;
  verified_at: Date;
  badge_valid_from: Date;
  badge_valid_until: Date;
  expires_at: Date;
  receipt_jwt_raw: string;
}

export interface IssueReceiptResult {
  receiptId: string;
  jwt: string;
  deepLink: string;
  record: ReceiptRecord;
}

/**
 * Builds a `verifia://receipt?jwt=...` deep link for a signed receipt JWT.
 */
export function buildReceiptDeepLink(jwt: string): string {
  return `verifia://receipt?jwt=${encodeURIComponent(jwt)}`;
}

/**
 * Issue (or return the existing) verification receipt for a completed badge.
 *
 * Idempotent by construction: the DB enforces a unique constraint on
 * `challenge_nonce`, so a double-invocation (e.g. P2P issue then a stray portal
 * validate) returns the already-persisted receipt instead of creating a second.
 *
 * @param challenge  the Challenge that was just consumed
 * @param token      the badge Token that was just created (source of jti/iat/exp)
 * @param issuedVia  'issue' (P2P /tokens/issue) | 'validate' (portal /tokens/validate)
 */
export async function issueReceipt(params: {
  challenge: Challenge;
  token: Token;
  issuedVia: 'issue' | 'validate';
}): Promise<IssueReceiptResult> {
  const { challenge, token, issuedVia } = params;

  // If a receipt already exists for this challenge, return it (true idempotency).
  const existing = await prisma.verificationReceipt.findUnique({
    where: { challenge_nonce: challenge.nonce },
  });
  if (existing) {
    return {
      receiptId: existing.id,
      jwt: existing.receipt_jwt_raw,
      deepLink: buildReceiptDeepLink(existing.receipt_jwt_raw),
      record: existing,
    };
  }

  // Resolve the subject's display name (no photos in the receipt itself).
  let subjectName: string | null = null;
  if (token.device_id) {
    const profile = await prisma.userProfile.findUnique({
      where: { device_id: token.device_id },
      select: { full_name: true },
    });
    subjectName = profile?.full_name ?? null;
  }

  const receiptId = randomUUID();
  const jti = randomUUID();
  const now = Math.floor(Date.now() / 1000);
  const expTs = now + RECEIPT_TTL_SECONDS;
  const verifiedAt = new Date();

  const privateKey = await importPKCS8(
    loadPem(process.env.JWT_PRIVATE_KEY_PEM, 'JWT_PRIVATE_KEY_PEM'),
    'ES256'
  );

  const jwt = await new SignJWT({
    purpose: RECEIPT_PURPOSE,
    receipt_id: receiptId,
    nonce: challenge.nonce,
    badge_jti: token.jti,
    verified_at: verifiedAt.toISOString(),
    badge_valid_from: token.iat.toISOString(),
    badge_valid_until: token.exp.toISOString(),
    challenge_account_id: challenge.account_id ?? null,
    device_id: token.device_id ?? null,
    subject_name: subjectName,
  })
    .setProtectedHeader({ alg: 'ES256', kid: RECEIPT_KID })
    .setIssuedAt(now)
    .setIssuer(RECEIPT_ISSUER)
    .setAudience(RECEIPT_AUDIENCE)
    .setSubject(receiptId)
    .setExpirationTime(expTs)
    .setJti(jti)
    .sign(privateKey);

  try {
    const record = await prisma.verificationReceipt.create({
      data: {
        id: receiptId,
        jti,
        challenge_nonce: challenge.nonce,
        badge_jti: token.jti,
        account_id: challenge.account_id ?? null,
        device_id: token.device_id ?? null,
        subject_name: subjectName,
        issued_via: issuedVia,
        verified_at: verifiedAt,
        badge_valid_from: token.iat,
        badge_valid_until: token.exp,
        expires_at: new Date(expTs * 1000),
        receipt_jwt_raw: jwt,
      },
    });
    return { receiptId: record.id, jwt, deepLink: buildReceiptDeepLink(jwt), record };
  } catch (err) {
    // Unique-violation race (P2999/P2002): another invocation won — return theirs.
    const raced = await prisma.verificationReceipt.findUnique({
      where: { challenge_nonce: challenge.nonce },
    });
    if (raced) {
      return {
        receiptId: raced.id,
        jwt: raced.receipt_jwt_raw,
        deepLink: buildReceiptDeepLink(raced.receipt_jwt_raw),
        record: raced,
      };
    }
    throw err;
  }
}

export interface VerifyReceiptResult {
  valid: boolean;
  reason?: 'expired' | 'invalid_signature' | 'not_a_receipt' | 'not_found';
  record?: ReceiptRecord;
  claims?: {
    receipt_id: string;
    nonce: string;
    badge_jti: string;
    verified_at: string;
    badge_valid_from: string;
    badge_valid_until: string;
    subject_name: string | null;
  };
}

/**
 * Verify a receipt JWT's ES256 signature, purpose, and expiry, then confirm the
 * backing row still exists. Never mutates state.
 *
 * Distinguishes an expired-but-authentic receipt (`reason: 'expired'`, the
 * verification genuinely happened, only the 30-day record lapsed) from a
 * tampered/forged one (`reason: 'invalid_signature'`, possible fraud) — the two
 * carry emotionally opposite meanings for the caller.
 */
export async function verifyReceipt(receiptJwt: string): Promise<VerifyReceiptResult> {
  const publicKey = await importSPKI(
    loadPem(process.env.JWT_PUBLIC_KEY_PEM, 'JWT_PUBLIC_KEY_PEM'),
    'ES256'
  );

  let payload: Record<string, unknown>;
  try {
    const verified = await jwtVerify(receiptJwt, publicKey, {
      issuer: RECEIPT_ISSUER,
      audience: RECEIPT_AUDIENCE,
      algorithms: ['ES256'],
    });
    payload = verified.payload as Record<string, unknown>;
  } catch (err) {
    // An expired-but-otherwise-valid receipt is authentic, just past its TTL.
    if (err instanceof joseErrors.JWTExpired) {
      const p = err.payload as Record<string, unknown> | undefined;
      const jti = (p?.['jti'] as string) ?? undefined;
      const record = jti
        ? await prisma.verificationReceipt.findUnique({ where: { jti } })
        : null;
      return { valid: false, reason: 'expired', record: record ?? undefined };
    }
    return { valid: false, reason: 'invalid_signature' };
  }

  if (payload['purpose'] !== RECEIPT_PURPOSE) {
    return { valid: false, reason: 'not_a_receipt' };
  }

  const jti = payload['jti'] as string;
  const record = await prisma.verificationReceipt.findUnique({ where: { jti } });
  if (!record) {
    return { valid: false, reason: 'not_found' };
  }

  return {
    valid: true,
    record,
    claims: {
      receipt_id: payload['receipt_id'] as string,
      nonce: payload['nonce'] as string,
      badge_jti: payload['badge_jti'] as string,
      verified_at: payload['verified_at'] as string,
      badge_valid_from: payload['badge_valid_from'] as string,
      badge_valid_until: payload['badge_valid_until'] as string,
      subject_name: (payload['subject_name'] as string | null) ?? null,
    },
  };
}

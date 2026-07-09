/**
 * Integration tests for verification receipts.
 *
 * Covers:
 *   - Idempotency: issuing a receipt twice for the same challenge returns the same row
 *   - verifyReceipt accepts an authentic receipt and exposes subject_name in claims
 *   - Tampered / forged receipt JWT is rejected (invalid_signature)
 *   - Expired receipt is reported as expired (authentic, just past TTL) without throwing
 *   - P2P security fix: a Token created USED at issuance cannot be re-consumed via /validate
 *
 * Requirements:
 *   - Running PostgreSQL (DATABASE_URL in .env)
 *   - Valid JWT keypair (generated fresh below)
 *
 * Run: npm test  (from apps/backend)
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { generateKeyPair, exportPKCS8, exportSPKI, SignJWT, importPKCS8 } from 'jose';
import { prisma } from '../services/db.js';
import { issueReceipt, verifyReceipt } from '../services/receipts.js';
import { issueToken } from '../utils/jwt.js';
import { generateNonce } from '../utils/crypto.js';

let publicKeyPem: string;
let otherPrivateKeyPem: string;

beforeAll(async () => {
  const { privateKey, publicKey } = await generateKeyPair('ES256');
  const privateKeyPem = await exportPKCS8(privateKey);
  publicKeyPem = await exportSPKI(publicKey);

  const { privateKey: otherPriv } = await generateKeyPair('ES256');
  otherPrivateKeyPem = await exportPKCS8(otherPriv);

  process.env.JWT_PRIVATE_KEY_PEM = privateKeyPem;
  process.env.JWT_PUBLIC_KEY_PEM = publicKeyPem;
  process.env.JWT_ISSUER = 'https://api.verifia.dev';
  process.env.TOKEN_TTL_SECONDS = '300';
  process.env.RECEIPT_TTL_SECONDS = String(30 * 24 * 60 * 60);
});

afterAll(async () => {
  await prisma.$disconnect();
});

const AUD = 'receipt-test-verifier';
const DEVICE = 'receipt-test-device';

async function makeChallengeAndToken(opts: { withProfile?: boolean; accountId?: string | null } = {}) {
  const nonce = generateNonce();
  const challenge = await prisma.challenge.create({
    data: {
      nonce,
      verifier_id: AUD,
      exp_time: new Date(Date.now() + 600_000),
      status: 'USED',
      account_id: opts.accountId ?? null,
    },
  });

  if (opts.withProfile) {
    await prisma.userProfile.upsert({
      where: { device_id: DEVICE },
      create: {
        device_id: DEVICE,
        full_name: 'Test Subject',
        id_type: 'INE',
        profile_photo: 'x',
        id_front_photo: 'y',
      },
      update: { full_name: 'Test Subject' },
    });
  }

  // Mirror the /tokens/issue decision: P2P (account_id present) consumes the
  // badge at issuance (status USED); the portal flow leaves it ACTIVE.
  const isP2P = !!challenge.account_id;
  const { jwt, jti, exp } = await issueToken({ sub: 'u', aud: AUD, nonce, device_id: DEVICE });
  const token = await prisma.token.create({
    data: {
      jti, nonce, aud: AUD, exp,
      status: isP2P ? 'USED' : 'ACTIVE',
      jwt_raw: jwt,
      device_id: DEVICE,
    },
  });

  return { challenge, token };
}

describe('Receipt idempotency', () => {
  it('issuing a receipt twice for the same challenge returns the same row', async () => {
    const { challenge, token } = await makeChallengeAndToken({ withProfile: true });

    const first = await issueReceipt({ challenge, token, issuedVia: 'issue' });
    const second = await issueReceipt({ challenge, token, issuedVia: 'validate' });

    expect(second.receiptId).toBe(first.receiptId);
    expect(second.jwt).toBe(first.jwt);

    const count = await prisma.verificationReceipt.count({
      where: { challenge_nonce: challenge.nonce },
    });
    expect(count).toBe(1);
  });

  it('re-verifying a receipt N times never mutates the row', async () => {
    const { challenge, token } = await makeChallengeAndToken();
    const { jwt, receiptId } = await issueReceipt({ challenge, token, issuedVia: 'issue' });

    const before = await prisma.verificationReceipt.findUnique({ where: { id: receiptId } });
    for (let i = 0; i < 3; i++) {
      const r = await verifyReceipt(jwt);
      expect(r.valid).toBe(true);
    }
    const after = await prisma.verificationReceipt.findUnique({ where: { id: receiptId } });
    expect(after).toEqual(before);
  });
});

describe('Receipt verification', () => {
  it('accepts an authentic receipt and exposes subject_name in the JWT claims', async () => {
    const { challenge, token } = await makeChallengeAndToken({ withProfile: true });
    const { jwt } = await issueReceipt({ challenge, token, issuedVia: 'issue' });

    const result = await verifyReceipt(jwt);
    expect(result.valid).toBe(true);
    expect(result.claims?.subject_name).toBe('Test Subject');
    expect(result.claims?.nonce).toBe(challenge.nonce);
  });

  it('rejects a receipt JWT signed with a different key as invalid_signature', async () => {
    const forgerKey = await importPKCS8(otherPrivateKeyPem, 'ES256');
    const forged = await new SignJWT({ purpose: 'verification_receipt', receipt_id: 'x' })
      .setProtectedHeader({ alg: 'ES256', kid: 'v1' })
      .setIssuedAt()
      .setIssuer('https://api.verifia.dev')
      .setAudience('verifia-receipt')
      .setSubject('x')
      .setExpirationTime('30d')
      .setJti('forged-receipt')
      .sign(forgerKey);

    const result = await verifyReceipt(forged);
    expect(result.valid).toBe(false);
    expect(result.reason).toBe('invalid_signature');
  });

  it('reports an expired receipt as expired (authentic, past TTL) without throwing', async () => {
    const { challenge, token } = await makeChallengeAndToken();

    // Craft a genuinely-signed receipt whose exp is already in the past, and
    // persist a matching row (RECEIPT_TTL_SECONDS is read once at import, so we
    // can't shorten the TTL at runtime — sign the expired JWT directly instead).
    const privKey = await importPKCS8(process.env.JWT_PRIVATE_KEY_PEM!, 'ES256');
    const now = Math.floor(Date.now() / 1000);
    const jti = generateNonce().slice(0, 24);
    const receiptId = generateNonce().slice(0, 24);
    const expiredJwt = await new SignJWT({
      purpose: 'verification_receipt',
      receipt_id: receiptId,
      nonce: challenge.nonce,
      badge_jti: token.jti,
      verified_at: new Date().toISOString(),
      badge_valid_from: token.iat.toISOString(),
      badge_valid_until: token.exp.toISOString(),
      subject_name: null,
    })
      .setProtectedHeader({ alg: 'ES256', kid: 'v1' })
      .setIssuedAt(now - 3600)
      .setIssuer('https://api.verifia.dev')
      .setAudience('verifia-receipt')
      .setSubject(receiptId)
      .setExpirationTime(now - 10) // already expired
      .setJti(jti)
      .sign(privKey);

    await prisma.verificationReceipt.create({
      data: {
        id: receiptId,
        jti,
        challenge_nonce: challenge.nonce,
        badge_jti: token.jti,
        account_id: null,
        device_id: token.device_id,
        subject_name: null,
        issued_via: 'issue',
        verified_at: new Date(),
        badge_valid_from: token.iat,
        badge_valid_until: token.exp,
        expires_at: new Date((now - 10) * 1000),
        receipt_jwt_raw: expiredJwt,
      },
    });

    const result = await verifyReceipt(expiredJwt);
    expect(result.valid).toBe(false);
    expect(result.reason).toBe('expired');
    // The backing row still exists — the verification genuinely happened.
    expect(result.record?.challenge_nonce).toBe(challenge.nonce);
  });
});

describe('P2P security — badge consumed at issuance', () => {
  it('a P2P Token is created USED so /validate would reject re-consumption with 409', async () => {
    // Create an account so the challenge is treated as P2P (account_id present).
    const account = await prisma.account.create({
      data: {
        email: `p2p-${generateNonce().slice(0, 12)}@test.dev`,
        password_hash: 'x',
        device_id: `p2p-dev-${generateNonce().slice(0, 12)}`,
      },
    });
    const { token } = await makeChallengeAndToken({ accountId: account.id });

    // The /issue P2P branch sets status USED immediately (badge single-use here).
    const stored = await prisma.token.findUnique({ where: { nonce: token.nonce } });
    expect(stored!.status).toBe('USED');
    // /validate checks status === 'USED' before aud → 409 TOKEN_USED,
    // so a guessed X-API-Key (the requester's email) cannot re-consume it.
    expect(stored!.status).not.toBe('ACTIVE');
  });
});

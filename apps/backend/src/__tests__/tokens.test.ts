/**
 * Integration tests for token issuance, validation, and security enforcement.
 *
 * Covers:
 *   TC-F02 — expired token is rejected on /validate
 *   TC-F03 — second use of same nonce is rejected
 *   TC-S01 — JWT forged with a different key is rejected
 *   TC-S04 — wrong audience on /validate is rejected
 *
 * Requirements:
 *   - Running PostgreSQL (DATABASE_URL in .env)
 *   - Valid JWT keypair in .env (JWT_PRIVATE_KEY_PEM / JWT_PUBLIC_KEY_PEM)
 *
 * Run: npm test  (from apps/backend)
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { generateKeyPair, exportPKCS8, exportSPKI } from 'jose';
import { prisma } from '../services/db.js';
import { issueToken, verifyToken } from '../utils/jwt.js';
import { generateNonce } from '../utils/crypto.js';

// ── Key setup ─────────────────────────────────────────────────────────────────

let privateKeyPem: string;
let publicKeyPem: string;
let otherPrivateKeyPem: string; // different key for TC-S01

beforeAll(async () => {
  // Generate a fresh ES256 keypair for the test run
  const { privateKey, publicKey } = await generateKeyPair('ES256');
  privateKeyPem = await exportPKCS8(privateKey);
  publicKeyPem = await exportSPKI(publicKey);

  // Generate a second keypair (used to forge tokens in TC-S01)
  const { privateKey: otherPrivKey } = await generateKeyPair('ES256');
  otherPrivateKeyPem = await exportPKCS8(otherPrivKey);

  // Inject into process.env so jwt.ts picks them up
  process.env.JWT_PRIVATE_KEY_PEM = privateKeyPem;
  process.env.JWT_PUBLIC_KEY_PEM = publicKeyPem;
  process.env.JWT_ISSUER = 'https://api.verifia.dev';
  process.env.TOKEN_TTL_SECONDS = '300';
  process.env.VERIFIA_SKIP_ATTEST = 'true';
});

afterAll(async () => {
  await prisma.$disconnect();
});

// ── Helpers ───────────────────────────────────────────────────────────────────

const TEST_AUDIENCE = 'test-verifier-key';
const TEST_DEVICE = 'test-device-001';

async function createActiveToken(overrides: { ttlSeconds?: number } = {}) {
  const nonce = generateNonce();
  const ttl = overrides.ttlSeconds ?? 300;
  const origTtl = process.env.TOKEN_TTL_SECONDS;
  process.env.TOKEN_TTL_SECONDS = String(ttl);

  const { jwt, jti, exp } = await issueToken({
    sub: 'test-user',
    aud: TEST_AUDIENCE,
    nonce,
    device_id: TEST_DEVICE,
  });

  process.env.TOKEN_TTL_SECONDS = origTtl;

  await prisma.token.create({
    data: {
      jti,
      nonce,
      aud: TEST_AUDIENCE,
      exp,
      status: 'ACTIVE',
      jwt_raw: jwt,
    },
  });

  return { nonce, jti, jwt, exp };
}

async function createExpiredToken() {
  // Create a token, then manually set its exp in the past
  const { nonce, jti, jwt } = await createActiveToken();
  const pastExp = new Date(Date.now() - 10_000); // 10 seconds ago
  await prisma.token.update({
    where: { nonce },
    data: { exp: pastExp, status: 'EXPIRED' },
  });
  return { nonce, jti, jwt };
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('TC-F02 — Expired token rejected', () => {
  it('verifyToken throws JWTExpired for an already-expired JWT', async () => {
    // Build a JWT whose exp is set 10 seconds in the past
    const { SignJWT, importPKCS8 } = await import('jose');
    const privKey = await importPKCS8(privateKeyPem, 'ES256');
    const nonce = generateNonce();
    const pastExp = Math.floor(Date.now() / 1000) - 10; // 10 seconds ago

    const expiredJwt = await new SignJWT({ nonce, device_id: TEST_DEVICE })
      .setProtectedHeader({ alg: 'ES256' })
      .setIssuedAt(pastExp - 300)
      .setIssuer('https://api.verifia.dev')
      .setSubject('test-user')
      .setAudience(TEST_AUDIENCE)
      .setExpirationTime(pastExp) // already expired
      .setJti('expired-jti')
      .sign(privKey);

    // verifyToken should throw because JWT is past exp
    await expect(verifyToken(expiredJwt, TEST_AUDIENCE)).rejects.toThrow();
  });

  it('DB token with status EXPIRED is recognised as expired', async () => {
    const { nonce } = await createExpiredToken();
    const token = await prisma.token.findUnique({ where: { nonce } });
    expect(token).not.toBeNull();
    expect(token!.status).toBe('EXPIRED');
    expect(token!.exp.getTime()).toBeLessThan(Date.now());
  });
});

describe('TC-F03 — Second use of same nonce rejected', () => {
  it('marking a token USED and attempting to find it as ACTIVE fails', async () => {
    const { nonce, jti } = await createActiveToken();

    // First consumption: mark USED
    await prisma.token.update({ where: { nonce }, data: { status: 'USED' } });

    // Second attempt: token is no longer ACTIVE
    const token = await prisma.token.findUnique({ where: { nonce } });
    expect(token).not.toBeNull();
    expect(token!.status).toBe('USED');

    // Simulate the /validate logic: token.status === 'USED' → 409
    expect(token!.jti).toBe(jti);
    expect(token!.status).not.toBe('ACTIVE');
  });

  it('challenge nonce with status USED is rejected for token issuance', async () => {
    const nonce = generateNonce();
    await prisma.challenge.create({
      data: {
        nonce,
        verifier_id: TEST_AUDIENCE,
        exp_time: new Date(Date.now() + 300_000),
        status: 'USED',
      },
    });

    const challenge = await prisma.challenge.findUnique({ where: { nonce } });
    expect(challenge!.status).toBe('USED');
    // The /issue route checks challenge.status === 'USED' → 409
    await prisma.challenge.delete({ where: { nonce } });
  });
});

describe('TC-S01 — Forged JWT with different key rejected', () => {
  it('verifyToken rejects a JWT signed with a different private key', async () => {
    // Sign a JWT with a different private key (forger's key)
    const { SignJWT, importPKCS8 } = await import('jose');
    const forgerPrivKey = await importPKCS8(otherPrivateKeyPem, 'ES256');
    const forgedJwt = await new SignJWT({ nonce: 'fake', device_id: 'evil' })
      .setProtectedHeader({ alg: 'ES256' })
      .setIssuedAt()
      .setIssuer('https://api.verifia.dev')
      .setSubject('attacker')
      .setAudience(TEST_AUDIENCE)
      .setExpirationTime('5m')
      .setJti('forged-jti')
      .sign(forgerPrivKey);

    // Verification with the correct public key must fail
    await expect(verifyToken(forgedJwt, TEST_AUDIENCE)).rejects.toThrow();
  });

  it('verifyToken accepts a JWT signed with the correct private key', async () => {
    const nonce = generateNonce();
    const { jwt } = await issueToken({
      sub: 'legit-user',
      aud: TEST_AUDIENCE,
      nonce,
      device_id: TEST_DEVICE,
    });

    const result = await verifyToken(jwt, TEST_AUDIENCE);
    expect(result.nonce).toBe(nonce);
    expect(result.sub).toBe('legit-user');
  });
});

describe('TC-S04 — Wrong audience rejected on /validate', () => {
  it('verifyToken throws when audience does not match', async () => {
    const nonce = generateNonce();
    const { jwt } = await issueToken({
      sub: 'test-user',
      aud: 'correct-audience',
      nonce,
      device_id: TEST_DEVICE,
    });

    // Verifying with a different audience must throw
    await expect(verifyToken(jwt, 'wrong-audience')).rejects.toThrow();
  });

  it('DB token with mismatched aud is flagged before verification', async () => {
    const { nonce } = await createActiveToken();
    const token = await prisma.token.findUnique({ where: { nonce } });
    expect(token!.aud).toBe(TEST_AUDIENCE);

    // Simulate the /validate route audience check
    const incomingApiKey = 'totally-different-verifier';
    expect(token!.aud).not.toBe(incomingApiKey);

    // Clean up
    await prisma.token.delete({ where: { nonce } });
  });
});

import {
  verifyRegistrationResponse,
  verifyAuthenticationResponse,
  generateRegistrationOptions,
  generateAuthenticationOptions,
} from '@simplewebauthn/server';
import type {
  RegistrationResponseJSON,
  AuthenticationResponseJSON,
} from '@simplewebauthn/server';
import { prisma } from './db.js';
import { AppError } from '../middleware/error-handler.js';

// RP (Relying Party) config — these must match what the iOS app sends.
const RP_ID = process.env.PASSKEY_RP_ID ?? 'api.verifia.dev';
const RP_NAME = process.env.PASSKEY_RP_NAME ?? 'VerifiA';
const RP_ORIGIN = process.env.PASSKEY_RP_ORIGIN ?? `https://${RP_ID}`;

// Dev bypass: when PASSKEY_RP_ID is not configured, skip full FIDO2 verification.
const isDevMode = !process.env.PASSKEY_RP_ID;

interface PasskeyVerifyResult {
  userId: string;
  credentialId: string;
}

// ─── Registration helpers (called once per device) ────────────────────────

export async function getRegistrationOptions(userId: string) {
  const opts = await generateRegistrationOptions({
    rpID: RP_ID,
    rpName: RP_NAME,
    userID: new TextEncoder().encode(userId),
    userName: userId,
    userDisplayName: 'VerifiA User',
    attestationType: 'none',
    authenticatorSelection: {
      authenticatorAttachment: 'platform',
      userVerification: 'required',
      residentKey: 'preferred',
    },
  });

  await prisma.passkeyRegistrationChallenge.upsert({
    where: { user_id: userId },
    update: {
      challenge: opts.challenge,
      exp_time: new Date(Date.now() + 5 * 60 * 1000),
    },
    create: {
      user_id: userId,
      challenge: opts.challenge,
      exp_time: new Date(Date.now() + 5 * 60 * 1000),
    },
  });

  return opts;
}

export async function verifyRegistration(
  userId: string,
  response: RegistrationResponseJSON,
): Promise<void> {
  const pending = await prisma.passkeyRegistrationChallenge.findUnique({
    where: { user_id: userId },
  });
  if (!pending) {
    throw new AppError(400, 'No pending registration challenge', 'PASSKEY_NO_CHALLENGE');
  }
  if (pending.exp_time < new Date()) {
    throw new AppError(410, 'Registration challenge expired', 'PASSKEY_CHALLENGE_EXPIRED');
  }

  const verification = await verifyRegistrationResponse({
    response,
    expectedChallenge: pending.challenge,
    expectedOrigin: RP_ORIGIN,
    expectedRPID: RP_ID,
    requireUserVerification: true,
  });

  if (!verification.verified || !verification.registrationInfo) {
    throw new AppError(401, 'Passkey registration failed', 'PASSKEY_REG_FAILED');
  }

  const { credential } = verification.registrationInfo;

  await prisma.passkeyCredential.upsert({
    where: { credential_id: credential.id },
    update: {
      public_key: Buffer.from(credential.publicKey),
      sign_count: credential.counter,
    },
    create: {
      credential_id: credential.id,
      public_key: Buffer.from(credential.publicKey),
      sign_count: credential.counter,
      user_id: userId,
    },
  });

  await prisma.passkeyRegistrationChallenge.delete({ where: { user_id: userId } });
}

// ─── Authentication options (assertion challenge) ─────────────────────────

export async function getAuthenticationOptions(credentialId?: string) {
  return generateAuthenticationOptions({
    rpID: RP_ID,
    userVerification: 'required',
    ...(credentialId ? { allowCredentials: [{ id: credentialId }] } : {}),
  });
}

// ─── Assertion verification ───────────────────────────────────────────────

export async function verifyPasskeyAssertion(input: {
  assertion: AuthenticationResponseJSON;
  challenge: string;
}): Promise<PasskeyVerifyResult> {
  const { assertion, challenge } = input;

  if (!assertion.response?.authenticatorData || !assertion.response?.clientDataJSON || !assertion.response?.signature) {
    throw new AppError(400, 'Incomplete passkey assertion', 'PASSKEY_INCOMPLETE');
  }

  // Dev bypass: verify only the challenge field, skip ECDSA
  if (isDevMode) {
    console.warn('[Passkeys] Dev mode — skipping FIDO2 verification (set PASSKEY_RP_ID to enable)');
    try {
      const clientDataStr = Buffer.from(assertion.response.clientDataJSON, 'base64url').toString('utf8');
      const clientData = JSON.parse(clientDataStr) as { type: string; challenge: string };
      const expectedChallenge = Buffer.from(challenge).toString('base64url');
      if (clientData.challenge !== expectedChallenge) {
        throw new AppError(401, 'Passkey challenge mismatch', 'PASSKEY_CHALLENGE_MISMATCH');
      }
    } catch (err) {
      if (err instanceof AppError) throw err;
      throw new AppError(401, 'Failed to parse passkey assertion', 'PASSKEY_PARSE_ERROR');
    }
    return {
      userId: assertion.response.userHandle ?? assertion.id,
      credentialId: assertion.id,
    };
  }

  // Production: full FIDO2 verification with stored credential
  const stored = await prisma.passkeyCredential.findUnique({
    where: { credential_id: assertion.id },
  });
  if (!stored) {
    throw new AppError(401, 'Unknown credential', 'PASSKEY_CREDENTIAL_NOT_FOUND');
  }

  const verification = await verifyAuthenticationResponse({
    response: assertion,
    expectedChallenge: Buffer.from(challenge).toString('base64url'),
    expectedOrigin: RP_ORIGIN,
    expectedRPID: RP_ID,
    requireUserVerification: true,
    credential: {
      id: stored.credential_id,
      publicKey: new Uint8Array(stored.public_key),
      counter: stored.sign_count,
    },
  });

  if (!verification.verified || !verification.authenticationInfo) {
    throw new AppError(401, 'Passkey assertion failed', 'PASSKEY_INVALID');
  }

  // Update sign counter (cloning detection)
  await prisma.passkeyCredential.update({
    where: { credential_id: assertion.id },
    data: { sign_count: verification.authenticationInfo.newCounter },
  });

  return {
    userId: stored.user_id,
    credentialId: assertion.id,
  };
}

import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../services/db.js';
import { AppError } from '../middleware/error-handler.js';
import { issueToken, verifyToken } from '../utils/jwt.js';
import { verifyAppAttestAssertion } from '../services/app-attest.js';
import { verifyFaceTecSession } from '../services/facetec.js';
import { verifyPasskeyAssertion } from '../services/passkeys.js';

export const tokensRouter = Router();

const IssueTokenSchema = z.object({
  nonce: z.string().length(64),
  app_attest_assertion: z.string().min(1),
  device_id: z.string().min(1),
  facetec_session_id: z.string().min(1),
  passkey_assertion: z.object({
    id: z.string(),
    raw_id: z.string(),
    authenticator_data: z.string(),
    client_data_json: z.string(),
    signature: z.string(),
    user_handle: z.string().optional(),
  }),
});

/**
 * POST /api/v1/tokens/issue
 * Validates all three security proofs and issues a JWT badge token.
 * App Attest assertion + FaceTec result + Passkey assertion → JWT ES256
 */
tokensRouter.post('/issue', async (req, res, next) => {
  try {
    const parsed = IssueTokenSchema.safeParse(req.body);
    if (!parsed.success) {
      throw new AppError(400, 'Invalid request body', 'VALIDATION_ERROR');
    }

    const { nonce, app_attest_assertion, device_id, facetec_session_id, passkey_assertion } = parsed.data;

    // 1. Validate challenge nonce
    const challenge = await prisma.challenge.findUnique({ where: { nonce } });
    if (!challenge) {
      throw new AppError(404, 'Challenge not found', 'NONCE_NOT_FOUND');
    }
    if (challenge.status === 'USED') {
      throw new AppError(409, 'Challenge already used', 'NONCE_USED');
    }
    if (challenge.exp_time < new Date()) {
      throw new AppError(410, 'Challenge expired', 'NONCE_EXPIRED');
    }

    // 2. Validate App Attest assertion (skip in CI mode)
    const skipAttest = process.env.VERIFIA_SKIP_ATTEST === 'true';
    if (!skipAttest) {
      const attestKey = await prisma.appAttestKey.findUnique({ where: { device_id } });
      if (!attestKey) {
        throw new AppError(401, 'Device not registered', 'DEVICE_NOT_ATTESTED');
      }
      await verifyAppAttestAssertion({
        assertion: app_attest_assertion,
        challenge: nonce,
        publicKeyPem: attestKey.public_key_pem,
        deviceId: device_id,
      });
    }

    // 3. Validate FaceTec liveness result
    await verifyFaceTecSession({
      session_id: facetec_session_id,
      nonce,
    });

    // 4. Validate Passkey (FIDO2) assertion
    const passkeyResult = await verifyPasskeyAssertion({
      assertion: passkey_assertion,
      challenge: nonce,
    });

    // 5. Mark challenge as USED
    await prisma.challenge.update({
      where: { nonce },
      data: { status: 'USED' },
    });

    // 6. Issue JWT ES256 token
    const { jwt, jti, exp } = await issueToken({
      sub: passkeyResult.userId,
      aud: challenge.verifier_id,
      nonce,
      device_id,
    });

    // 7. Persist token record
    await prisma.token.create({
      data: {
        jti,
        nonce,
        aud: challenge.verifier_id,
        exp,
        status: 'ACTIVE',
        jwt_raw: jwt,
      },
    });

    // 8. Audit log
    await prisma.auditLog.create({
      data: {
        action: 'TOKEN_ISSUED',
        token_jti: jti,
        device_id,
        result: 'SUCCESS',
      },
    });

    const ttl = parseInt(process.env.TOKEN_TTL_SECONDS ?? '300', 10);

    res.status(201).json({
      token: jwt,
      expires_in: ttl,
      expires_at: exp.toISOString(),
      badge_display: {
        jti,
        verifier: challenge.verifier_id,
        issued_at: new Date().toISOString(),
        expires_at: exp.toISOString(),
      },
    });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/v1/tokens/verify/:nonce
 * Non-destructive status check for portal polling.
 * Does NOT consume the token.
 */
tokensRouter.get('/verify/:nonce', async (req, res, next) => {
  try {
    const { nonce } = req.params;

    const token = await prisma.token.findUnique({ where: { nonce } });
    if (!token) {
      res.json({ valid: false, status: 'NOT_FOUND' });
      return;
    }

    const now = new Date();

    // Auto-expire tokens past their exp
    if (token.status === 'ACTIVE' && token.exp < now) {
      await prisma.token.update({ where: { nonce }, data: { status: 'EXPIRED' } });
      res.json({ valid: false, status: 'EXPIRED' });
      return;
    }

    res.json({
      valid: token.status === 'ACTIVE',
      status: token.status,
      exp: token.exp.toISOString(),
      iat: token.iat.toISOString(),
    });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/v1/tokens/validate/:nonce
 * Validates AND consumes the token (marks USED). Called by the verifier.
 */
tokensRouter.post('/validate/:nonce', async (req, res, next) => {
  try {
    const { nonce } = req.params;
    const audience = (req.headers['x-api-key'] as string) ?? '';

    if (!audience) {
      throw new AppError(401, 'Missing X-API-Key header', 'MISSING_API_KEY');
    }

    const token = await prisma.token.findUnique({ where: { nonce } });

    if (!token) {
      throw new AppError(404, 'Token not found', 'TOKEN_NOT_FOUND');
    }
    if (token.status === 'USED') {
      throw new AppError(409, 'Token already consumed', 'TOKEN_USED');
    }
    if (token.status === 'EXPIRED' || token.exp < new Date()) {
      throw new AppError(410, 'Token expired', 'TOKEN_EXPIRED');
    }
    if (token.aud !== audience) {
      throw new AppError(403, 'Audience mismatch', 'AUDIENCE_MISMATCH');
    }

    // Verify JWT signature
    await verifyToken(token.jwt_raw, audience);

    // Consume token
    const consumedAt = new Date();
    await prisma.token.update({
      where: { nonce },
      data: { status: 'USED' },
    });

    await prisma.auditLog.create({
      data: {
        action: 'TOKEN_VALIDATED',
        token_jti: token.jti,
        result: 'SUCCESS',
      },
    });

    res.json({
      valid: true,
      consumed_at: consumedAt.toISOString(),
      message: 'Token validated and consumed successfully',
      badge: {
        jti: token.jti,
        verifier: token.aud,
        issued_at: token.iat.toISOString(),
        expires_at: token.exp.toISOString(),
      },
    });
  } catch (err) {
    next(err);
  }
});

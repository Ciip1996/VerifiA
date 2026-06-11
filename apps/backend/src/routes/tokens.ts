import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../services/db.js';
import { AppError } from '../middleware/error-handler.js';
import { issueToken, verifyToken } from '../utils/jwt.js';
import type { AuthenticationResponseJSON } from '@simplewebauthn/server';
import { verifyAppAttestAssertion } from '../services/app-attest.js';
import { verifyFaceTecSession } from '../services/facetec.js';
import { verifyPasskeyAssertion } from '../services/passkeys.js';

export const tokensRouter = Router();

const IssueTokenSchema = z.object({
  nonce: z.string().length(64),
  app_attest_assertion: z.string().min(1),
  device_id: z.string().min(1),
  facetec_session_id: z.string().min(1),
  facetec_face_scan: z.string().optional(),        // base64 blob from FaceTec SDK
  facetec_audit_trail_image: z.string().optional(),
  liveness_match_score: z.number().int().min(0).max(100).nullable().optional(),
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

    const {
      nonce, app_attest_assertion, device_id,
      facetec_session_id, facetec_face_scan, facetec_audit_trail_image,
      liveness_match_score,
      passkey_assertion,
    } = parsed.data;

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
      face_scan: facetec_face_scan,
      audit_trail_image: facetec_audit_trail_image,
    });

    // 4. Validate Passkey (FIDO2) assertion
    // Map the Zod-validated shape into the AuthenticationResponseJSON format
    const assertionJson: AuthenticationResponseJSON = {
      id: passkey_assertion.id,
      rawId: passkey_assertion.raw_id,
      type: 'public-key',
      clientExtensionResults: {},
      response: {
        clientDataJSON: passkey_assertion.client_data_json,
        authenticatorData: passkey_assertion.authenticator_data,
        signature: passkey_assertion.signature,
        userHandle: passkey_assertion.user_handle,
      },
    };
    const passkeyResult = await verifyPasskeyAssertion({
      assertion: assertionJson,
      challenge: nonce,
    });

    // 5. FaceTec 3D-3D score threshold check — reject if too low
    const minScore = parseInt(process.env.FACETEC_MIN_MATCH_SCORE ?? '40', 10);
    if (liveness_match_score !== null && liveness_match_score !== undefined
        && liveness_match_score < minScore) {
      await prisma.challenge.update({
        where: { nonce },
        data: {
          status: 'REJECTED',
          rejection_reason: `FaceTec 3D match score too low: ${liveness_match_score}/100 (mínimo requerido: ${minScore}/100)`,
        },
      });
      await prisma.auditLog.create({
        data: {
          action: 'TOKEN_REJECTED',
          device_id,
          result: 'FAILURE',
          metadata: { reason: 'FACETEC_SCORE_BELOW_THRESHOLD', score: liveness_match_score, min_score: minScore },
        },
      });
      throw new AppError(422, 'Face match score below threshold — verification rejected', 'FACETEC_SCORE_REJECTED');
    }

    // 6. Mark challenge as USED
    await prisma.challenge.update({
      where: { nonce },
      data: { status: 'USED' },
    });

    // 8. Issue JWT ES256 token
    const { jwt, jti, exp } = await issueToken({
      sub: passkeyResult.userId,
      aud: challenge.verifier_id,
      nonce,
      device_id,
    });

    // 9. Persist token record (including identity link + liveness snapshot + 3D-3D score)
    await prisma.token.create({
      data: {
        jti,
        nonce,
        aud: challenge.verifier_id,
        exp,
        status: 'ACTIVE',
        jwt_raw: jwt,
        device_id,
        liveness_snapshot: facetec_audit_trail_image ?? facetec_face_scan ?? null,
        liveness_match_score: liveness_match_score ?? null,
      },
    });

    // 10. Audit log
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

    // First check if the challenge itself was rejected (FaceTec score below threshold)
    const challenge = await prisma.challenge.findUnique({ where: { nonce } });
    if (challenge?.status === 'REJECTED') {
      res.json({
        valid: false,
        status: 'REJECTED',
        rejection_reason: challenge.rejection_reason,
      });
      return;
    }

    // Check if challenge expired with no token
    if (challenge && challenge.status === 'PENDING' && challenge.exp_time < new Date()) {
      res.json({ valid: false, status: 'EXPIRED' });
      return;
    }

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

    // Look up user identity profile if token has a device_id
    let identity = null;
    if (token.device_id) {
      const profile = await prisma.userProfile.findUnique({
        where: { device_id: token.device_id },
      });
      if (profile) {
        identity = {
          full_name: profile.full_name,
          curp: profile.curp,
          date_of_birth: profile.date_of_birth,
          id_type: profile.id_type,
          profile_photo: profile.profile_photo,
          id_front_photo: profile.id_front_photo,
          id_back_photo: profile.id_back_photo,
          facetec_match_level: profile.facetec_match_level,
          liveness_snapshot: token.liveness_snapshot,
          liveness_match_score: token.liveness_match_score,
        };
      }
    }

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
      identity,
    });
  } catch (err) {
    next(err);
  }
});

import { Router } from 'express';
import { z } from 'zod';
import { AppError } from '../middleware/error-handler.js';
import {
  getRegistrationOptions,
  verifyRegistration,
  getAuthenticationOptions,
} from '../services/passkeys.js';

export const passkeysRouter = Router();

const UserIdSchema = z.object({ user_id: z.string().min(1) });

/**
 * POST /api/v1/passkeys/register/options
 * Returns FIDO2 registration options (challenge + RP config) for a given user.
 * Called once per device before creating a passkey credential.
 */
passkeysRouter.post('/register/options', async (req, res, next) => {
  try {
    const parsed = UserIdSchema.safeParse(req.body);
    if (!parsed.success) {
      throw new AppError(400, 'user_id required', 'VALIDATION_ERROR');
    }
    const opts = await getRegistrationOptions(parsed.data.user_id);
    res.json(opts);
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/v1/passkeys/register/verify
 * Verifies the FIDO2 registration response and stores the public key.
 */
passkeysRouter.post('/register/verify', async (req, res, next) => {
  try {
    const { user_id, response } = req.body as { user_id?: string; response?: unknown };
    if (!user_id || !response) {
      throw new AppError(400, 'user_id and response required', 'VALIDATION_ERROR');
    }
    await verifyRegistration(user_id, response as Parameters<typeof verifyRegistration>[1]);
    res.json({ registered: true });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/v1/passkeys/authenticate/options
 * Returns FIDO2 authentication options (challenge) for assertion.
 * Optional: pass credential_id to restrict to a specific key.
 */
passkeysRouter.post('/authenticate/options', async (req, res, next) => {
  try {
    const { credential_id } = req.body as { credential_id?: string };
    const opts = await getAuthenticationOptions(credential_id);
    res.json(opts);
  } catch (err) {
    next(err);
  }
});

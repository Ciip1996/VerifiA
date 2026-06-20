import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../services/db.js';
import { AppError } from '../middleware/error-handler.js';
import { requireAccount } from '../middleware/account-auth.js';

export const devicesRouter = Router();

const RegisterSchema = z.object({
  token: z.string().min(1).max(512),
  platform: z.enum(['ios', 'android', 'web']),
});

/**
 * POST /api/v1/devices/register
 * Upserts a OneSignal subscription ID for the authenticated account's device.
 * Called by the mobile app after notification permission is granted.
 */
devicesRouter.post('/register', requireAccount, async (req, res, next) => {
  try {
    const parsed = RegisterSchema.safeParse(req.body);
    if (!parsed.success) {
      throw new AppError(400, 'Invalid request body', 'VALIDATION_ERROR');
    }

    const { token, platform } = parsed.data;

    await prisma.deviceToken.upsert({
      where: { token },
      update: { account_id: req.account!.id, platform },
      create: { token, platform, account_id: req.account!.id },
    });

    res.status(204).end();
  } catch (err) {
    next(err);
  }
});

/**
 * DELETE /api/v1/devices/unregister
 * Removes a device token on logout so the device stops receiving pushes.
 */
devicesRouter.delete('/unregister', requireAccount, async (req, res, next) => {
  try {
    const parsed = z.object({ token: z.string().min(1) }).safeParse(req.body);
    if (!parsed.success) {
      throw new AppError(400, 'Invalid request body', 'VALIDATION_ERROR');
    }

    await prisma.deviceToken.deleteMany({
      where: { token: parsed.data.token, account_id: req.account!.id },
    });

    res.status(204).end();
  } catch (err) {
    next(err);
  }
});

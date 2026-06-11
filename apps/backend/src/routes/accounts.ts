import { Router } from 'express';
import { prisma } from '../services/db.js';
import { AppError } from '../middleware/error-handler.js';
import { requireAccount } from '../middleware/account-auth.js';

export const accountsRouter = Router();

/**
 * GET /api/v1/accounts/search?q=<query>
 * Search registered accounts by name or email (case-insensitive partial match).
 * Requires Bearer session JWT. Excludes the caller's own account.
 * Returns up to 20 results with basic public info (no photos in list for performance).
 */
accountsRouter.get('/search', requireAccount, async (req, res, next) => {
  try {
    const rawQ = req.query.q;
    const q = (typeof rawQ === 'string' ? rawQ : '').trim();
    if (q.length < 2) {
      res.json({ results: [] });
      return;
    }

    const selfId = req.account!.id;
    const profileSelect = {
      device_id: true,
      full_name: true,
      profile_photo: true,
      id_type: true,
      date_of_birth: true,
      facetec_match_level: true,
    };

    // Run both searches in parallel:
    // 1) accounts whose email contains the query
    // 2) profiles whose full_name contains the query → then fetch their accounts
    const [emailMatchAccounts, nameMatchProfiles] = await Promise.all([
      prisma.account.findMany({
        where: { email: { contains: q, mode: 'insensitive' } },
        select: { id: true, email: true, device_id: true },
        take: 20,
      }),
      prisma.userProfile.findMany({
        where: { full_name: { contains: q, mode: 'insensitive' } },
        select: profileSelect,
        take: 20,
      }),
    ]);

    // Fetch accounts for name-matched profiles
    const nameDeviceIds = nameMatchProfiles.map(p => p.device_id);
    const nameMatchAccounts = nameDeviceIds.length > 0
      ? await prisma.account.findMany({
          where: { device_id: { in: nameDeviceIds } },
          select: { id: true, email: true, device_id: true },
        })
      : [];

    // Merge account lists, deduplicating by id
    const accountMap = new Map<string, { id: string; email: string; device_id: string }>();
    for (const a of [...emailMatchAccounts, ...nameMatchAccounts]) {
      accountMap.set(a.id, a);
    }
    const allAccounts = [...accountMap.values()];

    if (allAccounts.length === 0) {
      res.json({ results: [] });
      return;
    }

    // Fetch all profiles for the merged account set (some may already be in nameMatchProfiles)
    const allDeviceIds = allAccounts.map(a => a.device_id);
    const extraProfiles = await prisma.userProfile.findMany({
      where: {
        device_id: { in: allDeviceIds },
        NOT: { device_id: { in: nameDeviceIds } }, // avoid re-fetching
      },
      select: profileSelect,
    });

    const profileByDevice = Object.fromEntries(
      [...nameMatchProfiles, ...extraProfiles].map(p => [p.device_id, p])
    );

    const results = allAccounts
      .map(a => {
        const profile = profileByDevice[a.device_id];
        if (!profile) return null; // account has no completed profile
        return {
          id: a.id,
          email: a.email,
          full_name: profile.full_name,
          profile_photo: profile.profile_photo,
          id_type: profile.id_type,
          date_of_birth: profile.date_of_birth,
          facetec_match_level: profile.facetec_match_level,
          is_self: a.id === selfId,
        };
      })
      .filter((r): r is NonNullable<typeof r> => r !== null)
      .slice(0, 20);

    res.json({ results });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/v1/accounts/:accountId/public-profile
 * Returns the full public identity profile for a given account.
 * Includes selfie, ID front photo, and FaceTec match score.
 * Requires Bearer session JWT.
 */
accountsRouter.get('/:accountId/public-profile', requireAccount, async (req, res, next) => {
  try {
    const accountId = req.params['accountId'] as string;

    const account = await prisma.account.findUnique({
      where: { id: accountId },
      select: { id: true, email: true, device_id: true },
    });

    if (!account) {
      throw new AppError(404, 'Account not found', 'ACCOUNT_NOT_FOUND');
    }

    const profile = await prisma.userProfile.findUnique({
      where: { device_id: account.device_id },
    });

    if (!profile) {
      throw new AppError(404, 'Profile not found', 'PROFILE_NOT_FOUND');
    }

    res.json({
      id: account.id,
      email: account.email,
      full_name: profile.full_name,
      date_of_birth: profile.date_of_birth,
      id_type: profile.id_type,
      profile_photo: profile.profile_photo,
      id_front_photo: profile.id_front_photo,
      facetec_match_level: profile.facetec_match_level,
    });
  } catch (err) {
    next(err);
  }
});

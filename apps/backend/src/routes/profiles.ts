import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../services/db.js';
import { AppError } from '../middleware/error-handler.js';

export const profilesRouter = Router();

const RegisterProfileSchema = z.object({
  device_id: z.string().min(1),
  full_name: z.string().min(1),
  curp: z.string().optional(),
  date_of_birth: z.string().optional(),
  id_type: z.enum(['INE', 'PASSPORT']),
  profile_photo: z.string().min(1),     // base64 JPEG selfie
  id_front_photo: z.string().min(1),    // base64 JPEG
  id_back_photo: z.string().optional(), // base64 JPEG (INE reverse)
  facetec_match_level: z.number().int().min(0).max(100).optional(),
  enrollment_ref_id: z.string().optional(),
});

/**
 * POST /api/v1/profile/register
 * Creates or updates a user identity profile linked to a device_id.
 * Called after FaceTec Photo ID Match during onboarding.
 */
profilesRouter.post('/register', async (req, res, next) => {
  try {
    const parsed = RegisterProfileSchema.safeParse(req.body);
    if (!parsed.success) {
      throw new AppError(400, 'Invalid request body', 'VALIDATION_ERROR');
    }

    const {
      device_id, full_name, curp, date_of_birth,
      id_type, profile_photo, id_front_photo, id_back_photo,
      facetec_match_level, enrollment_ref_id,
    } = parsed.data;

    const profile = await prisma.userProfile.upsert({
      where: { device_id },
      create: {
        device_id,
        full_name,
        curp: curp ?? null,
        date_of_birth: date_of_birth ?? null,
        id_type,
        profile_photo,
        id_front_photo,
        id_back_photo: id_back_photo ?? null,
        facetec_match_level: facetec_match_level ?? null,
        enrollment_ref_id: enrollment_ref_id ?? null,
      },
      update: {
        full_name,
        curp: curp ?? null,
        date_of_birth: date_of_birth ?? null,
        id_type,
        profile_photo,
        id_front_photo,
        id_back_photo: id_back_photo ?? null,
        facetec_match_level: facetec_match_level ?? null,
        enrollment_ref_id: enrollment_ref_id ?? null,
      },
    });

    res.status(201).json({
      registered: true,
      profile_id: profile.id,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/v1/profile/:device_id
 * Returns the identity profile for a device. Used internally by token validation.
 */
profilesRouter.get('/:device_id', async (req, res, next) => {
  try {
    const { device_id } = req.params;

    const profile = await prisma.userProfile.findUnique({
      where: { device_id },
    });

    if (!profile) {
      res.json({ found: false, profile: null });
      return;
    }

    res.json({
      found: true,
      profile: {
        full_name: profile.full_name,
        curp: profile.curp,
        date_of_birth: profile.date_of_birth,
        id_type: profile.id_type,
        facetec_match_level: profile.facetec_match_level,
        created_at: profile.created_at.toISOString(),
      },
    });
  } catch (err) {
    next(err);
  }
});

import { Router } from 'express';
import { z } from 'zod';
import { Resend } from 'resend';
import { prisma } from '../services/db.js';
import { generateNonce } from '../utils/crypto.js';
import { AppError } from '../middleware/error-handler.js';
import { requireAccount, optionalAccount } from '../middleware/account-auth.js';

// Instantiated lazily inside the route so a missing key only errors on use, not startup.
function getResend() {
  const key = process.env.RESEND_API_KEY;
  if (!key) throw new Error('RESEND_API_KEY is not set');
  return new Resend(key);
}

export const challengesRouter = Router();

const CreateChallengeSchema = z.object({
  verifier_id: z.string().min(1).max(128),
  target_email: z.string().email().optional(),
});

/**
 * POST /api/v1/challenges
 * Creates a new challenge nonce for a verifier session.
 * Supports both API-key (legacy) and Bearer JWT (account) auth modes.
 * Optional target_email for targeted verification invites.
 */
challengesRouter.post('/', optionalAccount, async (req, res, next) => {
  try {
    const parsed = CreateChallengeSchema.safeParse(req.body);
    if (!parsed.success) {
      throw new AppError(400, 'Invalid request body', 'VALIDATION_ERROR');
    }

    const { verifier_id, target_email } = parsed.data;
    const nonce = generateNonce();
    const ttlSeconds = parseInt(process.env.CHALLENGE_TTL_SECONDS ?? '600', 10);
    const expTime = new Date(Date.now() + ttlSeconds * 1000);

    const challenge = await prisma.challenge.create({
      data: {
        nonce,
        verifier_id,
        exp_time: expTime,
        status: 'PENDING',
        account_id: req.account?.id ?? null,
        target_email: target_email ?? null,
      },
    });

    const deepLink = `verifia://badge?nonce=${nonce}&verifier=${encodeURIComponent(verifier_id)}`;
    const qrData = deepLink;

    res.status(201).json({
      nonce: challenge.nonce,
      verifier_id,
      expires_in: ttlSeconds,
      qr_data: qrData,
      deep_link: deepLink,
      expires_at: expTime.toISOString(),
    });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/v1/challenges/history
 * Returns all challenges created by the authenticated account, newest first.
 * Includes linked token summary if one was issued.
 */
challengesRouter.get('/history', requireAccount, async (req, res, next) => {
  try {
    const page = parseInt(req.query.page as string ?? '1', 10);
    const limit = Math.min(parseInt(req.query.limit as string ?? '20', 10), 50);
    const skip = (page - 1) * limit;

    const challenges = await prisma.challenge.findMany({
      where: { account_id: req.account!.id },
      orderBy: { created_at: 'desc' },
      skip,
      take: limit,
    });

    // Fetch linked tokens for each challenge
    const nonces = challenges.map(c => c.nonce);
    const tokens = nonces.length > 0
      ? await prisma.token.findMany({
          where: { nonce: { in: nonces } },
          select: {
            nonce: true,
            status: true,
            liveness_match_score: true,
            liveness_snapshot: true,
            created_at: true,
            device_id: true,
          },
        })
      : [];

    const tokenByNonce = Object.fromEntries(tokens.map(t => [t.nonce, t]));

    // Fetch user profiles for tokens with device_id
    const deviceIds = tokens
      .map(t => t.device_id)
      .filter((id): id is string => id !== null);
    const profiles = deviceIds.length > 0
      ? await prisma.userProfile.findMany({
          where: { device_id: { in: deviceIds } },
          select: { device_id: true, full_name: true, profile_photo: true, id_type: true, id_front_photo: true },
        })
      : [];
    const profileByDevice = Object.fromEntries(profiles.map(p => [p.device_id, p]));

    const items = challenges.map(c => {
      const token = tokenByNonce[c.nonce];
      const profile = token?.device_id ? profileByDevice[token.device_id] : null;
      return {
        nonce: c.nonce,
        status: c.status,
        target_email: c.target_email,
        rejection_reason: c.rejection_reason,
        created_at: c.created_at.toISOString(),
        expires_at: c.exp_time.toISOString(),
        token: token
          ? {
              status: token.status,
              liveness_match_score: token.liveness_match_score,
              liveness_snapshot: token.liveness_snapshot,
              validated_at: token.created_at.toISOString(),
            }
          : null,
        subject: profile
          ? {
              full_name: profile.full_name,
              profile_photo: profile.profile_photo,
              id_type: profile.id_type,
              id_front_photo: profile.id_front_photo,
            }
          : null,
      };
    });

    res.json({ items, page, limit });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/v1/challenges/send-invite
 * Sends an invitation email to a non-registered address via Resend.
 * Includes download instructions and the challenge deep link.
 */
const SendInviteSchema = z.object({
  nonce: z.string().min(1),
  email: z.string().email(),
});

challengesRouter.post('/send-invite', requireAccount, async (req, res, next) => {
  try {
    const parsed = SendInviteSchema.safeParse(req.body);
    if (!parsed.success) {
      throw new AppError(400, 'Invalid request body', 'VALIDATION_ERROR');
    }

    const { nonce, email } = parsed.data;

    const challenge = await prisma.challenge.findUnique({
      where: { nonce },
      select: { nonce: true, verifier_id: true, exp_time: true, account_id: true },
    });

    if (!challenge) {
      throw new AppError(404, 'Challenge not found', 'CHALLENGE_NOT_FOUND');
    }

    // Only the owner can send the invite
    if (challenge.account_id !== req.account!.id) {
      throw new AppError(403, 'Forbidden', 'FORBIDDEN');
    }

    const deepLink = `verifia://badge?nonce=${nonce}&verifier=${encodeURIComponent(challenge.verifier_id)}`;
    const expStr = challenge.exp_time.toLocaleString('es-MX', {
      day: 'numeric', month: 'long', year: 'numeric',
      hour: '2-digit', minute: '2-digit', timeZone: 'America/Mexico_City',
    });
    const senderName = req.account!.email;

    const html = `<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f5f5f5;font-family:system-ui,sans-serif">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f5f5f5;padding:32px 0">
    <tr><td align="center">
      <table width="540" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,.08)">
        <!-- Header -->
        <tr><td style="background:#1a1a2e;padding:28px 40px;text-align:center">
          <span style="font-size:28px;font-weight:700;color:#fff">🛡️ VerifiA</span>
        </td></tr>
        <!-- Body -->
        <tr><td style="padding:36px 40px 24px">
          <h2 style="margin:0 0 12px;font-size:20px;color:#111">Te invitaron a verificar tu identidad</h2>
          <p style="margin:0 0 20px;color:#444;line-height:1.6">
            <strong>${senderName}</strong> te ha enviado una solicitud de verificación de identidad
            a través de <strong>VerifiA</strong>, una plataforma segura de verificación criptográfica efímera.
          </p>
          <hr style="border:none;border-top:1px solid #eee;margin:24px 0">

          <h3 style="margin:0 0 12px;font-size:15px;color:#111">Cómo verificar:</h3>
          <ol style="margin:0 0 24px;padding-left:20px;color:#444;line-height:2">
            <li>Descarga la app <strong>VerifiA</strong> en el App Store <em>(próximamente disponible)</em></li>
            <li>Crea tu cuenta y completa el registro con tu INE</li>
            <li>Abre el enlace directo o escanea el QR compartido</li>
          </ol>

          <!-- CTA deep link -->
          <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px">
            <tr><td align="center">
              <a href="${deepLink}"
                 style="display:inline-block;background:#6c63ff;color:#fff;text-decoration:none;padding:14px 32px;border-radius:10px;font-weight:600;font-size:15px">
                Abrir solicitud de verificación →
              </a>
            </td></tr>
          </table>

          <p style="margin:0 0 8px;font-size:12px;color:#888;text-align:center">
            O copia este enlace manualmente:<br>
            <code style="font-size:11px;color:#555">${deepLink}</code>
          </p>

          <hr style="border:none;border-top:1px solid #eee;margin:24px 0">
          <p style="margin:0;font-size:12px;color:#aaa;text-align:center">
            ⏱ Este QR expira el ${expStr}.<br>
            Si no esperabas este mensaje puedes ignorarlo.
          </p>
        </td></tr>
        <!-- Footer -->
        <tr><td style="background:#f9f9f9;padding:16px 40px;text-align:center">
          <p style="margin:0;font-size:11px;color:#bbb">
            VerifiA — verificación de identidad criptográfica efímera · ITESM
          </p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;

    await getResend().emails.send({
      from: 'VerifiA <onboarding@resend.dev>',
      to: [email],
      subject: `${senderName} te pide verificar tu identidad en VerifiA`,
      html,
    });

    res.status(204).end();
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/v1/challenges/incoming
 * Returns PENDING challenges targeted at the authenticated account's email.
 * Used by the mobile app to display pending verification requests.
 */
challengesRouter.get('/incoming', requireAccount, async (req, res, next) => {
  try {
    const now = new Date();
    const challenges = await prisma.challenge.findMany({
      where: {
        target_email: req.account!.email,
        status: 'PENDING',
        exp_time: { gt: now },
      },
      orderBy: { created_at: 'desc' },
    });

    // Get requester info for each challenge
    const accountIds = challenges
      .map(c => c.account_id)
      .filter((id): id is string => id !== null);

    const requesters = accountIds.length > 0
      ? await prisma.account.findMany({
          where: { id: { in: accountIds } },
          select: { id: true, email: true, device_id: true },
        })
      : [];

    const requesterProfiles = requesters.length > 0
      ? await prisma.userProfile.findMany({
          where: { device_id: { in: requesters.map(r => r.device_id) } },
          select: { device_id: true, full_name: true, profile_photo: true },
        })
      : [];

    const profileByDevice = Object.fromEntries(requesterProfiles.map(p => [p.device_id, p]));
    const requesterById = Object.fromEntries(requesters.map(r => [r.id, r]));

    const items = challenges.map(c => {
      const requester = c.account_id ? requesterById[c.account_id] : null;
      const profile = requester ? profileByDevice[requester.device_id] : null;
      return {
        nonce: c.nonce,
        verifier_id: c.verifier_id,
        created_at: c.created_at.toISOString(),
        expires_at: c.exp_time.toISOString(),
        requester: requester
          ? {
              email: requester.email,
              full_name: profile?.full_name ?? null,
              profile_photo: profile?.profile_photo ?? null,
            }
          : null,
      };
    });

    res.json({ items });
  } catch (err) {
    next(err);
  }
});

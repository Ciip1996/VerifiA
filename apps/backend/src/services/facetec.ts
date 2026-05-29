import { AppError } from '../middleware/error-handler.js';

interface FaceTecVerifyInput {
  session_id: string;
  nonce: string;
  face_scan?: string;           // base64 encrypted FaceScan blob from SDK
  audit_trail_image?: string;   // base64 from SDK (optional but improves score)
}

interface FaceTecApiResponse {
  success: boolean;
  livenessStatus?: string;      // "LIVENESS_DETERMINED" on success
  sessionId?: string;
  error?: string;
}

const FACETEC_BASE_URL = process.env.FACETEC_BASE_URL ?? '';
const FACETEC_DEVICE_KEY = process.env.FACETEC_DEVICE_KEY_IDENTIFIER ?? '';
const FACETEC_PUBLIC_FHD_KEY = process.env.FACETEC_PUBLIC_FHD_KEY ?? '';

/**
 * Verify a FaceTec liveness session via FaceTec Managed Testing API.
 *
 * When FACETEC_DEVICE_KEY is "dev" or not configured, verification is bypassed
 * (dev / simulator mode). In production the SDK sends an encrypted FaceScan
 * to this backend which forwards it to FaceTec's servers.
 *
 * FaceTec Managed Testing API: POST /liveness-3d
 * Headers: X-Device-Key, X-Public-FaceScan-Encryption-Key, Content-Type
 * Body: { faceScan, sessionId, auditTrailImage?, lowQualityAuditTrailImage? }
 * Success: { success: true, livenessStatus: "LIVENESS_DETERMINED", sessionId }
 */
export async function verifyFaceTecSession(input: FaceTecVerifyInput): Promise<void> {
  const { session_id, face_scan, audit_trail_image } = input;

  if (!session_id) {
    throw new AppError(400, 'Missing FaceTec session ID', 'FACETEC_SESSION_MISSING');
  }

  // Dev / simulator bypass — no FaceTec credentials configured
  const isDev = !FACETEC_BASE_URL || FACETEC_DEVICE_KEY === 'dev' || !FACETEC_DEVICE_KEY;
  if (isDev) {
    console.warn('[FaceTec] Dev mode — skipping liveness verification');
    return;
  }

  if (!face_scan) {
    throw new AppError(400, 'Missing FaceScan blob — SDK must supply face_scan', 'FACETEC_SCAN_MISSING');
  }

  let data: FaceTecApiResponse;
  try {
    const resp = await fetch(`${FACETEC_BASE_URL}/liveness-3d`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Device-Key': FACETEC_DEVICE_KEY,
        'X-Public-FaceScan-Encryption-Key': FACETEC_PUBLIC_FHD_KEY,
      },
      body: JSON.stringify({
        faceScan: face_scan,
        sessionId: session_id,
        ...(audit_trail_image ? { auditTrailImage: audit_trail_image } : {}),
      }),
    });

    data = (await resp.json()) as FaceTecApiResponse;

    if (!resp.ok) {
      console.error('[FaceTec] API error:', data);
      throw new AppError(502, 'FaceTec API error', 'FACETEC_API_ERROR');
    }
  } catch (err) {
    if (err instanceof AppError) throw err;
    throw new AppError(502, 'FaceTec request failed', 'FACETEC_REQUEST_FAILED');
  }

  if (!data.success || data.livenessStatus !== 'LIVENESS_DETERMINED') {
    throw new AppError(401, `Liveness check failed: ${data.livenessStatus ?? 'unknown'}`, 'LIVENESS_FAILED');
  }

  if (data.sessionId && data.sessionId !== session_id) {
    throw new AppError(401, 'FaceTec session ID mismatch', 'FACETEC_SESSION_MISMATCH');
  }
}

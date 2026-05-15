import { AppError } from '../middleware/error-handler.js';

interface FaceTecVerifyInput {
  session_id: string;
  nonce: string;
}

/**
 * Verify a FaceTec liveness session via FaceTec Managed Testing API.
 *
 * FaceTec Developer Account (free) provides access to the Managed Testing API
 * at https://api.facetec.com/api/v3.1/biometric-console
 *
 * The app SDK sends the encrypted FaceScan (3D mathematical representation)
 * to FaceTec's servers. We verify server-side that the session passed liveness.
 *
 * API endpoint: POST /liveness-3d
 * Required headers: X-Device-Key, X-User-Agent
 * Body: { faceScan, auditTrailImage, lowQualityAuditTrailImage, sessionId }
 *
 * Success response includes: { success: true, livenessStatus: "LIVENESS_DETERMINED" }
 *
 * TODO (Semana 2): Implement full FaceTec server-side verification call.
 * Reference: https://dev.facetec.com/server-side-api-guide
 */
export async function verifyFaceTecSession(input: FaceTecVerifyInput): Promise<void> {
  const { session_id } = input;

  if (!session_id) {
    throw new AppError(400, 'Missing FaceTec session ID', 'FACETEC_SESSION_MISSING');
  }

  const baseUrl = process.env.FACETEC_BASE_URL;
  const deviceKey = process.env.FACETEC_DEVICE_KEY_IDENTIFIER;

  if (!baseUrl || !deviceKey) {
    // In dev without FaceTec credentials, skip verification
    console.warn('[FaceTec] Credentials not configured — skipping verification (dev mode)');
    return;
  }

  // TODO (Semana 2): Implement actual API call to FaceTec Managed Testing API
  // The full implementation should:
  // 1. POST to {FACETEC_BASE_URL}/liveness-3d with session data
  // 2. Verify response.success === true
  // 3. Verify response.livenessStatus === 'LIVENESS_DETERMINED'
  // 4. Verify response.sessionId matches our session_id
  console.warn('[FaceTec] Server-side verification not yet implemented — Semana 2 task');
}

import { AppError } from '../middleware/error-handler.js';

interface PasskeyAssertion {
  id: string;
  raw_id: string;
  authenticator_data: string; // base64url
  client_data_json: string;   // base64url
  signature: string;          // base64url
  user_handle?: string;
}

interface PasskeyVerifyResult {
  userId: string;
  credentialId: string;
}

/**
 * Verify a WebAuthn/Passkey assertion (FIDO2).
 *
 * iOS implementation uses AuthenticationServices framework.
 * The client_data_json must contain our challenge (nonce) as the `challenge` field.
 *
 * Verification steps:
 * 1. Decode and parse client_data_json (base64url → JSON)
 * 2. Verify type === "webauthn.get"
 * 3. Verify challenge in client_data_json matches our nonce (base64url encoded)
 * 4. Verify origin matches our relying party domain
 * 5. Decode authenticator_data
 * 6. Verify RP ID hash (SHA256 of relying party domain)
 * 7. Verify UP (user present) flag is set
 * 8. Verify UV (user verified / Face ID) flag is set
 * 9. Verify ECDSA P-256 signature over (authenticatorData || SHA256(clientDataJSON))
 *    using the stored credential public key
 * 10. Verify sign count > stored count (replay protection)
 *
 * TODO (Semana 3): Implement full FIDO2 verification.
 * Consider using @simplewebauthn/server for standards-compliant implementation.
 */
export async function verifyPasskeyAssertion(input: {
  assertion: PasskeyAssertion;
  challenge: string;
}): Promise<PasskeyVerifyResult> {
  const { assertion, challenge } = input;

  if (!assertion.authenticator_data || !assertion.client_data_json || !assertion.signature) {
    throw new AppError(400, 'Incomplete passkey assertion', 'PASSKEY_INCOMPLETE');
  }

  // Decode client_data_json and verify challenge
  try {
    const clientDataStr = Buffer.from(assertion.client_data_json, 'base64url').toString('utf8');
    const clientData = JSON.parse(clientDataStr) as { type: string; challenge: string; origin: string };

    if (clientData.type !== 'webauthn.get') {
      throw new AppError(401, 'Invalid passkey assertion type', 'PASSKEY_INVALID_TYPE');
    }

    // Verify nonce is embedded in the challenge
    const expectedChallenge = Buffer.from(challenge).toString('base64url');
    if (clientData.challenge !== expectedChallenge) {
      throw new AppError(401, 'Passkey challenge mismatch', 'PASSKEY_CHALLENGE_MISMATCH');
    }
  } catch (err) {
    if (err instanceof AppError) throw err;
    throw new AppError(401, 'Failed to parse passkey assertion', 'PASSKEY_PARSE_ERROR');
  }

  // TODO (Semana 3): Full signature verification with stored public key
  console.warn('[Passkeys] Full FIDO2 assertion verification not yet implemented — Semana 3 task');

  return {
    userId: assertion.user_handle ?? assertion.id,
    credentialId: assertion.id,
  };
}

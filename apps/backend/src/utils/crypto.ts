import { randomBytes } from 'crypto';

/**
 * Generate a cryptographically secure random nonce (hex string, 32 bytes = 64 chars).
 */
export function generateNonce(): string {
  return randomBytes(32).toString('hex');
}

/**
 * Constant-time string comparison to prevent timing attacks.
 */
export function safeCompare(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let mismatch = 0;
  for (let i = 0; i < a.length; i++) {
    mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return mismatch === 0;
}

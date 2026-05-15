import { SignJWT, importPKCS8, importSPKI, jwtVerify } from 'jose';
import { randomUUID } from 'crypto';

const TTL = parseInt(process.env.TOKEN_TTL_SECONDS ?? '300', 10);
const ISSUER = process.env.JWT_ISSUER ?? 'https://api.verifia.dev';

/**
 * Issue an ES256 JWT badge token.
 */
export async function issueToken(payload: {
  sub: string;
  aud: string;
  nonce: string;
  device_id: string;
}): Promise<{ jwt: string; jti: string; exp: Date }> {
  const privateKeyPem = process.env.JWT_PRIVATE_KEY_PEM;
  if (!privateKeyPem) throw new Error('JWT_PRIVATE_KEY_PEM not set');

  const privateKey = await importPKCS8(privateKeyPem, 'ES256');
  const jti = randomUUID();
  const now = Math.floor(Date.now() / 1000);
  const expTs = now + TTL;

  const jwt = await new SignJWT({
    nonce: payload.nonce,
    device_id: payload.device_id,
  })
    .setProtectedHeader({ alg: 'ES256' })
    .setIssuedAt(now)
    .setIssuer(ISSUER)
    .setSubject(payload.sub)
    .setAudience(payload.aud)
    .setExpirationTime(expTs)
    .setJti(jti)
    .sign(privateKey);

  return { jwt, jti, exp: new Date(expTs * 1000) };
}

/**
 * Verify an ES256 JWT badge token.
 */
export async function verifyToken(
  token: string,
  audience: string
): Promise<{ jti: string; nonce: string; sub: string; exp: number }> {
  const publicKeyPem = process.env.JWT_PUBLIC_KEY_PEM;
  if (!publicKeyPem) throw new Error('JWT_PUBLIC_KEY_PEM not set');

  const publicKey = await importSPKI(publicKeyPem, 'ES256');
  const { payload } = await jwtVerify(token, publicKey, {
    issuer: ISSUER,
    audience,
    algorithms: ['ES256'],
  });

  return {
    jti: payload.jti as string,
    nonce: payload['nonce'] as string,
    sub: payload.sub as string,
    exp: payload.exp as number,
  };
}

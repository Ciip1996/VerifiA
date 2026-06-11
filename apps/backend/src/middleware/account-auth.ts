import { Request, Response, NextFunction } from 'express';
import { importSPKI, jwtVerify } from 'jose';
import { AppError } from './error-handler.js';

const ACCOUNT_ISSUER = 'verifia-account';

function loadPem(value: string | undefined, name: string): string {
  if (!value) throw new Error(`${name} not set`);
  return value.replace(/\\n/g, '\n');
}

export interface AccountPayload {
  id: string;
  email: string;
}

// Extend Express Request to carry account info
declare global {
  namespace Express {
    interface Request {
      account?: AccountPayload;
    }
  }
}

/**
 * Middleware that verifies a Bearer account session JWT.
 * Attaches `req.account = { id, email }` on success.
 * Throws 401 if token is missing or invalid.
 */
export async function requireAccount(
  req: Request,
  _res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      throw new AppError(401, 'Missing or invalid Authorization header', 'UNAUTHORIZED');
    }
    const token = authHeader.slice(7);
    const publicKey = await importSPKI(
      loadPem(process.env.JWT_PUBLIC_KEY_PEM, 'JWT_PUBLIC_KEY_PEM'),
      'ES256'
    );
    const { payload } = await jwtVerify(token, publicKey, {
      issuer: ACCOUNT_ISSUER,
      algorithms: ['ES256'],
    });
    req.account = {
      id: payload.sub as string,
      email: payload['email'] as string,
    };
    next();
  } catch (err) {
    if (err instanceof AppError) {
      next(err);
    } else {
      next(new AppError(401, 'Invalid or expired session token', 'UNAUTHORIZED'));
    }
  }
}

/**
 * Optional version — attaches account if Bearer token is present but does
 * not reject the request if missing (for routes that support both auth modes).
 */
export async function optionalAccount(
  req: Request,
  _res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return next();
    }
    const token = authHeader.slice(7);
    const publicKey = await importSPKI(
      loadPem(process.env.JWT_PUBLIC_KEY_PEM, 'JWT_PUBLIC_KEY_PEM'),
      'ES256'
    );
    const { payload } = await jwtVerify(token, publicKey, {
      issuer: ACCOUNT_ISSUER,
      algorithms: ['ES256'],
    });
    req.account = {
      id: payload.sub as string,
      email: payload['email'] as string,
    };
  } catch {
    // Ignore invalid token in optional mode
  }
  next();
}

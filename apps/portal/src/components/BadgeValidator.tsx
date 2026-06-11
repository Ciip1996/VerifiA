import { useEffect, useRef, useState } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import {
  getTokenStatus,
  validateToken,
  type BadgeInfo,
  type UserIdentity,
  type ChallengeResponse,
} from '../api/client.ts';

interface Props {
  challenge: ChallengeResponse;
  onValidated: (badge: BadgeInfo, identity?: UserIdentity | null) => void;
  onExpiredOrInvalid: (reason: string, rejectionReason?: string) => void;
}

const POLL_INTERVAL = parseInt(import.meta.env.VITE_POLL_INTERVAL_MS ?? '2000', 10);

export function BadgeValidator({ challenge, onValidated, onExpiredOrInvalid }: Props) {
  const [timeLeft, setTimeLeft] = useState<number>(challenge.expires_in);
  const [status, setStatus] = useState<'waiting' | 'scanning' | 'validating'>('waiting');
  const [copied, setCopied] = useState(false);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const consumedRef = useRef(false);

  function handleCopyLink() {
    navigator.clipboard.writeText(challenge.qr_data).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  }

  // Countdown
  useEffect(() => {
    const expAt = new Date(challenge.expires_at).getTime();
    timerRef.current = setInterval(() => {
      const remaining = Math.max(0, Math.floor((expAt - Date.now()) / 1000));
      setTimeLeft(remaining);
      if (remaining <= 0) {
        clearInterval(timerRef.current!);
        if (!consumedRef.current) onExpiredOrInvalid('El QR expiró antes de ser escaneado.');
      }
    }, 500);
    return () => clearInterval(timerRef.current!);
  }, [challenge.expires_at, onExpiredOrInvalid]);

  // Polling
  useEffect(() => {
    pollRef.current = setInterval(async () => {
      if (consumedRef.current) return;
      try {
        const res = await getTokenStatus(challenge.nonce);

        if (res.valid && res.status === 'ACTIVE') {
          setStatus('validating');
          clearInterval(pollRef.current!);
          const validate = await validateToken(challenge.nonce);
          consumedRef.current = true;
          if (validate.valid && validate.badge) {
            onValidated(validate.badge, validate.identity);
          } else {
            onExpiredOrInvalid('Validación fallida: ' + validate.message);
          }
        } else if (res.status === 'REJECTED') {
          clearInterval(pollRef.current!);
          consumedRef.current = true;
          onExpiredOrInvalid('Verificación rechazada por FaceTec.', res.rejection_reason ?? 'Score de coincidencia facial demasiado bajo.');
        } else if (res.status === 'EXPIRED') {
          clearInterval(pollRef.current!);
          if (!consumedRef.current) onExpiredOrInvalid('Token expirado.');
        } else if (res.status === 'USED') {
          clearInterval(pollRef.current!);
          onExpiredOrInvalid('Token ya fue utilizado (posible replay).');
        }
        // NOT_FOUND: no token yet — stay in waiting state, keep polling
      } catch {
        // Network hiccup — keep polling
      }
    }, POLL_INTERVAL);

    return () => clearInterval(pollRef.current!);
  }, [challenge.nonce, onValidated, onExpiredOrInvalid, status]);

  const minutes = Math.floor(timeLeft / 60);
  const seconds = timeLeft % 60;
  const pct = timeLeft / challenge.expires_in;
  const timerColor = pct < 0.2 ? '#ef4444' : pct < 0.4 ? '#f59e0b' : 'var(--color-text)';

  const statusLabel = {
    waiting: 'Esperando escaneo del QR...',
    scanning: 'Verificación en curso...',
    validating: 'Badge recibido — validando...',
  }[status];

  const statusDotColor = {
    waiting: 'var(--color-accent)',
    scanning: '#f59e0b',
    validating: '#22c55e',
  }[status];

  return (
    <div style={{ textAlign: 'center' }}>
      {/* Verifier badge */}
      <div
        style={{
          display: 'inline-flex',
          alignItems: 'center',
          gap: '0.4rem',
          background: 'rgba(108,99,255,0.1)',
          border: '1px solid rgba(108,99,255,0.3)',
          borderRadius: 20,
          padding: '0.3rem 0.8rem',
          marginBottom: '1.25rem',
          fontSize: '0.8rem',
          color: '#a8a4ff',
        }}
      >
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
          <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
        </svg>
        Verificando para: <strong style={{ color: '#c4c1ff' }}>{challenge.verifier_id}</strong>
      </div>

      {/* QR Code */}
      <div
        style={{
          background: '#fff',
          padding: '1rem',
          borderRadius: 'var(--radius)',
          display: 'inline-block',
          marginBottom: '1.5rem',
          position: 'relative',
        }}
      >
        <QRCodeSVG value={challenge.qr_data} size={220} />
        {status !== 'waiting' && (
          <div
            style={{
              position: 'absolute',
              inset: 0,
              background: 'rgba(255,255,255,0.85)',
              borderRadius: 'var(--radius)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              flexDirection: 'column',
              gap: '0.5rem',
            }}
          >
            <div style={{ fontSize: '2.5rem' }}>
              {status === 'validating' ? '✅' : '📱'}
            </div>
            <span style={{ fontSize: '0.8rem', color: '#333', fontWeight: 600 }}>
              {status === 'validating' ? 'Validando...' : 'Escaneado'}
            </span>
          </div>
        )}
      </div>

      {/* Timer */}
      <div
        style={{
          fontSize: '3rem',
          fontWeight: 700,
          fontVariantNumeric: 'tabular-nums',
          color: timerColor,
          marginBottom: '0.5rem',
          transition: 'color 0.3s',
        }}
      >
        {String(minutes).padStart(2, '0')}:{String(seconds).padStart(2, '0')}
      </div>

      {/* Status row */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: '0.5rem',
          color: 'var(--color-muted)',
          fontSize: '0.875rem',
          marginBottom: '0.75rem',
        }}
      >
        <span
          style={{
            width: 8,
            height: 8,
            borderRadius: '50%',
            background: statusDotColor,
            display: 'inline-block',
            animation: 'pulse 1.5s infinite',
          }}
        />
        {statusLabel}
      </div>

      {/* Nonce debug */}
      <div style={{ fontSize: '0.7rem', color: 'var(--color-muted)', fontFamily: 'monospace', marginBottom: '1.25rem' }}>
        nonce: {challenge.nonce.slice(0, 12)}…
      </div>

      {/* Share link */}
      {status === 'waiting' && (
        <div
          style={{
            background: 'rgba(255,255,255,0.04)',
            border: '1px solid rgba(255,255,255,0.1)',
            borderRadius: 10,
            padding: '0.85rem 1rem',
            display: 'flex',
            alignItems: 'center',
            gap: '0.75rem',
          }}
        >
          <div style={{ flex: 1, textAlign: 'left' }}>
            <div style={{ fontSize: '0.7rem', color: 'var(--color-muted)', marginBottom: '0.2rem' }}>
              ¿Sin acceso al QR? Comparte el link:
            </div>
            <div
              style={{
                fontSize: '0.72rem',
                fontFamily: 'monospace',
                color: 'var(--color-text)',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
                opacity: 0.7,
              }}
            >
              {challenge.qr_data.slice(0, 48)}…
            </div>
          </div>
          <button
            onClick={handleCopyLink}
            style={{
              padding: '0.5rem 1rem',
              background: copied ? 'rgba(34,197,94,0.15)' : 'rgba(108,99,255,0.15)',
              border: `1px solid ${copied ? 'rgba(34,197,94,0.4)' : 'rgba(108,99,255,0.4)'}`,
              borderRadius: 8,
              color: copied ? '#22c55e' : '#a8a4ff',
              cursor: 'pointer',
              fontSize: '0.8rem',
              fontWeight: 600,
              flexShrink: 0,
              transition: 'all 0.2s',
              whiteSpace: 'nowrap',
            }}
          >
            {copied ? '✓ Copiado' : '📋 Copiar link'}
          </button>
        </div>
      )}

      <style>{`
        @keyframes pulse {
          0%, 100% { opacity: 1; transform: scale(1); }
          50% { opacity: 0.4; transform: scale(0.85); }
        }
      `}</style>
    </div>
  );
}

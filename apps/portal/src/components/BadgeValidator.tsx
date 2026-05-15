import { useEffect, useRef, useState } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { getTokenStatus, validateToken, type ChallengeResponse } from '../api/client.ts';

interface Props {
  challenge: ChallengeResponse;
  onValidated: () => void;
  onExpiredOrInvalid: (reason: string) => void;
}

const POLL_INTERVAL = parseInt(import.meta.env.VITE_POLL_INTERVAL_MS ?? '2000', 10);

export function BadgeValidator({ challenge, onValidated, onExpiredOrInvalid }: Props) {
  const [timeLeft, setTimeLeft] = useState<number>(challenge.expires_in);
  const [status, setStatus] = useState<string>('Esperando escaneo...');
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const consumedRef = useRef(false);

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
          setStatus('Badge recibido — validando...');
          clearInterval(pollRef.current!);
          // Consume the token
          const validate = await validateToken(challenge.nonce);
          consumedRef.current = true;
          if (validate.valid) {
            onValidated();
          } else {
            onExpiredOrInvalid('Validación fallida: ' + validate.message);
          }
        } else if (res.status === 'EXPIRED') {
          clearInterval(pollRef.current!);
          if (!consumedRef.current) onExpiredOrInvalid('Token expirado.');
        } else if (res.status === 'USED') {
          clearInterval(pollRef.current!);
          onExpiredOrInvalid('Token ya fue utilizado (posible replay).');
        }
      } catch {
        // Network error — keep polling
      }
    }, POLL_INTERVAL);

    return () => clearInterval(pollRef.current!);
  }, [challenge.nonce, onValidated, onExpiredOrInvalid]);

  const minutes = Math.floor(timeLeft / 60);
  const seconds = timeLeft % 60;

  return (
    <div style={{ textAlign: 'center' }}>
      <div
        style={{
          background: '#fff',
          padding: '1rem',
          borderRadius: 'var(--radius)',
          display: 'inline-block',
          marginBottom: '1.5rem',
        }}
      >
        <QRCodeSVG value={challenge.qr_data} size={240} />
      </div>

      <div
        style={{
          fontSize: '3rem',
          fontWeight: 700,
          fontVariantNumeric: 'tabular-nums',
          color: timeLeft < 60 ? 'var(--color-danger)' : 'var(--color-text)',
          marginBottom: '0.5rem',
        }}
      >
        {String(minutes).padStart(2, '0')}:{String(seconds).padStart(2, '0')}
      </div>

      <p style={{ color: 'var(--color-muted)', marginBottom: '1rem' }}>{status}</p>

      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: '0.5rem',
          color: 'var(--color-muted)',
          fontSize: '0.85rem',
        }}
      >
        <span
          style={{
            width: 8,
            height: 8,
            borderRadius: '50%',
            background: 'var(--color-accent)',
            display: 'inline-block',
            animation: 'pulse 1.5s infinite',
          }}
        />
        Verificando en tiempo real
      </div>

      <style>{`
        @keyframes pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.3; }
        }
      `}</style>
    </div>
  );
}

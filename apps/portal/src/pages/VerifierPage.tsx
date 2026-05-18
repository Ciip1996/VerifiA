import { useState, useCallback } from 'react';
import { QRGenerator } from '../components/QRGenerator.tsx';
import { BadgeValidator } from '../components/BadgeValidator.tsx';
import type { BadgeInfo, ChallengeResponse } from '../api/client.ts';

type SessionState =
  | { phase: 'idle' }
  | { phase: 'pending'; challenge: ChallengeResponse }
  | { phase: 'valid'; challenge: ChallengeResponse; badge: BadgeInfo }
  | { phase: 'expired' | 'invalid'; challenge: ChallengeResponse; reason: string };

export function VerifierPage() {
  const [session, setSession] = useState<SessionState>({ phase: 'idle' });

  const handleNewSession = useCallback((challenge: ChallengeResponse) => {
    setSession({ phase: 'pending', challenge });
  }, []);

  const handleValidated = useCallback((badge: BadgeInfo) => {
    setSession((prev) =>
      prev.phase === 'pending' ? { ...prev, phase: 'valid', badge } : prev,
    );
  }, []);

  const handleExpiredOrInvalid = useCallback((reason: string) => {
    setSession((prev) =>
      prev.phase === 'pending' ? { ...prev, phase: 'expired', reason } : prev,
    );
  }, []);

  const handleReset = useCallback(() => setSession({ phase: 'idle' }), []);

  return (
    <main style={{ maxWidth: 600, margin: '0 auto', padding: '2rem 1rem' }}>
      <header style={{ marginBottom: '2rem', textAlign: 'center' }}>
        <h1 style={{ fontSize: '1.8rem', fontWeight: 700, letterSpacing: '-0.02em' }}>
          VerifiA
        </h1>
        <p style={{ color: 'var(--color-muted)', marginTop: '0.5rem' }}>
          Portal de verificación de presencia
        </p>
      </header>

      {session.phase === 'idle' && (
        <QRGenerator onChallengeCreated={handleNewSession} />
      )}

      {session.phase === 'pending' && (
        <BadgeValidator
          challenge={session.challenge}
          onValidated={handleValidated}
          onExpiredOrInvalid={handleExpiredOrInvalid}
        />
      )}

      {session.phase === 'valid' && (
        <ValidResult badge={session.badge} onReset={handleReset} />
      )}

      {(session.phase === 'expired' || session.phase === 'invalid') && (
        <InvalidResult reason={session.reason} onReset={handleReset} />
      )}
    </main>
  );
}

// ── Valid result ─────────────────────────────────────────────────────────────

function ValidResult({ badge, onReset }: { badge: BadgeInfo; onReset: () => void }) {
  const issuedAt = new Date(badge.issued_at);
  const expiresAt = new Date(badge.expires_at);
  const now = Date.now();
  const isExpired = expiresAt.getTime() < now;
  const ttlSeconds = Math.round((expiresAt.getTime() - issuedAt.getTime()) / 1000);

  const fmt = (d: Date) =>
    d.toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit', second: '2-digit' });

  return (
    <div style={{ textAlign: 'center' }}>
      {/* Big checkmark */}
      <div
        style={{
          width: 80,
          height: 80,
          borderRadius: '50%',
          background: 'rgba(34,197,94,0.15)',
          border: '2px solid rgba(34,197,94,0.5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          margin: '0 auto 1.25rem',
          fontSize: '2.5rem',
        }}
      >
        ✅
      </div>

      <h2 style={{ marginBottom: '0.25rem', color: '#22c55e' }}>Presencia verificada</h2>
      <p style={{ color: 'var(--color-muted)', marginBottom: '1.5rem', fontSize: '0.9rem' }}>
        El badge es criptográficamente válido
      </p>

      {/* Badge details card */}
      <div
        style={{
          background: 'rgba(255,255,255,0.04)',
          border: '1px solid rgba(255,255,255,0.1)',
          borderRadius: 12,
          padding: '1rem 1.25rem',
          marginBottom: '1.5rem',
          textAlign: 'left',
        }}
      >
        <div style={{ fontSize: '0.7rem', color: 'var(--color-muted)', letterSpacing: 1, marginBottom: '0.75rem', fontWeight: 600 }}>
          DETALLES DEL BADGE
        </div>
        <BadgeRow label="Badge ID" value={`${badge.jti.slice(0, 18)}…`} mono />
        <BadgeRow label="Verificador" value={badge.verifier} mono />
        <BadgeRow label="Emitido" value={fmt(issuedAt)} />
        <BadgeRow
          label="Expira"
          value={`${fmt(expiresAt)} (TTL ${ttlSeconds}s)`}
          valueStyle={{ color: isExpired ? '#ef4444' : '#22c55e' }}
        />
      </div>

      <button
        onClick={onReset}
        style={{
          padding: '0.75rem 2rem',
          background: 'var(--color-accent)',
          color: '#fff',
          border: 'none',
          borderRadius: 'var(--radius)',
          cursor: 'pointer',
          fontSize: '1rem',
          fontWeight: 600,
        }}
      >
        Nueva verificación
      </button>
    </div>
  );
}

// ── Invalid/expired result ────────────────────────────────────────────────────

function InvalidResult({ reason, onReset }: { reason: string; onReset: () => void }) {
  return (
    <div style={{ textAlign: 'center' }}>
      <div
        style={{
          width: 80,
          height: 80,
          borderRadius: '50%',
          background: 'rgba(239,68,68,0.12)',
          border: '2px solid rgba(239,68,68,0.4)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          margin: '0 auto 1.25rem',
          fontSize: '2.5rem',
        }}
      >
        ❌
      </div>
      <h2 style={{ marginBottom: '0.5rem' }}>Verificación fallida</h2>
      <p style={{ color: 'var(--color-danger)', marginBottom: '1.5rem', fontSize: '0.9rem' }}>
        {reason}
      </p>
      <button
        onClick={onReset}
        style={{
          padding: '0.75rem 2rem',
          background: 'var(--color-accent)',
          color: '#fff',
          border: 'none',
          borderRadius: 'var(--radius)',
          cursor: 'pointer',
          fontSize: '1rem',
          fontWeight: 600,
        }}
      >
        Nueva verificación
      </button>
    </div>
  );
}

// ── Helper ────────────────────────────────────────────────────────────────────

function BadgeRow({
  label,
  value,
  mono = false,
  valueStyle,
}: {
  label: string;
  value: string;
  mono?: boolean;
  valueStyle?: React.CSSProperties;
}) {
  return (
    <div
      style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'baseline',
        gap: '1rem',
        padding: '0.35rem 0',
        borderBottom: '1px solid rgba(255,255,255,0.05)',
      }}
    >
      <span style={{ color: 'var(--color-muted)', fontSize: '0.8rem', flexShrink: 0 }}>
        {label}
      </span>
      <span
        style={{
          fontSize: '0.82rem',
          fontFamily: mono ? 'monospace' : undefined,
          color: 'var(--color-text)',
          wordBreak: 'break-all',
          textAlign: 'right',
          ...valueStyle,
        }}
      >
        {value}
      </span>
    </div>
  );
}

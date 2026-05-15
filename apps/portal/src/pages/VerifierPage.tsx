import { useState, useEffect, useCallback } from 'react';
import { QRGenerator } from '../components/QRGenerator.tsx';
import { BadgeValidator } from '../components/BadgeValidator.tsx';
import type { ChallengeResponse } from '../api/client.ts';

type SessionState =
  | { phase: 'idle' }
  | { phase: 'pending'; challenge: ChallengeResponse }
  | { phase: 'valid'; challenge: ChallengeResponse }
  | { phase: 'expired' | 'invalid'; challenge: ChallengeResponse; reason: string };

export function VerifierPage() {
  const [session, setSession] = useState<SessionState>({ phase: 'idle' });

  const handleNewSession = useCallback((challenge: ChallengeResponse) => {
    setSession({ phase: 'pending', challenge });
  }, []);

  const handleValidated = useCallback(() => {
    setSession((prev) =>
      prev.phase === 'pending' ? { ...prev, phase: 'valid' } : prev
    );
  }, []);

  const handleExpiredOrInvalid = useCallback((reason: string) => {
    setSession((prev) =>
      prev.phase === 'pending' ? { ...prev, phase: 'expired', reason } : prev
    );
  }, []);

  const handleReset = useCallback(() => {
    setSession({ phase: 'idle' });
  }, []);

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

      {(session.phase === 'valid' || session.phase === 'expired' || session.phase === 'invalid') && (
        <div style={{ textAlign: 'center' }}>
          <div
            style={{
              fontSize: '4rem',
              marginBottom: '1rem',
            }}
          >
            {session.phase === 'valid' ? '✅' : '❌'}
          </div>
          <h2 style={{ marginBottom: '0.5rem' }}>
            {session.phase === 'valid' ? 'Presencia verificada' : 'Verificación fallida'}
          </h2>
          {(session.phase === 'expired' || session.phase === 'invalid') && (
            <p style={{ color: 'var(--color-danger)', marginBottom: '1rem' }}>
              {session.reason}
            </p>
          )}
          <button
            onClick={handleReset}
            style={{
              marginTop: '1.5rem',
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
      )}
    </main>
  );
}

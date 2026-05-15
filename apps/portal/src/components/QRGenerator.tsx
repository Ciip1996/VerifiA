import { useState } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { createChallenge, type ChallengeResponse } from '../api/client.ts';

interface Props {
  onChallengeCreated: (challenge: ChallengeResponse) => void;
}

export function QRGenerator({ onChallengeCreated }: Props) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [preview, setPreview] = useState<ChallengeResponse | null>(null);

  async function handleGenerate() {
    setLoading(true);
    setError(null);
    try {
      const challenge = await createChallenge();
      setPreview(challenge);
      // Move to polling phase after a short preview
      setTimeout(() => onChallengeCreated(challenge), 1500);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Error generating challenge');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{ textAlign: 'center' }}>
      <p style={{ color: 'var(--color-muted)', marginBottom: '2rem' }}>
        Genera un código QR para que el portador escanee y complete la verificación de presencia.
      </p>

      {preview && (
        <div style={{ marginBottom: '1.5rem' }}>
          <div
            style={{
              background: '#fff',
              padding: '1rem',
              borderRadius: 'var(--radius)',
              display: 'inline-block',
              marginBottom: '1rem',
            }}
          >
            <QRCodeSVG value={preview.qr_data} size={240} />
          </div>
          <p style={{ fontSize: '0.75rem', color: 'var(--color-muted)', fontFamily: 'monospace' }}>
            nonce: {preview.nonce.slice(0, 16)}...
          </p>
        </div>
      )}

      {!preview && (
        <button
          onClick={handleGenerate}
          disabled={loading}
          style={{
            padding: '0.875rem 2.5rem',
            background: 'var(--color-accent)',
            color: '#fff',
            border: 'none',
            borderRadius: 'var(--radius)',
            cursor: loading ? 'not-allowed' : 'pointer',
            fontSize: '1rem',
            fontWeight: 600,
            opacity: loading ? 0.7 : 1,
          }}
        >
          {loading ? 'Generando...' : 'Generar QR de verificación'}
        </button>
      )}

      {error && (
        <p style={{ color: 'var(--color-danger)', marginTop: '1rem' }}>{error}</p>
      )}
    </div>
  );
}

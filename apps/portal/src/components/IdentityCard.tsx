import type { UserIdentity } from '../api/client.ts';

const b64Src = (b64: string) => `data:image/jpeg;base64,${b64}`;

function scoreColor(score: number) {
  if (score >= 85) return { fg: '#22c55e', bg: 'rgba(34,197,94,0.12)', border: 'rgba(34,197,94,0.35)' };
  if (score >= 70) return { fg: '#a3e635', bg: 'rgba(163,230,53,0.12)', border: 'rgba(163,230,53,0.35)' };
  if (score >= 50) return { fg: '#f59e0b', bg: 'rgba(245,158,11,0.12)', border: 'rgba(245,158,11,0.35)' };
  return { fg: '#ef4444', bg: 'rgba(239,68,68,0.12)', border: 'rgba(239,68,68,0.35)' };
}

function scoreLabel(score: number) {
  if (score >= 85) return 'Excelente';
  if (score >= 70) return 'Muy alto';
  if (score >= 50) return 'Aceptable';
  if (score >= 30) return 'Bajo';
  return 'Insuficiente';
}

export function ScorePill({
  label,
  score,
}: {
  label: string;
  score: number;
}) {
  const { fg, bg, border } = scoreColor(score);
  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: '0.3rem',
        padding: '0.18rem 0.55rem',
        borderRadius: 20,
        background: bg,
        border: `1px solid ${border}`,
        fontSize: '0.72rem',
        fontWeight: 600,
        color: fg,
      }}
    >
      {label}: {score}/100 — {scoreLabel(score)}
    </span>
  );
}

export function PhotoBox({ src, label }: { src: string; label: string }) {
  return (
    <div>
      <div style={{ fontSize: '0.68rem', color: 'var(--color-muted)', marginBottom: '0.3rem' }}>
        {label}
      </div>
      <img
        src={src}
        alt={label}
        style={{ width: '100%', height: 110, objectFit: 'cover', borderRadius: 8, border: '1px solid rgba(255,255,255,0.1)' }}
      />
    </div>
  );
}

export function EmptyPhotoBox({ label }: { label: string }) {
  return (
    <div>
      <div style={{ fontSize: '0.68rem', color: 'var(--color-muted)', marginBottom: '0.3rem' }}>
        {label}
      </div>
      <div
        style={{
          width: '100%',
          height: 110,
          borderRadius: 8,
          border: '1px dashed rgba(255,255,255,0.15)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: 'var(--color-muted)',
          fontSize: '0.75rem',
        }}
      >
        No disponible
      </div>
    </div>
  );
}

export function IdentityCard({ identity }: { identity?: UserIdentity | null }) {
  if (!identity) {
    return (
      <div
        style={{
          background: 'rgba(255,255,255,0.03)',
          border: '1px solid rgba(255,255,255,0.08)',
          borderRadius: 12,
          padding: '1rem 1.25rem',
          marginBottom: '1.25rem',
          textAlign: 'center',
          color: 'var(--color-muted)',
          fontSize: '0.82rem',
        }}
      >
        Identidad no registrada — este dispositivo no completó el onboarding.
      </div>
    );
  }

  return (
    <div
      style={{
        background: 'rgba(108,99,255,0.06)',
        border: '1px solid rgba(108,99,255,0.25)',
        borderRadius: 14,
        padding: '1.1rem 1.25rem',
        marginBottom: '1.25rem',
        textAlign: 'left',
      }}
    >
      {/* Header */}
      <div
        style={{
          fontSize: '0.68rem',
          color: '#a8a4ff',
          letterSpacing: 1,
          fontWeight: 700,
          marginBottom: '0.85rem',
          display: 'flex',
          alignItems: 'center',
          gap: '0.4rem',
        }}
      >
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
          <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
        </svg>
        IDENTIDAD VERIFICADA
      </div>

      {/* Top row: profile photo + text info */}
      <div style={{ display: 'flex', gap: '1rem', marginBottom: '1rem' }}>
        {identity.profile_photo && (
          <img
            src={b64Src(identity.profile_photo)}
            alt="Selfie registro"
            style={{
              width: 80,
              height: 80,
              borderRadius: 10,
              objectFit: 'cover',
              flexShrink: 0,
              border: '2px solid rgba(108,99,255,0.4)',
            }}
          />
        )}
        <div style={{ flex: 1, minWidth: 0 }}>
          <div
            style={{
              fontWeight: 700,
              fontSize: '1rem',
              color: 'var(--color-text)',
              marginBottom: '0.2rem',
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {identity.full_name}
          </div>
          {identity.id_type && (
            <div style={{ fontSize: '0.8rem', color: 'var(--color-muted)', marginBottom: '0.15rem' }}>
              {identity.id_type === 'INE' ? 'INE / IFE' : 'Pasaporte'}
            </div>
          )}
          {identity.curp && (
            <div style={{ fontSize: '0.72rem', fontFamily: 'monospace', color: 'var(--color-muted)', marginBottom: '0.15rem' }}>
              CURP: {identity.curp}
            </div>
          )}
          {identity.date_of_birth && (
            <div style={{ fontSize: '0.75rem', color: 'var(--color-muted)', marginBottom: '0.35rem' }}>
              Nac. {identity.date_of_birth}
            </div>
          )}
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.35rem' }}>
            {identity.facetec_match_level != null && (
              <ScorePill label="Match INE (2D vs 3D)" score={identity.facetec_match_level} />
            )}
            {identity.liveness_match_score != null && (
              <ScorePill label="Match verificación (3D vs 3D)" score={identity.liveness_match_score} />
            )}
          </div>
        </div>
      </div>

      {/* Bottom row: liveness snapshot + ID front photo */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
        {identity.liveness_snapshot ? (
          <PhotoBox src={b64Src(identity.liveness_snapshot)} label="Selfie en verificación" />
        ) : (
          <EmptyPhotoBox label="Selfie en verificación" />
        )}
        {identity.id_front_photo ? (
          <PhotoBox src={b64Src(identity.id_front_photo)} label={`Frente del ${identity.id_type}`} />
        ) : (
          <EmptyPhotoBox label="Frente del ID" />
        )}
      </div>
    </div>
  );
}

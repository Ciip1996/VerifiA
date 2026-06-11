import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { getPublicProfile, createChallenge, type PublicProfile } from '../api/client.ts';

export function PublicProfilePage() {
  const { accountId } = useParams<{ accountId: string }>();
  const navigate = useNavigate();
  const [profile, setProfile] = useState<PublicProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [sending, setSending] = useState(false);
  const [sent, setSent] = useState(false);
  const [sendError, setSendError] = useState<string | null>(null);

  useEffect(() => {
    if (!accountId) return;
    setLoading(true);
    getPublicProfile(accountId)
      .then(setProfile)
      .catch((err) => setError(err instanceof Error ? err.message : 'Error al cargar perfil'))
      .finally(() => setLoading(false));
  }, [accountId]);

  async function handleSendRequest() {
    if (!profile?.email) return;
    setSending(true);
    setSendError(null);
    try {
      await createChallenge({ targetEmail: profile.email });
      setSent(true);
    } catch (err) {
      setSendError(err instanceof Error ? err.message : 'Error al enviar solicitud');
    } finally {
      setSending(false);
    }
  }

  if (loading) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh' }}>
        <div style={{ textAlign: 'center', color: 'var(--color-muted)' }}>
          <div style={{ width: 36, height: 36, border: '3px solid rgba(108,99,255,0.3)', borderTopColor: '#6c63ff', borderRadius: '50%', animation: 'spin 0.8s linear infinite', margin: '0 auto 1rem' }} />
          Cargando perfil…
        </div>
      </div>
    );
  }

  if (error || !profile) {
    return (
      <div style={{ maxWidth: 480, margin: '4rem auto', padding: '0 1.5rem', textAlign: 'center' }}>
        <div style={{ fontSize: '2rem', marginBottom: '1rem' }}>⚠️</div>
        <div style={{ fontWeight: 600, color: 'var(--color-text)', marginBottom: '0.5rem' }}>No se pudo cargar el perfil</div>
        <div style={{ color: 'var(--color-muted)', fontSize: '0.88rem', marginBottom: '1.5rem' }}>{error}</div>
        <button onClick={() => navigate('/buscar')} style={{ padding: '0.6rem 1.5rem', borderRadius: 10, border: '1px solid var(--color-border)', background: 'transparent', color: 'var(--color-muted)', cursor: 'pointer' }}>
          ← Volver a buscar
        </button>
      </div>
    );
  }

  const age = profile.date_of_birth
    ? Math.floor((Date.now() - new Date(profile.date_of_birth).getTime()) / (365.25 * 24 * 3600 * 1000))
    : null;

  const scoreColor = (s: number) =>
    s >= 85 ? '#22c55e' : s >= 70 ? '#a3e635' : s >= 50 ? '#f59e0b' : '#ef4444';
  const scoreLabel = (s: number) =>
    s >= 85 ? 'Excelente' : s >= 70 ? 'Muy alto' : s >= 50 ? 'Aceptable' : s >= 30 ? 'Bajo' : 'Insuficiente';

  return (
    <div style={{ maxWidth: 640, margin: '0 auto', padding: '0 0 6rem' }}>

      {/* Back button */}
      <div style={{ padding: '1.25rem 1.5rem 0' }}>
        <button
          onClick={() => navigate(-1)}
          style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', color: 'var(--color-muted)', background: 'none', border: 'none', cursor: 'pointer', fontSize: '0.85rem', padding: '0.4rem 0' }}
        >
          ← Volver
        </button>
      </div>

      {/* Hero header */}
      <div style={{
        background: 'linear-gradient(180deg, rgba(108,99,255,0.18) 0%, transparent 100%)',
        borderBottom: '1px solid var(--color-border)',
        padding: '2rem 1.5rem 1.75rem',
        display: 'flex',
        gap: '1.25rem',
        alignItems: 'flex-start',
      }}>
        {/* Avatar */}
        <div style={{ flexShrink: 0 }}>
          {profile.profile_photo ? (
            <img
              src={`data:image/jpeg;base64,${profile.profile_photo}`}
              alt={profile.full_name ?? ''}
              style={{ width: 88, height: 88, borderRadius: '50%', objectFit: 'cover', border: '3px solid rgba(108,99,255,0.5)' }}
            />
          ) : (
            <div style={{
              width: 88, height: 88, borderRadius: '50%',
              background: 'rgba(108,99,255,0.2)', border: '3px solid rgba(108,99,255,0.4)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 32, fontWeight: 700, color: '#a8a4ff',
            }}>
              {profile.full_name ? profile.full_name.split(' ').map((w) => w[0]).join('').slice(0, 2).toUpperCase() : '?'}
            </div>
          )}
        </div>

        {/* Info */}
        <div style={{ flex: 1, minWidth: 0 }}>
          <h1 style={{ fontSize: '1.3rem', fontWeight: 700, color: 'var(--color-text)', marginBottom: '0.15rem' }}>
            {profile.full_name ?? 'Sin nombre'}
          </h1>
          {age !== null && (
            <div style={{ fontSize: '0.82rem', color: 'var(--color-muted)', marginBottom: '0.35rem' }}>
              {age} años
            </div>
          )}
          {profile.id_type && (
            <span style={{
              display: 'inline-flex', alignItems: 'center', gap: '0.3rem',
              fontSize: '0.72rem', fontWeight: 600, color: '#a8a4ff',
              background: 'rgba(108,99,255,0.15)', border: '1px solid rgba(108,99,255,0.3)',
              padding: '2px 9px', borderRadius: 10,
            }}>
              <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
              </svg>
              Identidad verificada con FaceTec
            </span>
          )}
        </div>
      </div>

      {/* Content */}
      <div style={{ padding: '1.5rem' }}>

        {/* FaceTec score */}
        {profile.facetec_match_level != null && (
          <div style={{
            background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)',
            borderRadius: 14, padding: '1rem 1.1rem', marginBottom: '1.25rem',
          }}>
            <div style={{ fontSize: '0.68rem', color: 'var(--color-muted)', letterSpacing: 1, fontWeight: 600, marginBottom: '0.75rem' }}>PUNTAJE BIOMÉTRICO</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
              {/* Arc gauge */}
              <svg width="72" height="72" viewBox="0 0 72 72" style={{ flexShrink: 0 }}>
                <circle cx="36" cy="36" r="28" fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth="6" strokeDasharray="132 44" strokeDashoffset="-22" strokeLinecap="round" />
                <circle
                  cx="36" cy="36" r="28"
                  fill="none"
                  stroke={scoreColor(profile.facetec_match_level)}
                  strokeWidth="6"
                  strokeDasharray={`${132 * profile.facetec_match_level / 100} ${132 * (1 - profile.facetec_match_level / 100) + 44}`}
                  strokeDashoffset="-22"
                  strokeLinecap="round"
                  style={{ transition: 'stroke-dasharray 0.5s ease' }}
                />
                <text x="36" y="40" textAnchor="middle" fontSize="14" fontWeight="700" fill={scoreColor(profile.facetec_match_level)}>
                  {profile.facetec_match_level}
                </text>
              </svg>
              <div>
                <div style={{ fontWeight: 700, fontSize: '1rem', color: scoreColor(profile.facetec_match_level) }}>
                  {scoreLabel(profile.facetec_match_level)}
                </div>
                <div style={{ fontSize: '0.78rem', color: 'var(--color-muted)' }}>
                  Match facial FaceTec (2D vs 3D)
                </div>
                <div style={{ fontSize: '0.72rem', color: 'var(--color-muted)', marginTop: '0.15rem' }}>
                  Coincidencia foto ID vs selfie biométrico
                </div>
              </div>
            </div>
          </div>
        )}

        {/* ID details */}
        <div style={{
          background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)',
          borderRadius: 14, padding: '1rem 1.1rem', marginBottom: '1.25rem',
        }}>
          <div style={{ fontSize: '0.68rem', color: 'var(--color-muted)', letterSpacing: 1, fontWeight: 600, marginBottom: '0.75rem' }}>INFORMACIÓN DE IDENTIDAD</div>
          <ProfileRow label="Correo" value={profile.email} />
          {profile.id_type && (
            <ProfileRow label="Tipo de ID" value={profile.id_type === 'INE' ? 'INE / IFE' : 'Pasaporte'} />
          )}
          {profile.date_of_birth && (
            <ProfileRow label="Fecha de nacimiento" value={profile.date_of_birth} />
          )}
        </div>

        {/* ID front photo */}
        {profile.id_front_photo && (
          <div style={{ marginBottom: '1.25rem' }}>
            <div style={{ fontSize: '0.75rem', color: 'var(--color-muted)', marginBottom: '0.5rem', fontWeight: 500 }}>
              Frente del {profile.id_type ?? 'ID'}
            </div>
            <img
              src={`data:image/jpeg;base64,${profile.id_front_photo}`}
              alt="ID front"
              style={{ width: '100%', maxHeight: 200, objectFit: 'cover', borderRadius: 12, border: '1px solid rgba(255,255,255,0.1)' }}
            />
          </div>
        )}
      </div>

      {/* Sticky CTA */}
      <div style={{
        position: 'fixed', bottom: 0, left: 0, right: 0,
        padding: '1rem 1.5rem', background: 'var(--color-bg)',
        borderTop: '1px solid var(--color-border)',
        display: 'flex', alignItems: 'center', gap: '0.75rem',
        zIndex: 50,
      }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          {sent ? (
            <div style={{ fontSize: '0.82rem', color: '#22c55e', fontWeight: 600 }}>
              ✓ Solicitud enviada a {profile.email}
            </div>
          ) : sendError ? (
            <div style={{ fontSize: '0.78rem', color: '#ef4444' }}>{sendError}</div>
          ) : (
            <div style={{ fontSize: '0.8rem', color: 'var(--color-muted)' }}>
              El usuario recibirá la solicitud en su app
            </div>
          )}
        </div>
        <button
          onClick={handleSendRequest}
          disabled={sending || sent}
          style={{
            padding: '0.7rem 1.4rem',
            background: sent ? 'rgba(34,197,94,0.15)' : 'var(--color-accent)',
            color: sent ? '#22c55e' : '#fff',
            border: sent ? '1px solid rgba(34,197,94,0.4)' : 'none',
            borderRadius: 10,
            cursor: sending || sent ? 'not-allowed' : 'pointer',
            fontSize: '0.88rem',
            fontWeight: 700,
            opacity: sending ? 0.7 : 1,
            flexShrink: 0,
            transition: 'all 0.2s',
            whiteSpace: 'nowrap',
          }}
        >
          {sent ? '✓ Enviado' : sending ? 'Enviando…' : 'Solicitar verificación'}
        </button>
      </div>
    </div>
  );
}

function ProfileRow({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', gap: '1rem', padding: '0.35rem 0', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
      <span style={{ fontSize: '0.8rem', color: 'var(--color-muted)', flexShrink: 0 }}>{label}</span>
      <span style={{ fontSize: '0.82rem', color: 'var(--color-text)', textAlign: 'right', wordBreak: 'break-word' }}>{value}</span>
    </div>
  );
}

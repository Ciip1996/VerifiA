import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { getMeDetails, type AccountDetails } from '../api/client.ts';
import { useAuth } from '../context/AuthContext.tsx';

export function ProfilePage() {
  const { account, logout } = useAuth();
  const navigate = useNavigate();
  const [details, setDetails] = useState<AccountDetails | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [confirmLogout, setConfirmLogout] = useState(false);

  useEffect(() => {
    getMeDetails()
      .then(setDetails)
      .catch((err) => setError(err instanceof Error ? err.message : 'Error al cargar perfil'))
      .finally(() => setLoading(false));
  }, []);

  function handleLogout() {
    logout();
    navigate('/login', { replace: true });
  }

  const displayData = details ?? account;

  return (
    <div style={{ maxWidth: 580, margin: '0 auto', padding: '2rem 1.5rem' }}>
      {/* Page header */}
      <div style={{ marginBottom: '2rem' }}>
        <h1 style={{ fontSize: '1.35rem', fontWeight: 700, color: 'var(--color-text)', marginBottom: '0.25rem' }}>
          Mi perfil
        </h1>
        <p style={{ fontSize: '0.88rem', color: 'var(--color-muted)' }}>
          Tu identidad verificada en VerifiA.
        </p>
      </div>

      {loading && (
        <div style={{ textAlign: 'center', padding: '3rem', color: 'var(--color-muted)' }}>
          <div style={{ width: 32, height: 32, border: '3px solid rgba(108,99,255,0.3)', borderTopColor: '#6c63ff', borderRadius: '50%', animation: 'spin 0.8s linear infinite', margin: '0 auto 1rem' }} />
          Cargando perfil…
        </div>
      )}

      {error && (
        <div style={{ padding: '0.7rem 0.9rem', background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.3)', borderRadius: 8, color: '#ef4444', fontSize: '0.85rem', marginBottom: '1.25rem' }}>
          {error}
        </div>
      )}

      {!loading && displayData && (
        <>
          {/* Avatar + name card */}
          <div style={{
            background: 'linear-gradient(135deg, rgba(108,99,255,0.12) 0%, rgba(168,85,247,0.08) 100%)',
            border: '1px solid rgba(108,99,255,0.25)',
            borderRadius: 16,
            padding: '1.5rem',
            marginBottom: '1.25rem',
            display: 'flex',
            gap: '1.25rem',
            alignItems: 'center',
          }}>
            {displayData.profile_photo ? (
              <img
                src={`data:image/jpeg;base64,${displayData.profile_photo}`}
                alt={displayData.full_name ?? ''}
                style={{ width: 80, height: 80, borderRadius: '50%', objectFit: 'cover', border: '3px solid rgba(108,99,255,0.5)', flexShrink: 0 }}
              />
            ) : (
              <div style={{
                width: 80, height: 80, borderRadius: '50%', background: 'rgba(108,99,255,0.2)',
                border: '3px solid rgba(108,99,255,0.4)', display: 'flex', alignItems: 'center',
                justifyContent: 'center', fontSize: 28, fontWeight: 700, color: '#a8a4ff', flexShrink: 0,
              }}>
                {displayData.full_name ? displayData.full_name.split(' ').map((w) => w[0]).join('').slice(0, 2).toUpperCase() : '?'}
              </div>
            )}
            <div>
              <div style={{ fontWeight: 700, fontSize: '1.1rem', color: 'var(--color-text)', marginBottom: '0.25rem' }}>
                {displayData.full_name ?? displayData.email}
              </div>
              {displayData.full_name && (
                <div style={{ fontSize: '0.82rem', color: 'var(--color-muted)', marginBottom: '0.35rem' }}>
                  {displayData.email}
                </div>
              )}
              {displayData.id_type && (
                <span style={{
                  display: 'inline-flex', alignItems: 'center', gap: '0.3rem',
                  fontSize: '0.72rem', fontWeight: 600, color: '#a8a4ff',
                  background: 'rgba(108,99,255,0.15)', border: '1px solid rgba(108,99,255,0.3)',
                  padding: '2px 9px', borderRadius: 10,
                }}>
                  <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                    <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                  </svg>
                  Identidad verificada
                </span>
              )}
            </div>
          </div>

          {/* Details card */}
          <div style={{
            background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)',
            borderRadius: 14, padding: '1rem 1.1rem', marginBottom: '1.25rem',
          }}>
            <div style={{ fontSize: '0.68rem', color: 'var(--color-muted)', letterSpacing: 1, fontWeight: 600, marginBottom: '0.75rem' }}>INFORMACIÓN DE CUENTA</div>
            <ProfileRow label="Correo electrónico" value={displayData.email} />
            {displayData.id_type && (
              <ProfileRow label="Tipo de ID" value={displayData.id_type === 'INE' ? 'INE / IFE' : 'Pasaporte'} />
            )}
            {details?.date_of_birth && (
              <ProfileRow label="Fecha de nacimiento" value={details.date_of_birth} />
            )}
            {details?.curp && (
              <ProfileRow label="CURP" value={details.curp} mono />
            )}
          </div>

          {/* Security note */}
          <div style={{
            display: 'flex', alignItems: 'flex-start', gap: '0.6rem',
            background: 'rgba(34,197,94,0.06)', border: '1px solid rgba(34,197,94,0.2)',
            borderRadius: 10, padding: '0.75rem 0.9rem', marginBottom: '2rem',
            fontSize: '0.8rem', color: '#22c55e',
          }}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" style={{ flexShrink: 0, marginTop: 1 }}>
              <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
            </svg>
            <span>Tu identidad fue verificada con FaceTec Photo ID Match. Los datos biométricos se almacenan de forma segura y encriptada.</span>
          </div>

          {/* Logout */}
          {!confirmLogout ? (
            <button
              onClick={() => setConfirmLogout(true)}
              style={{
                width: '100%', padding: '0.75rem',
                background: 'rgba(239,68,68,0.08)', border: '1px solid rgba(239,68,68,0.3)',
                borderRadius: 12, color: '#ef4444', cursor: 'pointer', fontSize: '0.9rem', fontWeight: 600,
                transition: 'background 0.15s',
              }}
              onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(239,68,68,0.14)')}
              onMouseLeave={(e) => (e.currentTarget.style.background = 'rgba(239,68,68,0.08)')}
            >
              Cerrar sesión
            </button>
          ) : (
            <div style={{
              background: 'rgba(239,68,68,0.08)', border: '1px solid rgba(239,68,68,0.3)',
              borderRadius: 12, padding: '1rem 1.1rem',
            }}>
              <div style={{ fontWeight: 600, fontSize: '0.9rem', color: 'var(--color-text)', marginBottom: '0.4rem' }}>
                ¿Cerrar sesión?
              </div>
              <div style={{ fontSize: '0.82rem', color: 'var(--color-muted)', marginBottom: '1rem' }}>
                Tendrás que iniciar sesión de nuevo para acceder al portal.
              </div>
              <div style={{ display: 'flex', gap: '0.6rem' }}>
                <button
                  onClick={handleLogout}
                  style={{ flex: 1, padding: '0.6rem', background: '#ef4444', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontWeight: 700, fontSize: '0.88rem' }}
                >
                  Sí, cerrar sesión
                </button>
                <button
                  onClick={() => setConfirmLogout(false)}
                  style={{ flex: 1, padding: '0.6rem', background: 'transparent', color: 'var(--color-muted)', border: '1px solid var(--color-border)', borderRadius: 8, cursor: 'pointer', fontSize: '0.88rem' }}
                >
                  Cancelar
                </button>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}

function ProfileRow({ label, value, mono = false }: { label: string; value: string; mono?: boolean }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', gap: '1rem', padding: '0.38rem 0', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
      <span style={{ fontSize: '0.8rem', color: 'var(--color-muted)', flexShrink: 0 }}>{label}</span>
      <span style={{ fontSize: '0.82rem', color: 'var(--color-text)', textAlign: 'right', wordBreak: 'break-word', fontFamily: mono ? 'monospace' : undefined }}>
        {value}
      </span>
    </div>
  );
}

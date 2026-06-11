import { useState, useCallback, useEffect } from 'react';
import { QRGenerator } from '../components/QRGenerator.tsx';
import { BadgeValidator } from '../components/BadgeValidator.tsx';
import type { BadgeInfo, ChallengeResponse, UserIdentity, ChallengeHistoryItem } from '../api/client.ts';
import { getChallengeHistory } from '../api/client.ts';
import { useAuth } from '../context/AuthContext.tsx';
import { useNavigate } from 'react-router-dom';

type SessionState =
  | { phase: 'idle' }
  | { phase: 'pending'; challenge: ChallengeResponse }
  | { phase: 'valid'; challenge: ChallengeResponse; badge: BadgeInfo; identity?: UserIdentity | null }
  | { phase: 'expired' | 'invalid'; challenge: ChallengeResponse; reason: string }
  | { phase: 'rejected'; challenge: ChallengeResponse; rejection_reason: string };

type TabId = 'new' | 'history';

export function VerifierPage() {
  const { account, logout } = useAuth();
  const navigate = useNavigate();
  const [session, setSession] = useState<SessionState>({ phase: 'idle' });
  const [tab, setTab] = useState<TabId>('new');
  const [history, setHistory] = useState<ChallengeHistoryItem[]>([]);
  const [historyLoading, setHistoryLoading] = useState(false);

  const loadHistory = useCallback(async () => {
    setHistoryLoading(true);
    try {
      const res = await getChallengeHistory();
      setHistory(res.items);
    } catch {
      // ignore
    } finally {
      setHistoryLoading(false);
    }
  }, []);

  useEffect(() => {
    if (tab === 'history') loadHistory();
  }, [tab, loadHistory]);

  // Reload history whenever a session completes
  useEffect(() => {
    if (session.phase === 'valid' || session.phase === 'rejected') {
      loadHistory();
    }
  }, [session.phase, loadHistory]);

  const handleNewSession = useCallback((challenge: ChallengeResponse) => {
    setSession({ phase: 'pending', challenge });
  }, []);

  const handleValidated = useCallback((badge: BadgeInfo, identity?: UserIdentity | null) => {
    setSession((prev) =>
      prev.phase === 'pending' ? { ...prev, phase: 'valid', badge, identity } : prev,
    );
  }, []);

  const handleExpiredOrInvalid = useCallback((reason: string, rejectionReason?: string) => {
    setSession((prev) => {
      if (prev.phase !== 'pending') return prev;
      if (rejectionReason) {
        return { ...prev, phase: 'rejected', rejection_reason: rejectionReason };
      }
      return { ...prev, phase: 'expired', reason };
    });
  }, []);

  const handleReset = useCallback(() => setSession({ phase: 'idle' }), []);

  function handleLogout() {
    logout();
    navigate('/login', { replace: true });
  }

  const b64Avatar = account?.profile_photo
    ? `data:image/jpeg;base64,${account.profile_photo}`
    : null;

  return (
    <main style={{ maxWidth: 680, margin: '0 auto', padding: '1.5rem 1rem' }}>
      {/* Header */}
      <header style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        marginBottom: '1.75rem',
        gap: '1rem',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
          {b64Avatar ? (
            <img src={b64Avatar} alt="avatar" style={{ width: 40, height: 40, borderRadius: '50%', objectFit: 'cover', border: '2px solid rgba(108,99,255,0.5)' }} />
          ) : (
            <div style={{ width: 40, height: 40, borderRadius: '50%', background: 'rgba(108,99,255,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18 }}>🛡️</div>
          )}
          <div>
            <div style={{ fontWeight: 700, color: 'var(--color-text)', fontSize: '0.95rem' }}>
              {account?.full_name ?? account?.email}
            </div>
            {account?.full_name && (
              <div style={{ fontSize: '0.75rem', color: 'var(--color-muted)' }}>{account.email}</div>
            )}
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
          <span style={{
            padding: '0.2rem 0.6rem',
            borderRadius: 20,
            background: 'rgba(108,99,255,0.15)',
            color: '#a8a4ff',
            fontSize: '0.72rem',
            fontWeight: 700,
            letterSpacing: 0.8,
          }}>
            VERIFICADO
          </span>
          <button onClick={handleLogout} style={{
            padding: '0.4rem 0.9rem',
            borderRadius: 8,
            border: '1px solid var(--color-border)',
            background: 'transparent',
            color: 'var(--color-muted)',
            cursor: 'pointer',
            fontSize: '0.82rem',
          }}>
            Salir
          </button>
        </div>
      </header>

      {/* Tabs */}
      <div style={{ display: 'flex', gap: '0.25rem', marginBottom: '1.5rem', borderBottom: '1px solid var(--color-border)', paddingBottom: 0 }}>
        {(['new', 'history'] as const).map(t => (
          <button key={t} onClick={() => setTab(t)} style={{
            padding: '0.55rem 1.1rem',
            border: 'none',
            background: 'transparent',
            color: tab === t ? '#6c63ff' : 'var(--color-muted)',
            fontWeight: tab === t ? 700 : 400,
            fontSize: '0.9rem',
            cursor: 'pointer',
            borderBottom: tab === t ? '2px solid #6c63ff' : '2px solid transparent',
            marginBottom: -1,
          }}>
            {t === 'new' ? 'Nueva verificación' : 'Historial'}
          </button>
        ))}
      </div>

      {/* Tab content */}
      {tab === 'new' && (
        <>
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
            <ValidResult badge={session.badge} identity={session.identity} onReset={handleReset} />
          )}
          {session.phase === 'rejected' && (
            <RejectedResult reason={session.rejection_reason} onReset={handleReset} />
          )}
          {(session.phase === 'expired' || session.phase === 'invalid') && (
            <InvalidResult reason={session.reason} onReset={handleReset} />
          )}
        </>
      )}

      {tab === 'history' && (
        <HistoryPanel items={history} loading={historyLoading} onRefresh={loadHistory} />
      )}
    </main>
  );
}

// ── Valid result ─────────────────────────────────────────────────────────────

function ValidResult({
  badge,
  identity,
  onReset,
}: {
  badge: BadgeInfo;
  identity?: UserIdentity | null;
  onReset: () => void;
}) {
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

      {/* Identity card — only when profile exists */}
      <IdentityCard identity={identity} />

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

// ── Identity Card ─────────────────────────────────────────────────────────────

function IdentityCard({ identity }: { identity?: UserIdentity | null }) {
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

  const b64Src = (b64: string) => `data:image/jpeg;base64,${b64}`;

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
              marginBottom: '0.25rem',
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
            <div style={{ fontSize: '0.75rem', color: 'var(--color-muted)', marginBottom: '0.15rem' }}>
              Nac. {identity.date_of_birth}
            </div>
          )}
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.35rem', marginTop: '0.35rem' }}>
            {identity.facetec_match_level != null && (
              <div
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '0.3rem',
                  padding: '0.18rem 0.55rem',
                  borderRadius: 20,
                  background: identity.facetec_match_level >= 70
                    ? 'rgba(34,197,94,0.14)'
                    : 'rgba(239,68,68,0.14)',
                  border: `1px solid ${identity.facetec_match_level >= 70 ? 'rgba(34,197,94,0.4)' : 'rgba(239,68,68,0.4)'}`,
                  fontSize: '0.72rem',
                  fontWeight: 600,
                  color: identity.facetec_match_level >= 70 ? '#22c55e' : '#ef4444',
                }}
              >
                Match INE (2D vs 3D): {identity.facetec_match_level}/100
              </div>
            )}
            {identity.liveness_match_score != null && (
              <div
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '0.3rem',
                  padding: '0.18rem 0.55rem',
                  borderRadius: 20,
                  background: identity.liveness_match_score >= 70
                    ? 'rgba(34,197,94,0.14)'
                    : 'rgba(239,68,68,0.14)',
                  border: `1px solid ${identity.liveness_match_score >= 70 ? 'rgba(34,197,94,0.4)' : 'rgba(239,68,68,0.4)'}`,
                  fontSize: '0.72rem',
                  fontWeight: 600,
                  color: identity.liveness_match_score >= 70 ? '#22c55e' : '#ef4444',
                }}
              >
                Match verificación (3D vs 3D): {identity.liveness_match_score}/100
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Bottom row: liveness snapshot + ID front photo */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
        {identity.liveness_snapshot ? (
          <PhotoBox
            src={b64Src(identity.liveness_snapshot)}
            label="Selfie en verificación"
          />
        ) : (
          <EmptyPhotoBox label="Selfie en verificación" />
        )}
        {identity.id_front_photo ? (
          <PhotoBox
            src={b64Src(identity.id_front_photo)}
            label={`Frente del ${identity.id_type}`}
          />
        ) : (
          <EmptyPhotoBox label="Frente del ID" />
        )}
      </div>
    </div>
  );
}

function PhotoBox({ src, label }: { src: string; label: string }) {
  return (
    <div>
      <div style={{ fontSize: '0.68rem', color: 'var(--color-muted)', marginBottom: '0.3rem' }}>
        {label}
      </div>
      <img
        src={src}
        alt={label}
        style={{
          width: '100%',
          height: 110,
          objectFit: 'cover',
          borderRadius: 8,
          border: '1px solid rgba(255,255,255,0.1)',
        }}
      />
    </div>
  );
}

function EmptyPhotoBox({ label }: { label: string }) {
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

// ── Rejected result ───────────────────────────────────────────────────────────

function RejectedResult({ reason, onReset }: { reason: string; onReset: () => void }) {
  return (
    <div style={{ textAlign: 'center' }}>
      <div style={{
        width: 80, height: 80, borderRadius: '50%',
        background: 'rgba(245,158,11,0.12)',
        border: '2px solid rgba(245,158,11,0.4)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        margin: '0 auto 1.25rem', fontSize: '2.5rem',
      }}>
        ⚠️
      </div>
      <h2 style={{ marginBottom: '0.25rem', color: '#f59e0b' }}>Verificación rechazada</h2>
      <p style={{ color: 'var(--color-muted)', marginBottom: '0.75rem', fontSize: '0.88rem' }}>
        FaceTec detectó que la persona no coincide con el registro
      </p>
      <div style={{
        background: 'rgba(245,158,11,0.08)',
        border: '1px solid rgba(245,158,11,0.3)',
        borderRadius: 10,
        padding: '0.85rem 1rem',
        marginBottom: '1.5rem',
        fontSize: '0.85rem',
        color: '#f59e0b',
        textAlign: 'left',
      }}>
        {reason}
      </div>
      <button onClick={onReset} style={{
        padding: '0.75rem 2rem', background: 'var(--color-accent)',
        color: '#fff', border: 'none', borderRadius: 'var(--radius)',
        cursor: 'pointer', fontSize: '1rem', fontWeight: 600,
      }}>
        Nueva verificación
      </button>
    </div>
  );
}

// ── History panel ─────────────────────────────────────────────────────────────

function HistoryPanel({
  items,
  loading,
  onRefresh,
}: {
  items: ChallengeHistoryItem[];
  loading: boolean;
  onRefresh: () => void;
}) {
  if (loading) {
    return <div style={{ textAlign: 'center', color: 'var(--color-muted)', padding: '2rem' }}>Cargando historial…</div>;
  }
  if (items.length === 0) {
    return (
      <div style={{ textAlign: 'center', color: 'var(--color-muted)', padding: '2.5rem 1rem' }}>
        <div style={{ fontSize: '2rem', marginBottom: '0.75rem' }}>📋</div>
        <p>Aún no has generado ningún QR de verificación.</p>
        <button onClick={onRefresh} style={{ marginTop: '1rem', padding: '0.5rem 1.2rem', borderRadius: 8, border: '1px solid var(--color-border)', background: 'transparent', color: 'var(--color-muted)', cursor: 'pointer' }}>
          Actualizar
        </button>
      </div>
    );
  }

  function statusLabel(item: ChallengeHistoryItem) {
    if (item.status === 'REJECTED') return { text: 'Rechazado', color: '#f59e0b' };
    if (item.token?.status === 'USED') return { text: 'Validado', color: '#22c55e' };
    if (item.status === 'PENDING') return { text: 'Pendiente', color: '#6c63ff' };
    return { text: item.status, color: 'var(--color-muted)' };
  }

  const b64Src = (b64: string) => `data:image/jpeg;base64,${b64}`;

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '0.75rem' }}>
        <button onClick={onRefresh} style={{ padding: '0.4rem 0.9rem', borderRadius: 8, border: '1px solid var(--color-border)', background: 'transparent', color: 'var(--color-muted)', cursor: 'pointer', fontSize: '0.82rem' }}>
          ↻ Actualizar
        </button>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
        {items.map(item => {
          const { text: stText, color: stColor } = statusLabel(item);
          const date = new Date(item.created_at).toLocaleString('es-MX', { dateStyle: 'short', timeStyle: 'short' });
          return (
            <div key={item.nonce} style={{
              background: 'var(--color-surface)',
              border: '1px solid var(--color-border)',
              borderRadius: 12,
              padding: '0.9rem 1rem',
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '0.5rem' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', flex: 1, minWidth: 0 }}>
                  {item.subject?.profile_photo ? (
                    <img src={b64Src(item.subject.profile_photo)} alt="" style={{ width: 36, height: 36, borderRadius: '50%', objectFit: 'cover', flexShrink: 0 }} />
                  ) : (
                    <div style={{ width: 36, height: 36, borderRadius: '50%', background: 'rgba(108,99,255,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>👤</div>
                  )}
                  <div style={{ minWidth: 0 }}>
                    <div style={{ fontWeight: 600, fontSize: '0.9rem', color: 'var(--color-text)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {item.subject?.full_name ?? item.target_email ?? 'Verificación abierta'}
                    </div>
                    <div style={{ fontSize: '0.75rem', color: 'var(--color-muted)' }}>{date}</div>
                  </div>
                </div>
                <span style={{
                  padding: '0.2rem 0.6rem', borderRadius: 20,
                  background: `${stColor}20`, color: stColor,
                  fontSize: '0.72rem', fontWeight: 700, flexShrink: 0,
                }}>
                  {stText}
                </span>
              </div>

              {/* Score badges */}
              {item.token && (
                <div style={{ display: 'flex', gap: '0.4rem', marginTop: '0.6rem', flexWrap: 'wrap' }}>
                  {item.token.liveness_match_score !== null && (
                    <span style={{
                      padding: '0.15rem 0.5rem', borderRadius: 20, fontSize: '0.72rem', fontWeight: 600,
                      background: (item.token.liveness_match_score ?? 0) >= 70 ? 'rgba(34,197,94,0.12)' : 'rgba(239,68,68,0.12)',
                      color: (item.token.liveness_match_score ?? 0) >= 70 ? '#22c55e' : '#ef4444',
                      border: `1px solid ${(item.token.liveness_match_score ?? 0) >= 70 ? 'rgba(34,197,94,0.3)' : 'rgba(239,68,68,0.3)'}`,
                    }}>
                      3D match: {item.token.liveness_match_score}/100
                    </span>
                  )}
                </div>
              )}

              {/* Rejection reason */}
              {item.rejection_reason && (
                <div style={{
                  marginTop: '0.6rem', padding: '0.5rem 0.75rem',
                  background: 'rgba(245,158,11,0.08)', border: '1px solid rgba(245,158,11,0.25)',
                  borderRadius: 8, fontSize: '0.78rem', color: '#f59e0b',
                }}>
                  {item.rejection_reason}
                </div>
              )}
            </div>
          );
        })}
      </div>
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

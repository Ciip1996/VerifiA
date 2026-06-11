import { useState, useEffect, useCallback, useRef } from 'react';
import {
  rejectChallenge,
  cancelChallenge,
  getChallengeHistory,
  type IncomingChallenge,
  type ChallengeHistoryItem,
} from '../api/client.ts';
import { useInbox } from '../context/InboxContext.tsx';
import { IdentityCard, PhotoBox, EmptyPhotoBox } from '../components/IdentityCard.tsx';

type TabId = 'recibidas' | 'enviadas';

// ─── SolicitudesPage ──────────────────────────────────────────────────────────

export function SolicitudesPage() {
  const [tab, setTab] = useState<TabId>('recibidas');
  const { markAllSeen } = useInbox();

  useEffect(() => {
    if (tab === 'recibidas') markAllSeen();
  }, [tab, markAllSeen]);

  return (
    <div style={{ maxWidth: 720, margin: '0 auto', padding: '2rem 1.5rem' }}>
      <div style={{ marginBottom: '1.75rem' }}>
        <h1 style={{ fontSize: '1.35rem', fontWeight: 700, color: 'var(--color-text)', marginBottom: '0.25rem' }}>Solicitudes</h1>
        <p style={{ fontSize: '0.88rem', color: 'var(--color-muted)' }}>Verificaciones recibidas y enviadas.</p>
      </div>

      {/* Tabs */}
      <div style={{ display: 'flex', gap: 0, marginBottom: '1.5rem', borderBottom: '1px solid var(--color-border)' }}>
        {(['recibidas', 'enviadas'] as const).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            style={{
              padding: '0.55rem 1.2rem',
              border: 'none',
              background: 'transparent',
              color: tab === t ? '#6c63ff' : 'var(--color-muted)',
              fontWeight: tab === t ? 700 : 400,
              fontSize: '0.9rem',
              cursor: 'pointer',
              borderBottom: tab === t ? '2px solid #6c63ff' : '2px solid transparent',
              marginBottom: -1,
              transition: 'color 0.15s',
              textTransform: 'capitalize',
            }}
          >
            {t === 'recibidas' ? 'Recibidas' : 'Enviadas'}
          </button>
        ))}
      </div>

      {tab === 'recibidas' && <RecibidasTab />}
      {tab === 'enviadas' && <EnviadasTab />}
    </div>
  );
}

// ─── Recibidas tab ────────────────────────────────────────────────────────────

function RecibidasTab() {
  const { items, loading, refresh } = useInbox();
  const [rejecting, setRejecting] = useState<string | null>(null);

  async function handleReject(nonce: string) {
    if (!window.confirm('¿Rechazar esta solicitud de verificación?')) return;
    setRejecting(nonce);
    try {
      await rejectChallenge(nonce);
      await refresh();
    } catch {
      window.alert('No se pudo rechazar. Intenta de nuevo.');
    } finally {
      setRejecting(null);
    }
  }

  if (loading && items.length === 0) {
    return <LoadingSpinner />;
  }

  if (items.length === 0) {
    return (
      <EmptyState
        icon="📬"
        title="No tienes solicitudes pendientes"
        subtitle="Cuando alguien te solicite verificar tu identidad, aparecerá aquí."
        onRefresh={refresh}
      />
    );
  }

  return (
    <div>
      {/* Info banner */}
      <div style={{
        display: 'flex', alignItems: 'flex-start', gap: '0.6rem',
        background: 'rgba(108,99,255,0.08)', border: '1px solid rgba(108,99,255,0.25)',
        borderRadius: 10, padding: '0.7rem 0.9rem', marginBottom: '1rem', fontSize: '0.8rem', color: '#a8a4ff',
      }}>
        <span style={{ flexShrink: 0 }}>📱</span>
        <span>Para completar la verificación, escanea el QR con la app VerifiA en tu iPhone.</span>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
        {items.map((item) => (
          <IncomingCard key={item.nonce} item={item} onReject={handleReject} rejecting={rejecting} />
        ))}
      </div>
    </div>
  );
}

function IncomingCard({ item, onReject, rejecting }: { item: IncomingChallenge; onReject: (n: string) => void; rejecting: string | null }) {
  const [timeLeft, setTimeLeft] = useState(() =>
    Math.max(0, Math.floor((new Date(item.expires_at).getTime() - Date.now()) / 1000)),
  );

  useEffect(() => {
    const expAt = new Date(item.expires_at).getTime();
    const id = setInterval(() => {
      setTimeLeft(Math.max(0, Math.floor((expAt - Date.now()) / 1000)));
    }, 1000);
    return () => clearInterval(id);
  }, [item.expires_at]);

  const total = Math.max(1, Math.floor((new Date(item.expires_at).getTime() - new Date(item.created_at).getTime()) / 1000));
  const pct = timeLeft / total;
  const barColor = pct < 0.2 ? '#ef4444' : pct < 0.4 ? '#f59e0b' : '#22c55e';
  const mins = Math.floor(timeLeft / 60);
  const secs = timeLeft % 60;

  return (
    <div style={{ background: 'var(--color-surface)', border: '1px solid var(--color-border)', borderRadius: 14, padding: '1rem 1.1rem' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.75rem' }}>
        <UserAvatar src={item.requester.profile_photo} name={item.requester.full_name} size={44} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontWeight: 600, fontSize: '0.92rem', color: 'var(--color-text)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
            {item.requester.full_name ?? item.requester.email}
          </div>
          <div style={{ fontSize: '0.75rem', color: 'var(--color-muted)' }}>{item.requester.email}</div>
          <div style={{ fontSize: '0.72rem', color: 'var(--color-muted)', marginTop: '0.1rem' }}>
            Solicita verificar tu identidad
          </div>
        </div>
        <button
          onClick={() => onReject(item.nonce)}
          disabled={rejecting === item.nonce || timeLeft === 0}
          style={{
            padding: '0.4rem 0.85rem', borderRadius: 8,
            border: '1px solid rgba(239,68,68,0.4)', background: 'rgba(239,68,68,0.07)',
            color: '#ef4444', cursor: rejecting === item.nonce || timeLeft === 0 ? 'not-allowed' : 'pointer',
            fontSize: '0.8rem', fontWeight: 600, opacity: rejecting === item.nonce || timeLeft === 0 ? 0.5 : 1, flexShrink: 0,
          }}
        >
          {rejecting === item.nonce ? 'Rechazando…' : 'Rechazar'}
        </button>
      </div>

      {/* Countdown bar */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
        <div style={{ flex: 1, height: 5, background: 'rgba(255,255,255,0.08)', borderRadius: 3, overflow: 'hidden' }}>
          <div style={{ height: '100%', width: `${pct * 100}%`, background: barColor, borderRadius: 3, transition: 'width 1s linear, background 0.3s' }} />
        </div>
        <span style={{ fontSize: '0.72rem', color: timeLeft === 0 ? '#ef4444' : 'var(--color-muted)', fontVariantNumeric: 'tabular-nums', flexShrink: 0 }}>
          {timeLeft === 0 ? 'Expirado' : `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`}
        </span>
      </div>
    </div>
  );
}

// ─── Enviadas tab ─────────────────────────────────────────────────────────────

const POLL_MS = 8000;

function EnviadasTab() {
  const [items, setItems] = useState<ChallengeHistoryItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [cancelling, setCancelling] = useState<string | null>(null);
  const [detail, setDetail] = useState<ChallengeHistoryItem | null>(null);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const load = useCallback(async () => {
    try {
      const res = await getChallengeHistory();
      setItems(res.items);
    } catch {
      // ignore
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
    intervalRef.current = setInterval(() => { void load(); }, POLL_MS);
    return () => { if (intervalRef.current) clearInterval(intervalRef.current); };
  }, [load]);

  async function handleCancel(nonce: string) {
    if (!window.confirm('¿Cancelar esta solicitud de verificación pendiente?')) return;
    setCancelling(nonce);
    try {
      await cancelChallenge(nonce);
      setItems((prev) => prev.map((i) => i.nonce === nonce ? { ...i, status: 'CANCELLED' } : i));
    } catch {
      window.alert('No se pudo cancelar. Intenta de nuevo.');
    } finally {
      setCancelling(null);
    }
  }

  if (loading) return <LoadingSpinner />;

  if (items.length === 0) {
    return (
      <EmptyState
        icon="📤"
        title="No has enviado solicitudes"
        subtitle="Cuando crees un QR dirigido a alguien, aparecerá aquí."
        onRefresh={load}
      />
    );
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '0.75rem' }}>
        <button onClick={load} style={{ padding: '0.4rem 0.9rem', borderRadius: 8, border: '1px solid var(--color-border)', background: 'transparent', color: 'var(--color-muted)', cursor: 'pointer', fontSize: '0.82rem' }}>
          ↻ Actualizar
        </button>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
        {items.map((item) => (
          <SentCard
            key={item.nonce}
            item={item}
            onCancel={handleCancel}
            onOpenDetail={setDetail}
            cancelling={cancelling}
          />
        ))}
      </div>

      {detail && (
        <VerificationDetailDrawer item={detail} onClose={() => setDetail(null)} />
      )}
    </div>
  );
}

function SentCard({ item, onCancel, onOpenDetail, cancelling }: {
  item: ChallengeHistoryItem;
  onCancel: (n: string) => void;
  onOpenDetail: (i: ChallengeHistoryItem) => void;
  cancelling: string | null;
}) {
  const { text: stText, color: stColor } = statusLabel(item);
  const date = new Date(item.created_at).toLocaleString('es-MX', { dateStyle: 'short', timeStyle: 'short' });
  const isCompleted = item.token?.status === 'USED';
  const isPending = item.status === 'PENDING';

  return (
    <div
      onClick={isCompleted ? () => onOpenDetail(item) : undefined}
      style={{
        background: 'var(--color-surface)',
        border: '1px solid var(--color-border)',
        borderRadius: 12,
        padding: '0.9rem 1rem',
        cursor: isCompleted ? 'pointer' : 'default',
        transition: isCompleted ? 'border-color 0.15s' : undefined,
      }}
      onMouseEnter={(e) => { if (isCompleted) e.currentTarget.style.borderColor = 'rgba(108,99,255,0.4)'; }}
      onMouseLeave={(e) => { if (isCompleted) e.currentTarget.style.borderColor = 'var(--color-border)'; }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '0.5rem' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', flex: 1, minWidth: 0 }}>
          <UserAvatar src={item.subject?.profile_photo ?? null} name={item.subject?.full_name ?? null} size={36} />
          <div style={{ minWidth: 0 }}>
            <div style={{ fontWeight: 600, fontSize: '0.9rem', color: 'var(--color-text)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {item.subject?.full_name ?? item.target_email ?? 'Verificación abierta'}
            </div>
            <div style={{ fontSize: '0.75rem', color: 'var(--color-muted)' }}>{date}</div>
          </div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '0.35rem', flexShrink: 0 }}>
          <span style={{ padding: '0.2rem 0.6rem', borderRadius: 20, background: `${stColor}20`, color: stColor, fontSize: '0.72rem', fontWeight: 700 }}>
            {stText}
          </span>
          {isPending && (
            <button
              onClick={(e) => { e.stopPropagation(); void onCancel(item.nonce); }}
              disabled={cancelling === item.nonce}
              style={{ padding: '0.15rem 0.55rem', borderRadius: 6, border: '1px solid rgba(239,68,68,0.4)', background: 'rgba(239,68,68,0.06)', color: '#ef4444', cursor: cancelling === item.nonce ? 'not-allowed' : 'pointer', fontSize: '0.7rem', fontWeight: 600, opacity: cancelling === item.nonce ? 0.6 : 1 }}>
              {cancelling === item.nonce ? 'Cancelando…' : 'Cancelar'}
            </button>
          )}
          {isCompleted && (
            <span style={{ fontSize: '0.7rem', color: 'var(--color-muted)' }}>Ver detalle →</span>
          )}
        </div>
      </div>

      {item.token?.liveness_match_score != null && (
        <div style={{ marginTop: '0.6rem' }}>
          <span style={{
            padding: '0.15rem 0.5rem', borderRadius: 20, fontSize: '0.72rem', fontWeight: 600,
            background: (item.token.liveness_match_score ?? 0) >= 70 ? 'rgba(34,197,94,0.12)' : 'rgba(239,68,68,0.12)',
            color: (item.token.liveness_match_score ?? 0) >= 70 ? '#22c55e' : '#ef4444',
            border: `1px solid ${(item.token.liveness_match_score ?? 0) >= 70 ? 'rgba(34,197,94,0.3)' : 'rgba(239,68,68,0.3)'}`,
          }}>
            3D match: {item.token.liveness_match_score}/100
          </span>
        </div>
      )}
      {item.rejection_reason && (
        <div style={{ marginTop: '0.6rem', padding: '0.5rem 0.75rem', background: 'rgba(245,158,11,0.08)', border: '1px solid rgba(245,158,11,0.25)', borderRadius: 8, fontSize: '0.78rem', color: '#f59e0b' }}>
          {item.rejection_reason}
        </div>
      )}
    </div>
  );
}

function statusLabel(item: ChallengeHistoryItem): { text: string; color: string } {
  if (item.status === 'CANCELLED') return { text: 'Cancelado', color: '#9ca3af' };
  if (item.status === 'REJECTED') return { text: 'Rechazado', color: '#f59e0b' };
  if (item.token?.status === 'USED') return { text: 'Completada', color: '#22c55e' };
  if (item.status === 'PENDING') return { text: 'Pendiente', color: '#6c63ff' };
  return { text: item.status, color: 'var(--color-muted)' };
}

// ─── Verification detail drawer ───────────────────────────────────────────────

function VerificationDetailDrawer({ item, onClose }: { item: ChallengeHistoryItem; onClose: () => void }) {
  const [closing, setClosing] = useState(false);
  const b64Src = (b64: string) => `data:image/jpeg;base64,${b64}`;

  function close() {
    setClosing(true);
    setTimeout(onClose, 220);
  }

  // Build a partial UserIdentity-like object from history item for display
  const subject = item.subject;
  const token = item.token;

  return (
    <>
      {/* Overlay */}
      <div
        onClick={close}
        style={{
          position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.55)',
          zIndex: 300, animation: closing ? 'fadeOut 0.2s forwards' : 'fadeIn 0.2s forwards',
        }}
      />
      {/* Drawer */}
      <div style={{
        position: 'fixed', top: 0, right: 0, bottom: 0, width: Math.min(560, window.innerWidth),
        background: 'var(--color-bg)', borderLeft: '1px solid var(--color-border)',
        zIndex: 301, overflowY: 'auto', padding: '1.5rem',
        animation: closing ? 'slideOut 0.22s ease-in forwards' : 'slideIn 0.22s ease-out forwards',
      }}>
        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1.5rem' }}>
          <div>
            <div style={{ fontWeight: 700, fontSize: '1.1rem', color: 'var(--color-text)' }}>Detalle de verificación</div>
            <div style={{ fontSize: '0.75rem', color: 'var(--color-muted)' }}>
              {new Date(item.created_at).toLocaleString('es-MX', { dateStyle: 'long', timeStyle: 'short' })}
            </div>
          </div>
          <button onClick={close} style={{ padding: '0.4rem 0.75rem', borderRadius: 8, border: '1px solid var(--color-border)', background: 'transparent', color: 'var(--color-muted)', cursor: 'pointer', fontSize: '1rem' }}>
            ✕
          </button>
        </div>

        {/* Subject hero */}
        {subject && (
          <div style={{
            display: 'flex', alignItems: 'center', gap: '1rem',
            background: 'rgba(34,197,94,0.08)', border: '1px solid rgba(34,197,94,0.25)',
            borderRadius: 14, padding: '1rem 1.1rem', marginBottom: '1.25rem',
          }}>
            <UserAvatar src={subject.profile_photo} name={subject.full_name} size={56} />
            <div>
              <div style={{ fontWeight: 700, fontSize: '1rem', color: 'var(--color-text)' }}>{subject.full_name}</div>
              <div style={{ fontSize: '0.8rem', color: 'var(--color-muted)', marginBottom: '0.35rem' }}>
                {subject.id_type === 'INE' ? 'INE / IFE' : 'Pasaporte'}
              </div>
              <span style={{ fontSize: '0.72rem', background: 'rgba(34,197,94,0.12)', border: '1px solid rgba(34,197,94,0.3)', color: '#22c55e', padding: '2px 8px', borderRadius: 10, fontWeight: 600 }}>
                ✓ Verificación completada
              </span>
            </div>
          </div>
        )}

        {/* Timestamps */}
        <div style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 12, padding: '0.9rem 1rem', marginBottom: '1.25rem' }}>
          <div style={{ fontSize: '0.68rem', color: 'var(--color-muted)', letterSpacing: 1, fontWeight: 600, marginBottom: '0.6rem' }}>TIEMPOS</div>
          <DrawerRow label="Solicitud creada" value={new Date(item.created_at).toLocaleString('es-MX', { dateStyle: 'short', timeStyle: 'medium' })} />
          {token?.validated_at && (
            <DrawerRow label="Verificado a las" value={new Date(token.validated_at).toLocaleString('es-MX', { dateStyle: 'short', timeStyle: 'medium' })} />
          )}
        </div>

        {/* Biometric scores */}
        {token && (
          <div style={{ marginBottom: '1.25rem' }}>
            <div style={{ fontSize: '0.68rem', color: 'var(--color-muted)', letterSpacing: 1, fontWeight: 600, marginBottom: '0.6rem' }}>PUNTAJES BIOMÉTRICOS</div>
            {token.liveness_match_score != null && (
              <ScoreBar label="Match 3D vs 3D (verificación en vivo)" score={token.liveness_match_score} />
            )}
          </div>
        )}

        {/* Photos */}
        <div style={{ marginBottom: '1.25rem' }}>
          <div style={{ fontSize: '0.68rem', color: 'var(--color-muted)', letterSpacing: 1, fontWeight: 600, marginBottom: '0.75rem' }}>FOTOS</div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
            {token?.liveness_snapshot ? (
              <PhotoBox src={b64Src(token.liveness_snapshot)} label="Selfie en verificación" />
            ) : (
              <EmptyPhotoBox label="Selfie en verificación" />
            )}
            {subject?.profile_photo ? (
              <PhotoBox src={b64Src(subject.profile_photo)} label="Foto de registro" />
            ) : (
              <EmptyPhotoBox label="Foto de registro" />
            )}
          </div>
        </div>

        {/* Nonce */}
        <div style={{ fontSize: '0.7rem', color: 'var(--color-muted)', fontFamily: 'monospace', wordBreak: 'break-all' }}>
          nonce: {item.nonce}
        </div>
      </div>

      <style>{`
        @keyframes fadeIn { from { opacity: 0 } to { opacity: 1 } }
        @keyframes fadeOut { from { opacity: 1 } to { opacity: 0 } }
        @keyframes slideIn { from { transform: translateX(100%) } to { transform: translateX(0) } }
        @keyframes slideOut { from { transform: translateX(0) } to { transform: translateX(100%) } }
      `}</style>
    </>
  );
}

// ─── Shared sub-components ────────────────────────────────────────────────────

function DrawerRow({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', gap: '1rem', padding: '0.3rem 0', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
      <span style={{ fontSize: '0.8rem', color: 'var(--color-muted)', flexShrink: 0 }}>{label}</span>
      <span style={{ fontSize: '0.8rem', color: 'var(--color-text)', textAlign: 'right' }}>{value}</span>
    </div>
  );
}

function ScoreBar({ label, score }: { label: string; score: number }) {
  const color = score >= 70 ? '#22c55e' : score >= 50 ? '#f59e0b' : '#ef4444';
  const sublabel = score >= 85 ? 'Excelente' : score >= 70 ? 'Muy alto' : score >= 50 ? 'Aceptable' : 'Bajo';
  return (
    <div style={{ marginBottom: '0.75rem' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.3rem' }}>
        <span style={{ fontSize: '0.78rem', color: 'var(--color-muted)' }}>{label}</span>
        <span style={{ fontSize: '0.78rem', fontWeight: 700, color }}>{score}/100 — {sublabel}</span>
      </div>
      <div style={{ height: 6, background: 'rgba(255,255,255,0.08)', borderRadius: 3, overflow: 'hidden' }}>
        <div style={{ height: '100%', width: `${score}%`, background: color, borderRadius: 3, transition: 'width 0.4s ease' }} />
      </div>
    </div>
  );
}

function UserAvatar({ src, name, size = 36 }: { src: string | null; name: string | null; size?: number }) {
  if (src) {
    return (
      <img
        src={`data:image/jpeg;base64,${src}`}
        alt={name ?? ''}
        style={{ width: size, height: size, borderRadius: '50%', objectFit: 'cover', flexShrink: 0, border: '2px solid rgba(108,99,255,0.3)' }}
      />
    );
  }
  const initials = name ? name.split(' ').map((w) => w[0]).join('').slice(0, 2).toUpperCase() : '?';
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%', background: 'rgba(108,99,255,0.2)',
      border: '2px solid rgba(108,99,255,0.3)', display: 'flex', alignItems: 'center',
      justifyContent: 'center', fontSize: size * 0.35, fontWeight: 700, color: '#a8a4ff', flexShrink: 0,
    }}>
      {initials}
    </div>
  );
}

function LoadingSpinner() {
  return (
    <div style={{ textAlign: 'center', padding: '3rem', color: 'var(--color-muted)' }}>
      <div style={{ width: 32, height: 32, border: '3px solid rgba(108,99,255,0.3)', borderTopColor: '#6c63ff', borderRadius: '50%', animation: 'spin 0.8s linear infinite', margin: '0 auto 0.75rem' }} />
      Cargando…
    </div>
  );
}

function EmptyState({ icon, title, subtitle, onRefresh }: { icon: string; title: string; subtitle: string; onRefresh?: () => void }) {
  return (
    <div style={{ textAlign: 'center', padding: '3rem 1rem', color: 'var(--color-muted)' }}>
      <div style={{ fontSize: '2.2rem', marginBottom: '0.75rem' }}>{icon}</div>
      <div style={{ fontWeight: 600, fontSize: '0.95rem', color: 'var(--color-text)', marginBottom: '0.4rem' }}>{title}</div>
      <div style={{ fontSize: '0.85rem', marginBottom: '1.25rem' }}>{subtitle}</div>
      {onRefresh && (
        <button onClick={onRefresh} style={{ padding: '0.5rem 1.2rem', borderRadius: 8, border: '1px solid var(--color-border)', background: 'transparent', color: 'var(--color-muted)', cursor: 'pointer', fontSize: '0.85rem' }}>
          ↻ Actualizar
        </button>
      )}
    </div>
  );
}

// Re-export for convenience
export { IdentityCard };

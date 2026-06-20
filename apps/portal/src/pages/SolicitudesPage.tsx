import { useState, useEffect, useCallback, useRef } from 'react';
import { useTranslation } from 'react-i18next';
import {
  rejectChallenge,
  cancelChallenge,
  getChallengeHistory,
  type IncomingChallenge,
  type ChallengeHistoryItem,
} from '../api/client.ts';
import { useInbox } from '../context/InboxContext.tsx';
import { IdentityCard, PhotoBox, EmptyPhotoBox } from '../components/IdentityCard.tsx';
import { PhotoLightbox } from '../components/PhotoLightbox.tsx';

type TabId = 'recibidas' | 'enviadas';

// ─── SolicitudesPage ──────────────────────────────────────────────────────────

export function SolicitudesPage() {
  const { t } = useTranslation();
  const [tab, setTab] = useState<TabId>('recibidas');
  const { markAllSeen } = useInbox();

  useEffect(() => {
    if (tab === 'recibidas') markAllSeen();
  }, [tab, markAllSeen]);

  const TABS: { id: TabId; label: string }[] = [
    { id: 'recibidas', label: t('solicitudes.tabReceived') },
    { id: 'enviadas', label: t('solicitudes.tabSent') },
  ];

  return (
    <div style={{ maxWidth: 720, margin: '0 auto', padding: '2rem 1.5rem' }}>
      <div style={{ marginBottom: '1.75rem' }}>
        <h1 style={{ fontSize: '1.35rem', fontWeight: 700, color: 'var(--color-text)', marginBottom: '0.25rem' }}>{t('solicitudes.title')}</h1>
        <p style={{ fontSize: '0.88rem', color: 'var(--color-muted)' }}>{t('solicitudes.subtitle')}</p>
      </div>

      {/* Tabs */}
      <div style={{ display: 'flex', gap: 0, marginBottom: '1.5rem', borderBottom: '1px solid var(--color-border)' }}>
        {TABS.map(({ id, label }) => (
          <button
            key={id}
            onClick={() => setTab(id)}
            style={{
              padding: '0.55rem 1.2rem',
              border: 'none',
              background: 'transparent',
              color: tab === id ? 'var(--color-accent)' : 'var(--color-muted)',
              fontWeight: tab === id ? 700 : 400,
              fontSize: '0.9rem',
              cursor: 'pointer',
              borderBottom: tab === id ? '2px solid var(--color-accent)' : '2px solid transparent',
              marginBottom: -1,
              transition: 'color 0.15s',
            }}
          >
            {label}
          </button>
        ))}
      </div>

      {tab === 'recibidas' && <RecibidasTab />}
      {tab === 'enviadas' && <EnviadasTab />}
    </div>
  );
}

// ─── Confirm Dialog ────────────────────────────────────────────────────────────

function ConfirmDialog({
  title,
  body,
  confirmLabel,
  confirmColor,
  onConfirm,
  onCancel,
}: {
  title: string;
  body: string;
  confirmLabel: string;
  confirmColor: string;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  return (
    <>
      <div
        onClick={onCancel}
        style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', zIndex: 600 }}
      />
      <div style={{
        position: 'fixed', top: '50%', left: '50%', transform: 'translate(-50%,-50%)',
        width: 'min(420px, calc(100vw - 2rem))', background: 'var(--color-surface)',
        border: '1px solid var(--color-border)', borderRadius: 16, padding: '1.5rem',
        zIndex: 601, boxShadow: '0 20px 60px rgba(0,0,0,0.5)',
      }}>
        <div style={{ fontWeight: 700, fontSize: '1rem', color: 'var(--color-text)', marginBottom: '0.5rem' }}>{title}</div>
        <div style={{ fontSize: '0.88rem', color: 'var(--color-muted)', marginBottom: '1.25rem' }}>{body}</div>
        <div style={{ display: 'flex', gap: '0.65rem', justifyContent: 'flex-end' }}>
          <button
            onClick={onCancel}
            style={{ padding: '0.5rem 1rem', borderRadius: 8, border: '1px solid var(--color-border)', background: 'transparent', color: 'var(--color-muted)', cursor: 'pointer', fontSize: '0.88rem' }}
          >
            Cancelar
          </button>
          <button
            onClick={onConfirm}
            style={{ padding: '0.5rem 1rem', borderRadius: 8, border: `1px solid ${confirmColor}50`, background: `${confirmColor}15`, color: confirmColor, cursor: 'pointer', fontSize: '0.88rem', fontWeight: 600 }}
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </>
  );
}

// ─── Recibidas tab ────────────────────────────────────────────────────────────

function RecibidasTab() {
  const { t } = useTranslation();
  const { items, loading, refresh } = useInbox();
  const [rejecting, setRejecting] = useState<string | null>(null);
  const [confirmNonce, setConfirmNonce] = useState<string | null>(null);

  async function doReject(nonce: string) {
    setConfirmNonce(null);
    setRejecting(nonce);
    try {
      await rejectChallenge(nonce);
      await refresh();
    } catch {
      // no-op; user can retry
    } finally {
      setRejecting(null);
    }
  }

  return (
    <>
      {confirmNonce && (
        <ConfirmDialog
          title={t('solicitudes.confirmRejectTitle')}
          body={t('solicitudes.confirmRejectBody')}
          confirmLabel={t('solicitudes.confirmRejectButton')}
          confirmColor="#ef4444"
          onConfirm={() => void doReject(confirmNonce)}
          onCancel={() => setConfirmNonce(null)}
        />
      )}

      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '0.75rem' }}>
        <button
          onClick={() => void refresh()}
          disabled={loading}
          style={{ padding: '0.4rem 0.9rem', borderRadius: 8, border: '1px solid var(--color-border)', background: 'transparent', color: 'var(--color-muted)', cursor: loading ? 'not-allowed' : 'pointer', fontSize: '0.82rem', opacity: loading ? 0.6 : 1 }}
        >
          {t('solicitudes.refreshButton')}
        </button>
      </div>

      {loading && items.length === 0 ? (
        <LoadingSpinner />
      ) : items.length === 0 ? (
        <EmptyState
          icon="📬"
          title={t('solicitudes.emptyReceivedTitle')}
          subtitle={t('solicitudes.emptyReceivedSubtitle')}
        />
      ) : (
        <div>
          <div style={{
            display: 'flex', alignItems: 'flex-start', gap: '0.6rem',
            background: 'rgba(0,234,242,0.08)', border: '1px solid rgba(0,234,242,0.25)',
            borderRadius: 10, padding: '0.7rem 0.9rem', marginBottom: '1rem', fontSize: '0.8rem', color: 'var(--color-accent)',
          }}>
            <span style={{ flexShrink: 0 }}>📱</span>
            <span>{t('solicitudes.scanHint')}</span>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
            {items.map((item) => (
              <IncomingCard
                key={item.nonce}
                item={item}
                onReject={(n) => setConfirmNonce(n)}
                rejecting={rejecting}
              />
            ))}
          </div>
        </div>
      )}
    </>
  );
}

function IncomingCard({ item, onReject, rejecting }: { item: IncomingChallenge; onReject: (n: string) => void; rejecting: string | null; }) {
  const { t } = useTranslation();
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
            {t('solicitudes.requestsIdentity')}
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
          {rejecting === item.nonce ? t('solicitudes.rejecting') : t('solicitudes.rejectButton')}
        </button>
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
        <div style={{ flex: 1, height: 5, background: 'rgba(255,255,255,0.08)', borderRadius: 3, overflow: 'hidden' }}>
          <div style={{ height: '100%', width: `${pct * 100}%`, background: barColor, borderRadius: 3, transition: 'width 1s linear, background 0.3s' }} />
        </div>
        <span style={{ fontSize: '0.72rem', color: timeLeft === 0 ? '#ef4444' : 'var(--color-muted)', fontVariantNumeric: 'tabular-nums', flexShrink: 0 }}>
          {timeLeft === 0 ? t('expired') : `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`}
        </span>
      </div>
    </div>
  );
}

// ─── Enviadas tab ─────────────────────────────────────────────────────────────

const POLL_MS = 8000;

function EnviadasTab() {
  const { t } = useTranslation();
  const [items, setItems] = useState<ChallengeHistoryItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [cancelling, setCancelling] = useState<string | null>(null);
  const [detail, setDetail] = useState<ChallengeHistoryItem | null>(null);
  const [confirmCancel, setConfirmCancel] = useState<string | null>(null);
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

  async function doCancel(nonce: string) {
    setConfirmCancel(null);
    setCancelling(nonce);
    try {
      await cancelChallenge(nonce);
      setItems((prev) => prev.map((i) => i.nonce === nonce ? { ...i, status: 'CANCELLED' } : i));
    } catch {
      // no-op
    } finally {
      setCancelling(null);
    }
  }

  if (loading) return <LoadingSpinner />;

  if (items.length === 0) {
    return (
      <EmptyState
        icon="📤"
        title={t('solicitudes.emptySentTitle')}
        subtitle={t('solicitudes.emptySentSubtitle')}
        onRefresh={load}
      />
    );
  }

  return (
    <>
      {confirmCancel && (
        <ConfirmDialog
          title={t('solicitudes.confirmCancelTitle')}
          body={t('solicitudes.confirmCancelBody')}
          confirmLabel={t('solicitudes.confirmCancelButton')}
          confirmColor="#ef4444"
          onConfirm={() => void doCancel(confirmCancel)}
          onCancel={() => setConfirmCancel(null)}
        />
      )}

      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '0.75rem' }}>
        <button onClick={load} style={{ padding: '0.4rem 0.9rem', borderRadius: 8, border: '1px solid var(--color-border)', background: 'transparent', color: 'var(--color-muted)', cursor: 'pointer', fontSize: '0.82rem' }}>
          {t('solicitudes.refreshButton')}
        </button>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
        {items.map((item) => (
          <SentCard
            key={item.nonce}
            item={item}
            onCancel={(n) => setConfirmCancel(n)}
            onOpenDetail={setDetail}
            cancelling={cancelling}
          />
        ))}
      </div>

      {detail && (
        <VerificationDetailDrawer item={detail} onClose={() => setDetail(null)} />
      )}
    </>
  );
}

function SentCard({ item, onCancel, onOpenDetail, cancelling }: {
  item: ChallengeHistoryItem;
  onCancel: (n: string) => void;
  onOpenDetail: (i: ChallengeHistoryItem) => void;
  cancelling: string | null;
}) {
  const { t } = useTranslation();
  const { text: stText, color: stColor } = statusLabel(item, t);
  const date = new Date(item.created_at).toLocaleString('es-MX', { dateStyle: 'short', timeStyle: 'short' });
  const isCompleted = item.token?.status === 'USED';
  const canCancel = item.status === 'PENDING' || item.status === 'IN_PROGRESS';

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
      onMouseEnter={(e) => { if (isCompleted) e.currentTarget.style.borderColor = 'rgba(0,234,242,0.4)'; }}
      onMouseLeave={(e) => { if (isCompleted) e.currentTarget.style.borderColor = 'var(--color-border)'; }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '0.5rem' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', flex: 1, minWidth: 0 }}>
          <UserAvatar src={item.subject?.profile_photo ?? null} name={item.subject?.full_name ?? null} size={36} />
          <div style={{ minWidth: 0 }}>
            <div style={{ fontWeight: 600, fontSize: '0.9rem', color: 'var(--color-text)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {item.subject?.full_name ?? item.target_email ?? t('solicitudes.openVerification')}
            </div>
            <div style={{ fontSize: '0.75rem', color: 'var(--color-muted)' }}>{date}</div>
          </div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '0.35rem', flexShrink: 0 }}>
          <span style={{ padding: '0.2rem 0.6rem', borderRadius: 20, background: `${stColor}20`, color: stColor, fontSize: '0.72rem', fontWeight: 700 }}>
            {stText}
          </span>
          {canCancel && (
            <button
              onClick={(e) => { e.stopPropagation(); onCancel(item.nonce); }}
              disabled={cancelling === item.nonce}
              style={{ padding: '0.15rem 0.55rem', borderRadius: 6, border: '1px solid rgba(239,68,68,0.4)', background: 'rgba(239,68,68,0.06)', color: '#ef4444', cursor: cancelling === item.nonce ? 'not-allowed' : 'pointer', fontSize: '0.7rem', fontWeight: 600, opacity: cancelling === item.nonce ? 0.6 : 1 }}>
              {cancelling === item.nonce ? t('solicitudes.cancelling') : t('solicitudes.cancelButton')}
            </button>
          )}
          {isCompleted && (
            <span style={{ fontSize: '0.7rem', color: 'var(--color-muted)' }}>{t('solicitudes.viewDetail')}</span>
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

function statusLabel(item: ChallengeHistoryItem, t: (key: string) => string): { text: string; color: string } {
  if (item.status === 'CANCELLED') return { text: t('solicitudes.statusCancelled'), color: '#9ca3af' };
  if (item.status === 'REJECTED') return { text: t('solicitudes.statusRejected'), color: '#f59e0b' };
  if (item.token?.status === 'USED') return { text: t('solicitudes.statusCompleted'), color: '#22c55e' };
  if (item.status === 'IN_PROGRESS') return { text: t('solicitudes.statusInProgress'), color: '#3b82f6' };
  if (item.status === 'PENDING') return { text: t('solicitudes.statusPending'), color: 'var(--color-accent)' };
  return { text: item.status, color: 'var(--color-muted)' };
}

// ─── Verification detail drawer ───────────────────────────────────────────────

function VerificationDetailDrawer({ item, onClose }: { item: ChallengeHistoryItem; onClose: () => void }) {
  const { t } = useTranslation();
  const [closing, setClosing] = useState(false);
  const [lightbox, setLightbox] = useState<{ src: string; label: string } | null>(null);
  const b64Src = (b64: string) => `data:image/jpeg;base64,${b64}`;

  function close() {
    setClosing(true);
    setTimeout(onClose, 220);
  }

  const subject = item.subject;
  const token = item.token;

  return (
    <>
      {lightbox && (
        <PhotoLightbox src={lightbox.src} label={lightbox.label} onClose={() => setLightbox(null)} />
      )}

      <div
        onClick={close}
        style={{
          position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.55)',
          zIndex: 300, animation: closing ? 'fadeOut 0.2s forwards' : 'fadeIn 0.2s forwards',
        }}
      />
      <div style={{
        position: 'fixed', top: 0, right: 0, bottom: 0, width: Math.min(560, window.innerWidth),
        background: 'var(--color-bg)', borderLeft: '1px solid var(--color-border)',
        zIndex: 301, overflowY: 'auto', padding: '1.5rem',
        animation: closing ? 'slideOut 0.22s ease-in forwards' : 'slideIn 0.22s ease-out forwards',
      }}>
        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1.5rem' }}>
          <div>
            <div style={{ fontWeight: 700, fontSize: '1.1rem', color: 'var(--color-text)' }}>{t('solicitudes.detailTitle')}</div>
            <div style={{ fontSize: '0.75rem', color: 'var(--color-muted)' }}>
              {new Date(item.created_at).toLocaleString('es-MX', { dateStyle: 'long', timeStyle: 'short' })}
            </div>
          </div>
          <button onClick={close} style={{ padding: '0.4rem 0.75rem', borderRadius: 8, border: '1px solid var(--color-border)', background: 'transparent', color: 'var(--color-muted)', cursor: 'pointer', fontSize: '1rem' }}>
            {t('close')}
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
                {idTypeLabel(subject.id_type, t)}
              </div>
              <span style={{ fontSize: '0.72rem', background: 'rgba(34,197,94,0.12)', border: '1px solid rgba(34,197,94,0.3)', color: '#22c55e', padding: '2px 8px', borderRadius: 10, fontWeight: 600 }}>
                {t('solicitudes.verifiedBadgeLabel')}
              </span>
            </div>
          </div>
        )}

        {/* Timestamps + metadata */}
        <div style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 12, padding: '0.9rem 1rem', marginBottom: '1.25rem' }}>
          <div style={{ fontSize: '0.68rem', color: 'var(--color-muted)', letterSpacing: 1, fontWeight: 600, marginBottom: '0.6rem' }}>{t('solicitudes.detailsSectionLabel')}</div>
          <DrawerRow label={t('solicitudes.createdAtLabel')} value={new Date(item.created_at).toLocaleString(undefined, { dateStyle: 'short', timeStyle: 'medium' })} />
          {token?.validated_at && (
            <DrawerRow label={t('solicitudes.verifiedAtLabel')} value={new Date(token.validated_at).toLocaleString(undefined, { dateStyle: 'short', timeStyle: 'medium' })} />
          )}
          {subject?.id_type && (
            <DrawerRow label={t('solicitudes.idTypeLabel')} value={idTypeLabel(subject.id_type, t)} />
          )}
        </div>

        {/* Biometric scores */}
        {token && token.liveness_match_score != null && (
          <div style={{ marginBottom: '1.25rem' }}>
            <div style={{ fontSize: '0.68rem', color: 'var(--color-muted)', letterSpacing: 1, fontWeight: 600, marginBottom: '0.6rem' }}>{t('solicitudes.biometricsSectionLabel')}</div>
            <ScoreBar label={t('solicitudes.matchLabel')} score={token.liveness_match_score} t={t} />
          </div>
        )}

        {/* Photos */}
        <div style={{ marginBottom: '1.25rem' }}>
          <div style={{ fontSize: '0.68rem', color: 'var(--color-muted)', letterSpacing: 1, fontWeight: 600, marginBottom: '0.75rem' }}>{t('solicitudes.photosSectionLabel')}</div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '0.75rem' }}>
            {token?.liveness_snapshot ? (
              <ClickablePhoto src={b64Src(token.liveness_snapshot)} label={t('solicitudes.selfieLabel')} onOpen={setLightbox} />
            ) : (
              <EmptyPhotoBox label={t('solicitudes.selfieLabel')} />
            )}
            {subject?.profile_photo ? (
              <ClickablePhoto src={b64Src(subject.profile_photo)} label={t('solicitudes.profilePhotoLabel')} onOpen={setLightbox} />
            ) : (
              <EmptyPhotoBox label={t('solicitudes.profilePhotoLabel')} />
            )}
            {subject?.id_front_photo ? (
              <ClickablePhoto src={b64Src(subject.id_front_photo)} label={t('solicitudes.idPhotoLabel')} onOpen={setLightbox} />
            ) : (
              <EmptyPhotoBox label={t('solicitudes.idPhotoLabel')} />
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

function idTypeLabel(idType: string | null, t: (key: string) => string): string {
  if (idType === 'INE') return t('solicitudes.idTypeINE');
  if (idType === 'PASSPORT') return t('solicitudes.idTypePassport');
  return idType ?? t('solicitudes.idTypeUnknown');
}

function ClickablePhoto({ src, label, onOpen }: { src: string; label: string; onOpen: (v: { src: string; label: string }) => void }) {
  return (
    <div style={{ position: 'relative', cursor: 'zoom-in' }} onClick={() => onOpen({ src, label })}>
      <PhotoBox src={src} label={label} />
      <div style={{
        position: 'absolute', top: 6, right: 6,
        background: 'rgba(0,0,0,0.55)', borderRadius: 6,
        padding: '2px 5px', fontSize: '0.65rem', color: '#fff', pointerEvents: 'none',
      }}>
        🔍
      </div>
    </div>
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

function ScoreBar({ label, score, t }: { label: string; score: number; t: (key: string) => string }) {
  const color = score >= 70 ? '#22c55e' : score >= 50 ? '#f59e0b' : '#ef4444';
  const sublabel = score >= 85 ? t('solicitudes.matchExcellent') : score >= 70 ? t('solicitudes.matchVeryHigh') : score >= 50 ? t('solicitudes.matchAcceptable') : t('solicitudes.matchLow');
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
        style={{ width: size, height: size, borderRadius: '50%', objectFit: 'cover', flexShrink: 0, border: '2px solid rgba(0,234,242,0.3)' }}
      />
    );
  }
  const initials = name ? name.split(' ').map((w) => w[0]).join('').slice(0, 2).toUpperCase() : '?';
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%', background: 'rgba(0,234,242,0.2)',
      border: '2px solid rgba(0,234,242,0.3)', display: 'flex', alignItems: 'center',
      justifyContent: 'center', fontSize: size * 0.35, fontWeight: 700, color: 'var(--color-accent)', flexShrink: 0,
    }}>
      {initials}
    </div>
  );
}

function LoadingSpinner() {
  const { t } = useTranslation();
  return (
    <div style={{ textAlign: 'center', padding: '3rem', color: 'var(--color-muted)' }}>
      <div style={{ width: 32, height: 32, border: '3px solid rgba(0,234,242,0.3)', borderTopColor: 'var(--color-accent)', borderRadius: '50%', animation: 'spin 0.8s linear infinite', margin: '0 auto 0.75rem' }} />
      {t('loading')}
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

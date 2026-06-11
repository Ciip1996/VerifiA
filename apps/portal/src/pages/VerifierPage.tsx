import { useState, useCallback, useEffect, useRef } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import {
  createChallenge,
  sendInvite,
  searchAccounts,
  getTokenStatus,
  validateToken,
  type ChallengeResponse,
  type BadgeInfo,
  type UserIdentity,
  type AccountSearchResult,
} from '../api/client.ts';
import { IdentityCard } from '../components/IdentityCard.tsx';

// ─── Types ────────────────────────────────────────────────────────────────────

type Mode = 'open' | 'targeted';

type SessionState =
  | { phase: 'idle' }
  | { phase: 'generating' }
  | { phase: 'pending'; challenge: ChallengeResponse; targetEmail: string | null; isUnregistered: boolean }
  | { phase: 'valid'; challenge: ChallengeResponse; badge: BadgeInfo; identity?: UserIdentity | null }
  | { phase: 'expired' | 'invalid'; challenge: ChallengeResponse; reason: string }
  | { phase: 'rejected'; challenge: ChallengeResponse; rejection_reason: string };

const POLL_INTERVAL = parseInt(import.meta.env.VITE_POLL_INTERVAL_MS ?? '2000', 10);

// ─── VerifierPage ─────────────────────────────────────────────────────────────

export function VerifierPage() {
  const [session, setSession] = useState<SessionState>({ phase: 'idle' });
  const [mode, setMode] = useState<Mode>('open');
  const [targetEmail, setTargetEmail] = useState('');
  const [suggestions, setSuggestions] = useState<AccountSearchResult[]>([]);
  const [showDropdown, setShowDropdown] = useState(false);
  const [selectedUser, setSelectedUser] = useState<AccountSearchResult | null>(null);
  const [isUnregistered, setIsUnregistered] = useState(false);
  const [genError, setGenError] = useState<string | null>(null);
  const emailRef = useRef<HTMLInputElement>(null) as React.RefObject<HTMLInputElement>;

  // Debounced autocomplete
  useEffect(() => {
    if (mode !== 'targeted' || targetEmail.length < 2) {
      setSuggestions([]);
      setShowDropdown(false);
      return;
    }
    const timer = setTimeout(async () => {
      try {
        const res = await searchAccounts(targetEmail);
        setSuggestions(res.results);
        setShowDropdown(res.results.length > 0);
        const exactMatch = res.results.find(
          (r) => r.email.toLowerCase() === targetEmail.toLowerCase(),
        );
        setSelectedUser(exactMatch ?? null);
        const looksLikeEmail = targetEmail.includes('@') && targetEmail.length >= 5;
        setIsUnregistered(looksLikeEmail && res.results.length === 0);
      } catch {
        // ignore
      }
    }, 300);
    return () => clearTimeout(timer);
  }, [targetEmail, mode]);

  const handleReset = useCallback(() => {
    setSession({ phase: 'idle' });
    setTargetEmail('');
    setSelectedUser(null);
    setIsUnregistered(false);
    setSuggestions([]);
    setGenError(null);
  }, []);

  async function handleGenerate() {
    if (mode === 'targeted' && !targetEmail.trim()) return;
    setGenError(null);
    setSession({ phase: 'generating' });
    try {
      const challenge = await createChallenge({
        targetEmail: mode === 'targeted' ? targetEmail.trim() : undefined,
      });
      setSession({
        phase: 'pending',
        challenge,
        targetEmail: mode === 'targeted' ? targetEmail.trim() : null,
        isUnregistered,
      });
    } catch (err) {
      setSession({ phase: 'idle' });
      setGenError(err instanceof Error ? err.message : 'Error al generar QR');
    }
  }

  function selectSuggestion(user: AccountSearchResult) {
    setTargetEmail(user.email);
    setSelectedUser(user);
    setIsUnregistered(false);
    setSuggestions([]);
    setShowDropdown(false);
  }

  return (
    <div style={{ maxWidth: 640, margin: '0 auto', padding: '2rem 1.5rem' }}>
      {/* Page header */}
      <div style={{ marginBottom: '2rem' }}>
        <h1 style={{ fontSize: '1.35rem', fontWeight: 700, color: 'var(--color-text)', marginBottom: '0.25rem' }}>
          Verificar identidad
        </h1>
        <p style={{ fontSize: '0.88rem', color: 'var(--color-muted)' }}>
          Genera un QR criptográfico para solicitar verificación de presencia.
        </p>
      </div>

      {session.phase === 'idle' && (
        <IdleView
          mode={mode}
          setMode={setMode}
          targetEmail={targetEmail}
          setTargetEmail={setTargetEmail}
          suggestions={suggestions}
          showDropdown={showDropdown}
          setShowDropdown={setShowDropdown}
          selectedUser={selectedUser}
          isUnregistered={isUnregistered}
          onSelectSuggestion={selectSuggestion}
          onGenerate={handleGenerate}
          error={genError}
          emailRef={emailRef}
        />
      )}

      {session.phase === 'generating' && (
        <div style={{ textAlign: 'center', padding: '3rem 0', color: 'var(--color-muted)' }}>
          <div style={{ width: 32, height: 32, border: '3px solid rgba(108,99,255,0.3)', borderTopColor: '#6c63ff', borderRadius: '50%', animation: 'spin 0.8s linear infinite', margin: '0 auto 1rem' }} />
          Generando QR…
        </div>
      )}

      {session.phase === 'pending' && (
        <PendingView
          challenge={session.challenge}
          targetEmail={session.targetEmail}
          isUnregistered={session.isUnregistered}
          onValidated={(badge, identity) =>
            setSession((prev) =>
              prev.phase === 'pending' ? { ...prev, phase: 'valid', badge, identity } : prev,
            )
          }
          onExpiredOrInvalid={(reason, rejectionReason) =>
            setSession((prev) => {
              if (prev.phase !== 'pending') return prev;
              if (rejectionReason) return { ...prev, phase: 'rejected', rejection_reason: rejectionReason };
              return { ...prev, phase: 'expired', reason };
            })
          }
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
    </div>
  );
}

// ─── Idle view: mode selector + email input + generate button ─────────────────

function IdleView({
  mode,
  setMode,
  targetEmail,
  setTargetEmail,
  suggestions,
  showDropdown,
  setShowDropdown,
  selectedUser,
  isUnregistered,
  onSelectSuggestion,
  onGenerate,
  error,
  emailRef,
}: {
  mode: Mode;
  setMode: (m: Mode) => void;
  targetEmail: string;
  setTargetEmail: (v: string) => void;
  suggestions: AccountSearchResult[];
  showDropdown: boolean;
  setShowDropdown: (v: boolean) => void;
  selectedUser: AccountSearchResult | null;
  isUnregistered: boolean;
  onSelectSuggestion: (u: AccountSearchResult) => void;
  onGenerate: () => void;
  error: string | null;
  emailRef: React.RefObject<HTMLInputElement>;
}) {
  const canGenerate = mode === 'open' || targetEmail.trim().length >= 3;

  return (
    <div>
      {/* Mode selector */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem', marginBottom: '1.5rem' }}>
        {([
          {
            id: 'open' as Mode,
            title: 'Verificación abierta',
            desc: 'QR para cualquier persona. Comparte el link o muestra el código.',
            icon: '🔓',
          },
          {
            id: 'targeted' as Mode,
            title: 'Verificación dirigida',
            desc: 'Solicita a una persona específica por correo electrónico.',
            icon: '🎯',
          },
        ] as const).map(({ id, title, desc, icon }) => (
          <button
            key={id}
            onClick={() => setMode(id)}
            style={{
              padding: '1rem',
              borderRadius: 12,
              border: `2px solid ${mode === id ? '#6c63ff' : 'var(--color-border)'}`,
              background: mode === id ? 'rgba(108,99,255,0.1)' : 'var(--color-surface)',
              cursor: 'pointer',
              textAlign: 'left',
              transition: 'border-color 0.15s, background 0.15s',
            }}
          >
            <div style={{ fontSize: '1.3rem', marginBottom: '0.4rem' }}>{icon}</div>
            <div style={{ fontWeight: 600, fontSize: '0.88rem', color: mode === id ? '#c4c1ff' : 'var(--color-text)', marginBottom: '0.25rem' }}>
              {title}
            </div>
            <div style={{ fontSize: '0.75rem', color: 'var(--color-muted)', lineHeight: 1.4 }}>
              {desc}
            </div>
          </button>
        ))}
      </div>

      {/* Email input for targeted mode */}
      {mode === 'targeted' && (
        <div style={{ marginBottom: '1.25rem', position: 'relative' }}>
          <label style={{ display: 'block', fontSize: '0.8rem', color: 'var(--color-muted)', marginBottom: '0.4rem', fontWeight: 500 }}>
            Correo del destinatario
          </label>
          <div style={{ position: 'relative' }}>
            <input
              ref={emailRef}
              type="email"
              value={targetEmail}
              onChange={(e) => { setTargetEmail(e.target.value); setShowDropdown(true); }}
              onFocus={() => suggestions.length > 0 && setShowDropdown(true)}
              onBlur={() => setTimeout(() => setShowDropdown(false), 150)}
              placeholder="nombre@ejemplo.com"
              autoFocus
              style={{
                width: '100%',
                padding: '0.7rem 0.9rem',
                background: 'var(--color-surface)',
                border: `1px solid ${isUnregistered ? 'rgba(245,158,11,0.5)' : selectedUser ? 'rgba(34,197,94,0.5)' : 'var(--color-border)'}`,
                borderRadius: 10,
                color: 'var(--color-text)',
                fontSize: '0.9rem',
                outline: 'none',
                transition: 'border-color 0.15s',
              }}
            />
            {/* Status icon */}
            {selectedUser && (
              <span style={{ position: 'absolute', right: 10, top: '50%', transform: 'translateY(-50%)', color: '#22c55e', fontSize: '1rem' }}>✓</span>
            )}
            {isUnregistered && (
              <span style={{ position: 'absolute', right: 10, top: '50%', transform: 'translateY(-50%)', color: '#f59e0b', fontSize: '1rem' }}>?</span>
            )}
          </div>

          {/* Autocomplete dropdown */}
          {showDropdown && suggestions.length > 0 && (
            <div style={{
              position: 'absolute',
              top: '100%',
              left: 0,
              right: 0,
              marginTop: 4,
              background: 'var(--color-surface)',
              border: '1px solid var(--color-border)',
              borderRadius: 10,
              boxShadow: '0 8px 24px rgba(0,0,0,0.4)',
              zIndex: 200,
              overflow: 'hidden',
            }}>
              {suggestions.slice(0, 5).map((u) => (
                <button
                  key={u.id}
                  onMouseDown={() => onSelectSuggestion(u)}
                  style={{
                    width: '100%',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '0.65rem',
                    padding: '0.6rem 0.85rem',
                    background: 'transparent',
                    border: 'none',
                    cursor: 'pointer',
                    textAlign: 'left',
                    transition: 'background 0.1s',
                  }}
                  onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(255,255,255,0.05)')}
                  onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
                >
                  <UserAvatarSmall src={u.profile_photo} name={u.full_name} />
                  <div style={{ minWidth: 0 }}>
                    <div style={{ fontWeight: 600, fontSize: '0.85rem', color: 'var(--color-text)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {u.full_name ?? u.email}
                      {u.is_self && (
                        <span style={{ marginLeft: '0.4rem', fontSize: '0.68rem', color: '#a8a4ff', background: 'rgba(108,99,255,0.15)', padding: '1px 6px', borderRadius: 10 }}>
                          Tú
                        </span>
                      )}
                    </div>
                    <div style={{ fontSize: '0.73rem', color: 'var(--color-muted)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {u.email}
                    </div>
                  </div>
                  {u.id_type && (
                    <span style={{ marginLeft: 'auto', fontSize: '0.68rem', color: 'var(--color-muted)', background: 'rgba(255,255,255,0.06)', padding: '2px 7px', borderRadius: 8, flexShrink: 0 }}>
                      {u.id_type === 'INE' ? 'INE' : 'Pasaporte'}
                    </span>
                  )}
                </button>
              ))}
            </div>
          )}

          {/* Registration status pills */}
          {selectedUser && (
            <div style={{ marginTop: '0.5rem', display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
              <span style={{ fontSize: '0.78rem', color: '#22c55e', display: 'flex', alignItems: 'center', gap: '0.3rem' }}>
                ✓ Usuario registrado en VerifiA
              </span>
            </div>
          )}
          {isUnregistered && (
            <div style={{ marginTop: '0.5rem', fontSize: '0.78rem', color: '#f59e0b' }}>
              Este correo no está registrado en VerifiA. Podrás enviar una invitación después de generar el QR.
            </div>
          )}
        </div>
      )}

      {/* Generate button */}
      <button
        onClick={onGenerate}
        disabled={!canGenerate}
        style={{
          width: '100%',
          padding: '0.875rem',
          background: canGenerate ? 'var(--color-accent)' : 'rgba(108,99,255,0.3)',
          color: '#fff',
          border: 'none',
          borderRadius: 12,
          cursor: canGenerate ? 'pointer' : 'not-allowed',
          fontSize: '0.95rem',
          fontWeight: 700,
          transition: 'opacity 0.15s',
        }}
      >
        {mode === 'targeted' ? 'Enviar solicitud y generar QR' : 'Generar QR de verificación'}
      </button>

      {error && (
        <div style={{ marginTop: '0.75rem', padding: '0.65rem 0.9rem', background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.3)', borderRadius: 8, color: '#ef4444', fontSize: '0.85rem' }}>
          {error}
        </div>
      )}
    </div>
  );
}

// ─── Pending view: QR with countdown ring + polling ───────────────────────────

function PendingView({
  challenge,
  targetEmail,
  isUnregistered,
  onValidated,
  onExpiredOrInvalid,
}: {
  challenge: ChallengeResponse;
  targetEmail: string | null;
  isUnregistered: boolean;
  onValidated: (badge: BadgeInfo, identity?: UserIdentity | null) => void;
  onExpiredOrInvalid: (reason: string, rejectionReason?: string) => void;
}) {
  const [timeLeft, setTimeLeft] = useState(challenge.expires_in);
  const [pollStatus, setPollStatus] = useState<'waiting' | 'scanning' | 'validating'>('waiting');
  const [copied, setCopied] = useState(false);
  const [inviteSent, setInviteSent] = useState(false);
  const [inviteError, setInviteError] = useState<string | null>(null);
  const [sendingInvite, setSendingInvite] = useState(false);
  const consumedRef = useRef(false);

  // Countdown
  useEffect(() => {
    const expAt = new Date(challenge.expires_at).getTime();
    const id = setInterval(() => {
      const remaining = Math.max(0, Math.floor((expAt - Date.now()) / 1000));
      setTimeLeft(remaining);
      if (remaining <= 0) {
        clearInterval(id);
        if (!consumedRef.current) onExpiredOrInvalid('El QR expiró antes de ser escaneado.');
      }
    }, 500);
    return () => clearInterval(id);
  }, [challenge.expires_at, onExpiredOrInvalid]);

  // Polling
  useEffect(() => {
    const id = setInterval(async () => {
      if (consumedRef.current) return;
      try {
        const res = await getTokenStatus(challenge.nonce);
        if (res.valid && res.status === 'ACTIVE') {
          setPollStatus('validating');
          clearInterval(id);
          const validate = await validateToken(challenge.nonce);
          consumedRef.current = true;
          if (validate.valid && validate.badge) {
            onValidated(validate.badge, validate.identity);
          } else {
            onExpiredOrInvalid('Validación fallida: ' + validate.message);
          }
        } else if (res.status === 'REJECTED') {
          clearInterval(id);
          consumedRef.current = true;
          onExpiredOrInvalid('Verificación rechazada.', res.rejection_reason ?? 'Score facial insuficiente.');
        } else if (res.status === 'EXPIRED') {
          clearInterval(id);
          if (!consumedRef.current) onExpiredOrInvalid('Token expirado.');
        } else if (res.status === 'USED') {
          clearInterval(id);
          onExpiredOrInvalid('Token ya fue utilizado.');
        } else if (res.status === 'ACTIVE' && !res.valid) {
          setPollStatus('scanning');
        }
      } catch {
        // network hiccup
      }
    }, POLL_INTERVAL);
    return () => clearInterval(id);
  }, [challenge.nonce, onValidated, onExpiredOrInvalid]);

  async function handleSendInvite() {
    if (!targetEmail) return;
    setSendingInvite(true);
    setInviteError(null);
    try {
      await sendInvite(challenge.nonce, targetEmail);
      setInviteSent(true);
    } catch (err) {
      setInviteError(err instanceof Error ? err.message : 'Error al enviar invitación');
    } finally {
      setSendingInvite(false);
    }
  }

  function handleShare() {
    if (navigator.share) {
      void navigator.share({ title: 'Verificar identidad — VerifiA', url: challenge.qr_data });
    } else {
      void navigator.clipboard.writeText(challenge.qr_data).then(() => { setCopied(true); setTimeout(() => setCopied(false), 2000); });
    }
  }

  function handleCopy() {
    void navigator.clipboard.writeText(challenge.qr_data).then(() => { setCopied(true); setTimeout(() => setCopied(false), 2000); });
  }

  const pct = timeLeft / challenge.expires_in;
  const ringColor = pct < 0.2 ? '#ef4444' : pct < 0.4 ? '#f59e0b' : '#22c55e';
  const timerColor = pct < 0.2 ? '#ef4444' : pct < 0.4 ? '#f59e0b' : 'var(--color-text)';
  const minutes = Math.floor(timeLeft / 60);
  const seconds = timeLeft % 60;

  // SVG ring
  const R = 132;
  const C = 2 * Math.PI * R;
  const offset = C * (1 - pct);

  const statusLabel = { waiting: 'Esperando escaneo del QR…', scanning: 'Verificación en curso…', validating: 'Badge recibido — validando…' }[pollStatus];
  const statusDot = { waiting: 'var(--color-accent)', scanning: '#f59e0b', validating: '#22c55e' }[pollStatus];

  return (
    <div style={{ textAlign: 'center' }}>
      {/* Targeted badge */}
      {targetEmail && (
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: '0.4rem',
          background: 'rgba(108,99,255,0.1)', border: '1px solid rgba(108,99,255,0.3)',
          borderRadius: 20, padding: '0.3rem 0.9rem', marginBottom: '1.25rem',
          fontSize: '0.8rem', color: '#a8a4ff',
        }}>
          🎯 Para: <strong style={{ color: '#c4c1ff' }}>{targetEmail}</strong>
        </div>
      )}

      {/* QR with SVG countdown ring */}
      <div style={{ position: 'relative', display: 'inline-block', marginBottom: '1.25rem' }}>
        <svg
          width={300}
          height={300}
          viewBox="0 0 300 300"
          style={{ position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -50%)', pointerEvents: 'none' }}
        >
          <circle cx="150" cy="150" r={R} fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth="3.5" />
          <circle
            cx="150" cy="150" r={R}
            fill="none"
            stroke={ringColor}
            strokeWidth="3.5"
            strokeDasharray={C}
            strokeDashoffset={offset}
            strokeLinecap="round"
            transform="rotate(-90 150 150)"
            style={{ transition: 'stroke-dashoffset 0.5s ease, stroke 0.3s ease' }}
          />
        </svg>
        <div style={{ background: '#fff', padding: '1rem', borderRadius: 12, display: 'inline-block', position: 'relative', zIndex: 1 }}>
          <QRCodeSVG value={challenge.qr_data} size={220} />
          {pollStatus !== 'waiting' && (
            <div style={{
              position: 'absolute', inset: 0, background: 'rgba(255,255,255,0.88)',
              borderRadius: 12, display: 'flex', alignItems: 'center', justifyContent: 'center',
              flexDirection: 'column', gap: '0.5rem',
            }}>
              <div style={{ fontSize: '2.5rem' }}>{pollStatus === 'validating' ? '✅' : '📱'}</div>
              <span style={{ fontSize: '0.8rem', color: '#333', fontWeight: 600 }}>
                {pollStatus === 'validating' ? 'Validando…' : 'Escaneado'}
              </span>
            </div>
          )}
        </div>
      </div>

      {/* Timer */}
      <div style={{ fontSize: '2.5rem', fontWeight: 700, fontVariantNumeric: 'tabular-nums', color: timerColor, marginBottom: '0.4rem', transition: 'color 0.3s' }}>
        {String(minutes).padStart(2, '0')}:{String(seconds).padStart(2, '0')}
      </div>

      {/* Status */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.5rem', color: 'var(--color-muted)', fontSize: '0.875rem', marginBottom: '1.25rem' }}>
        <span style={{ width: 8, height: 8, borderRadius: '50%', background: statusDot, display: 'inline-block', animation: 'pulse 1.5s infinite' }} />
        {statusLabel}
      </div>

      {/* Actions */}
      {pollStatus === 'waiting' && (
        <div style={{ display: 'flex', gap: '0.6rem', justifyContent: 'center', marginBottom: '1.25rem', flexWrap: 'wrap' }}>
          <button onClick={handleCopy} style={actionBtnStyle(copied ? '#22c55e' : 'rgba(108,99,255,0.15)', copied ? 'rgba(34,197,94,0.4)' : 'rgba(108,99,255,0.4)', copied ? '#22c55e' : '#a8a4ff')}>
            {copied ? '✓ Copiado' : '📋 Copiar link'}
          </button>
          {typeof navigator.share === 'function' && (
            <button onClick={handleShare} style={actionBtnStyle('rgba(108,99,255,0.15)', 'rgba(108,99,255,0.4)', '#a8a4ff')}>
              ↑ Compartir
            </button>
          )}
        </div>
      )}

      {/* Invite card for unregistered targets */}
      {isUnregistered && targetEmail && pollStatus === 'waiting' && (
        <div style={{
          background: 'rgba(245,158,11,0.08)', border: '1px solid rgba(245,158,11,0.3)',
          borderRadius: 12, padding: '0.9rem 1rem', marginBottom: '1rem', textAlign: 'left',
        }}>
          <div style={{ fontSize: '0.82rem', color: '#f59e0b', fontWeight: 600, marginBottom: '0.4rem' }}>
            {targetEmail} no está en VerifiA
          </div>
          <div style={{ fontSize: '0.78rem', color: 'var(--color-muted)', marginBottom: '0.65rem' }}>
            Envía una invitación por correo con el link de verificación.
          </div>
          {inviteSent ? (
            <div style={{ fontSize: '0.82rem', color: '#22c55e', fontWeight: 600 }}>✓ Invitación enviada</div>
          ) : (
            <button
              onClick={handleSendInvite}
              disabled={sendingInvite}
              style={{ padding: '0.45rem 1rem', borderRadius: 8, border: '1px solid rgba(245,158,11,0.5)', background: 'rgba(245,158,11,0.12)', color: '#f59e0b', cursor: sendingInvite ? 'not-allowed' : 'pointer', fontSize: '0.82rem', fontWeight: 600, opacity: sendingInvite ? 0.6 : 1 }}>
              {sendingInvite ? 'Enviando…' : '✉️ Enviar invitación por correo'}
            </button>
          )}
          {inviteError && <div style={{ marginTop: '0.4rem', fontSize: '0.75rem', color: '#ef4444' }}>{inviteError}</div>}
        </div>
      )}

      <div style={{ fontSize: '0.7rem', color: 'var(--color-muted)', fontFamily: 'monospace' }}>
        nonce: {challenge.nonce.slice(0, 12)}…
      </div>
    </div>
  );
}

function actionBtnStyle(bg: string, border: string, color: string): React.CSSProperties {
  return { padding: '0.5rem 1rem', background: bg, border: `1px solid ${border}`, borderRadius: 8, color, cursor: 'pointer', fontSize: '0.82rem', fontWeight: 600, transition: 'all 0.2s', whiteSpace: 'nowrap' };
}

// ─── Valid result ──────────────────────────────────────────────────────────────

function ValidResult({ badge, identity, onReset }: { badge: BadgeInfo; identity?: UserIdentity | null; onReset: () => void }) {
  const issuedAt = new Date(badge.issued_at);
  const expiresAt = new Date(badge.expires_at);
  const isExpired = expiresAt.getTime() < Date.now();
  const ttlSeconds = Math.round((expiresAt.getTime() - issuedAt.getTime()) / 1000);
  const fmt = (d: Date) => d.toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit', second: '2-digit' });

  return (
    <div style={{ textAlign: 'center' }}>
      <div style={{ width: 80, height: 80, borderRadius: '50%', background: 'rgba(34,197,94,0.15)', border: '2px solid rgba(34,197,94,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 1.25rem', fontSize: '2.5rem' }}>✅</div>
      <h2 style={{ marginBottom: '0.25rem', color: '#22c55e' }}>Presencia verificada</h2>
      <p style={{ color: 'var(--color-muted)', marginBottom: '1.5rem', fontSize: '0.9rem' }}>El badge es criptográficamente válido</p>

      <IdentityCard identity={identity} />

      <div style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 12, padding: '1rem 1.25rem', marginBottom: '1.5rem', textAlign: 'left' }}>
        <div style={{ fontSize: '0.7rem', color: 'var(--color-muted)', letterSpacing: 1, marginBottom: '0.75rem', fontWeight: 600 }}>DETALLES DEL BADGE</div>
        <BadgeRow label="Badge ID" value={`${badge.jti.slice(0, 18)}…`} mono />
        <BadgeRow label="Verificador" value={badge.verifier} mono />
        <BadgeRow label="Emitido" value={fmt(issuedAt)} />
        <BadgeRow label="Expira" value={`${fmt(expiresAt)} (TTL ${ttlSeconds}s)`} valueStyle={{ color: isExpired ? '#ef4444' : '#22c55e' }} />
      </div>

      <button onClick={onReset} style={{ padding: '0.75rem 2rem', background: 'var(--color-accent)', color: '#fff', border: 'none', borderRadius: 'var(--radius)', cursor: 'pointer', fontSize: '1rem', fontWeight: 600 }}>
        Nueva verificación
      </button>
    </div>
  );
}

// ─── Invalid / Rejected results ───────────────────────────────────────────────

function InvalidResult({ reason, onReset }: { reason: string; onReset: () => void }) {
  return (
    <div style={{ textAlign: 'center' }}>
      <div style={{ width: 80, height: 80, borderRadius: '50%', background: 'rgba(239,68,68,0.12)', border: '2px solid rgba(239,68,68,0.4)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 1.25rem', fontSize: '2.5rem' }}>❌</div>
      <h2 style={{ marginBottom: '0.5rem' }}>Verificación fallida</h2>
      <p style={{ color: 'var(--color-danger)', marginBottom: '1.5rem', fontSize: '0.9rem' }}>{reason}</p>
      <button onClick={onReset} style={{ padding: '0.75rem 2rem', background: 'var(--color-accent)', color: '#fff', border: 'none', borderRadius: 'var(--radius)', cursor: 'pointer', fontSize: '1rem', fontWeight: 600 }}>Nueva verificación</button>
    </div>
  );
}

function RejectedResult({ reason, onReset }: { reason: string; onReset: () => void }) {
  return (
    <div style={{ textAlign: 'center' }}>
      <div style={{ width: 80, height: 80, borderRadius: '50%', background: 'rgba(245,158,11,0.12)', border: '2px solid rgba(245,158,11,0.4)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 1.25rem', fontSize: '2.5rem' }}>⚠️</div>
      <h2 style={{ marginBottom: '0.25rem', color: '#f59e0b' }}>Verificación rechazada</h2>
      <p style={{ color: 'var(--color-muted)', marginBottom: '0.75rem', fontSize: '0.88rem' }}>FaceTec detectó que la persona no coincide con el registro</p>
      <div style={{ background: 'rgba(245,158,11,0.08)', border: '1px solid rgba(245,158,11,0.3)', borderRadius: 10, padding: '0.85rem 1rem', marginBottom: '1.5rem', fontSize: '0.85rem', color: '#f59e0b', textAlign: 'left' }}>
        {reason}
      </div>
      <button onClick={onReset} style={{ padding: '0.75rem 2rem', background: 'var(--color-accent)', color: '#fff', border: 'none', borderRadius: 'var(--radius)', cursor: 'pointer', fontSize: '1rem', fontWeight: 600 }}>Nueva verificación</button>
    </div>
  );
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

function BadgeRow({ label, value, mono = false, valueStyle }: { label: string; value: string; mono?: boolean; valueStyle?: React.CSSProperties }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: '1rem', padding: '0.35rem 0', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
      <span style={{ color: 'var(--color-muted)', fontSize: '0.8rem', flexShrink: 0 }}>{label}</span>
      <span style={{ fontSize: '0.82rem', fontFamily: mono ? 'monospace' : undefined, color: 'var(--color-text)', wordBreak: 'break-all', textAlign: 'right', ...valueStyle }}>{value}</span>
    </div>
  );
}

function UserAvatarSmall({ src, name }: { src: string | null; name: string | null }) {
  if (src) return <img src={`data:image/jpeg;base64,${src}`} alt="" style={{ width: 32, height: 32, borderRadius: '50%', objectFit: 'cover', flexShrink: 0 }} />;
  const initials = name ? name.split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase() : '?';
  return (
    <div style={{ width: 32, height: 32, borderRadius: '50%', background: 'rgba(108,99,255,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12, fontWeight: 700, color: '#a8a4ff', flexShrink: 0 }}>
      {initials}
    </div>
  );
}

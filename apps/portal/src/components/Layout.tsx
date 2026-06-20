import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../context/AuthContext.tsx';
import { useInbox } from '../context/InboxContext.tsx';
import { useSentChanges } from '../context/SentChangesContext.tsx';
import { hasPushPermission, isOneSignalConfigured, requestPushPermission } from '../services/onesignal.ts';
import logo from '../assets/logo.svg';

// ── Icons ─────────────────────────────────────────────────────────────────────

function ShieldIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
    </svg>
  );
}

function BellIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" />
      <path d="M13.73 21a2 2 0 0 1-3.46 0" />
    </svg>
  );
}

function SearchIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="11" cy="11" r="8" />
      <line x1="21" y1="21" x2="16.65" y2="16.65" />
    </svg>
  );
}

function UserIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
      <circle cx="12" cy="7" r="4" />
    </svg>
  );
}

function LogOutIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
      <polyline points="16 17 21 12 16 7" />
      <line x1="21" y1="12" x2="9" y2="12" />
    </svg>
  );
}

function VerifyIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="20 6 9 17 4 12" />
    </svg>
  );
}

// ── Badge count dot ───────────────────────────────────────────────────────────

function BadgeCount({ count }: { count: number }) {
  if (count === 0) return null;
  return (
    <span
      style={{
        minWidth: 18,
        height: 18,
        padding: '0 5px',
        borderRadius: 9,
        background: '#ef4444',
        color: '#fff',
        fontSize: '0.68rem',
        fontWeight: 700,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        lineHeight: 1,
        marginLeft: 'auto',
      }}
    >
      {count > 99 ? '99+' : count}
    </span>
  );
}

// ── Avatar ────────────────────────────────────────────────────────────────────

function Avatar({ src, name, size = 32 }: { src: string | null; name: string | null; size?: number }) {
  if (src) {
    return (
      <img
        src={`data:image/jpeg;base64,${src}`}
        alt={name ?? 'avatar'}
        style={{
          width: size,
          height: size,
          borderRadius: '50%',
          objectFit: 'cover',
          flexShrink: 0,
          border: '2px solid rgba(0,234,242,0.4)',
        }}
      />
    );
  }
  const initials = name
    ? name.split(' ').map((w) => w[0]).join('').slice(0, 2).toUpperCase()
    : '?';
  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: '50%',
        background: 'rgba(0,234,242,0.2)',
        border: '2px solid rgba(0,234,242,0.3)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontSize: size * 0.35,
        fontWeight: 700,
        color: 'var(--color-accent)',
        flexShrink: 0,
      }}
    >
      {initials}
    </div>
  );
}

// ── Language toggle ───────────────────────────────────────────────────────────

function LangToggle() {
  const { i18n } = useTranslation();
  const isEs = i18n.resolvedLanguage === 'es';
  return (
    <div style={{ display: 'flex', gap: 4, padding: '0.35rem 0.5rem' }}>
      <button
        onClick={() => void i18n.changeLanguage('es')}
        style={{
          padding: '0.2rem 0.55rem', borderRadius: 6, border: 'none', cursor: 'pointer',
          fontSize: '0.72rem', fontWeight: isEs ? 700 : 400,
          background: isEs ? 'rgba(0,234,242,0.15)' : 'transparent',
          color: isEs ? 'var(--color-accent)' : 'var(--color-muted)',
        }}
      >
        ES
      </button>
      <button
        onClick={() => void i18n.changeLanguage('en')}
        style={{
          padding: '0.2rem 0.55rem', borderRadius: 6, border: 'none', cursor: 'pointer',
          fontSize: '0.72rem', fontWeight: !isEs ? 700 : 400,
          background: !isEs ? 'rgba(0,234,242,0.15)' : 'transparent',
          color: !isEs ? 'var(--color-accent)' : 'var(--color-muted)',
        }}
      >
        EN
      </button>
    </div>
  );
}

// ── Layout ────────────────────────────────────────────────────────────────────

export function Layout() {
  const { t } = useTranslation();
  const { account, logout } = useAuth();
  const { unseenCount, isOffline, latestNew, consumeLatestNew } = useInbox();
  const { latestChange, consumeLatestChange } = useSentChanges();
  const navigate = useNavigate();
  const [showPushPrompt, setShowPushPrompt] = useState(false);

  // Show soft push permission prompt once per session if not yet granted
  useEffect(() => {
    if (!account || !isOneSignalConfigured()) return;
    // Small delay so the page settles before presenting the prompt
    const id = setTimeout(() => {
      if (!hasPushPermission()) setShowPushPrompt(true);
    }, 3000);
    return () => clearTimeout(id);
  }, [account]);

  const NAV_ITEMS = [
    { to: '/', label: t('nav.verify'), Icon: ShieldIcon, end: true },
    { to: '/solicitudes', label: t('nav.requests'), Icon: BellIcon, end: false },
    { to: '/buscar', label: t('nav.search'), Icon: SearchIcon, end: false },
    { to: '/perfil', label: t('nav.profile'), Icon: UserIcon, end: false },
  ] as const;

  function handleLogout() {
    logout();
    navigate('/login', { replace: true });
  }

  const badgeCounts: Record<string, number> = { '/solicitudes': unseenCount };

  // Auto-dismiss challenge banner after 6s
  useEffect(() => {
    if (!latestNew) return;
    const id = setTimeout(consumeLatestNew, 6000);
    return () => clearTimeout(id);
  }, [latestNew, consumeLatestNew]);

  // Auto-dismiss sent-change banner after 6s
  useEffect(() => {
    if (!latestChange) return;
    const id = setTimeout(consumeLatestChange, 6000);
    return () => clearTimeout(id);
  }, [latestChange, consumeLatestChange]);

  return (
    <div className="verifia-layout">

      {/* ── Offline banner ───────────────────────────────────────────────── */}
      {isOffline && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, height: 36, zIndex: 500,
          background: '#ef4444', display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: '0.82rem', color: '#fff', fontWeight: 600, animation: 'slideDown 0.35s ease',
        }}>
          {t('banner.offline')}
        </div>
      )}

      {/* ── Incoming challenge banner ────────────────────────────────────── */}
      {latestNew && (
        <div style={{
          position: 'fixed', top: isOffline ? 36 : 0, left: 0, right: 0, zIndex: 499,
          background: 'var(--color-surface)', borderBottom: '1px solid rgba(0,234,242,0.35)',
          padding: '0.6rem 1rem', display: 'flex', alignItems: 'center', gap: '0.75rem',
          animation: 'slideDown 0.35s ease', boxShadow: '0 4px 20px rgba(0,0,0,0.3)',
        }}>
          <div style={{ width: 36, height: 36, borderRadius: '50%', background: 'rgba(0,234,242,0.2)', border: '2px solid rgba(0,234,242,0.4)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, fontSize: '0.7rem', fontWeight: 700, color: 'var(--color-accent)' }}>
            {(latestNew.requester.full_name ?? latestNew.requester.email).split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase()}
          </div>
          <span style={{ fontSize: '0.85rem', color: 'var(--color-text)', flex: 1 }}>
            <strong>{latestNew.requester.full_name ?? latestNew.requester.email}</strong>{' '}{t('banner.incomingRequest')}
          </span>
          <button onClick={consumeLatestNew} style={{ background: 'none', border: 'none', color: 'var(--color-muted)', cursor: 'pointer', fontSize: '0.8rem', padding: '0.2rem 0.4rem' }}>{t('dismiss')}</button>
          <button onClick={() => { navigate('/solicitudes'); consumeLatestNew(); }} style={{ background: 'rgba(0,234,242,0.15)', border: '1px solid rgba(0,234,242,0.3)', color: 'var(--color-accent)', cursor: 'pointer', fontSize: '0.8rem', fontWeight: 600, padding: '0.3rem 0.7rem', borderRadius: 7 }}>{t('view')}</button>
        </div>
      )}

      {/* ── Verified (USED) banner ───────────────────────────────────────── */}
      {latestChange?.newStatus === 'USED' && !latestNew && (
        <div style={{
          position: 'fixed', top: isOffline ? 36 : 0, left: 0, right: 0, zIndex: 498,
          background: 'var(--color-surface)', borderBottom: '1px solid rgba(34,197,94,0.35)',
          padding: '0.6rem 1rem', display: 'flex', alignItems: 'center', gap: '0.75rem',
          animation: 'slideDown 0.35s ease', boxShadow: '0 4px 20px rgba(0,0,0,0.3)',
        }}>
          <div style={{ width: 32, height: 32, borderRadius: '50%', background: 'rgba(34,197,94,0.15)', border: '2px solid rgba(34,197,94,0.4)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <VerifyIcon />
          </div>
          <span style={{ fontSize: '0.85rem', color: 'var(--color-text)', flex: 1 }}>
            <strong style={{ color: '#22c55e' }}>{latestChange.subjectFullName ?? latestChange.targetEmail ?? t('banner.someone')}</strong>{' '}
            {t('banner.verifiedRequest')}
          </span>
          <button onClick={consumeLatestChange} style={{ background: 'none', border: 'none', color: 'var(--color-muted)', cursor: 'pointer', fontSize: '0.8rem', padding: '0.2rem 0.4rem' }}>{t('dismiss')}</button>
          <button onClick={() => { navigate('/solicitudes'); consumeLatestChange(); }} style={{ background: 'rgba(34,197,94,0.12)', border: '1px solid rgba(34,197,94,0.3)', color: '#22c55e', cursor: 'pointer', fontSize: '0.8rem', fontWeight: 600, padding: '0.3rem 0.7rem', borderRadius: 7 }}>{t('view')}</button>
        </div>
      )}

      {/* ── Sent-change banner (rejected / cancelled) ────────────────────── */}
      {latestChange && latestChange.newStatus !== 'USED' && !latestNew && (
        <div style={{
          position: 'fixed', top: isOffline ? 36 : 0, left: 0, right: 0, zIndex: 498,
          background: 'var(--color-surface)', borderBottom: '1px solid rgba(245,158,11,0.35)',
          padding: '0.6rem 1rem', display: 'flex', alignItems: 'center', gap: '0.75rem',
          animation: 'slideDown 0.35s ease', boxShadow: '0 4px 20px rgba(0,0,0,0.3)',
        }}>
          <span style={{ fontSize: '0.85rem', color: 'var(--color-text)', flex: 1 }}>
            <strong>{latestChange.subjectFullName ?? latestChange.targetEmail ?? t('banner.someone')}</strong>{' '}
            {latestChange.newStatus === 'REJECTED' ? t('banner.rejectedRequest') : t('banner.cancelledRequest')}
          </span>
          <button onClick={consumeLatestChange} style={{ background: 'none', border: 'none', color: 'var(--color-muted)', cursor: 'pointer', fontSize: '0.8rem', padding: '0.2rem 0.4rem' }}>{t('dismiss')}</button>
          <button onClick={() => { navigate('/solicitudes'); consumeLatestChange(); }} style={{ background: 'rgba(245,158,11,0.12)', border: '1px solid rgba(245,158,11,0.3)', color: '#f59e0b', cursor: 'pointer', fontSize: '0.8rem', fontWeight: 600, padding: '0.3rem 0.7rem', borderRadius: 7 }}>{t('view')}</button>
        </div>
      )}

      {/* ── Desktop Sidebar ──────────────────────────────────────────────── */}
      <aside className="verifia-sidebar">

        {/* Logo */}
        <div style={{
          padding: '1.25rem 1rem 1rem',
          borderBottom: '1px solid var(--color-border)',
          flexShrink: 0,
        }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.25rem' }}>
            <img src={logo} alt="VerifiA" style={{ width: '100%', objectFit: 'contain', objectPosition: 'left' }} />
            <div style={{ fontSize: '0.62rem', color: 'var(--color-muted)', letterSpacing: 0.3 }}>
              {t('portalLabel')}
            </div>
          </div>
        </div>

        {/* Nav */}
        <nav style={{ flex: 1, padding: '0.75rem 0.6rem', display: 'flex', flexDirection: 'column', gap: '0.15rem', overflowY: 'auto' }}>
          {NAV_ITEMS.map(({ to, label, Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) => `verifia-nav-item${isActive ? ' active' : ''}`}
            >
              <Icon />
              <span style={{ flex: 1 }}>{label}</span>
              <BadgeCount count={badgeCounts[to] ?? 0} />
            </NavLink>
          ))}
        </nav>

        {/* User + Logout */}
        <div style={{ padding: '0.6rem', borderTop: '1px solid var(--color-border)', flexShrink: 0 }}>
          {account && (
            <NavLink
              to="/perfil"
              className={({ isActive }) => `verifia-nav-item${isActive ? ' active' : ''}`}
              style={{ marginBottom: '0.15rem' }}
            >
              <Avatar src={account.profile_photo} name={account.full_name} size={28} />
              <div style={{ minWidth: 0, flex: 1 }}>
                <div style={{ fontWeight: 600, fontSize: '0.82rem', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', color: 'inherit' }}>
                  {account.full_name ?? account.email}
                </div>
                {account.full_name && (
                  <div style={{ fontSize: '0.68rem', color: 'var(--color-muted)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {account.email}
                  </div>
                )}
              </div>
            </NavLink>
          )}
          <button
            onClick={handleLogout}
            className="verifia-nav-item"
            style={{ color: '#ef4444' }}
          >
            <LogOutIcon />
            <span>{t('nav.logout')}</span>
          </button>
          <LangToggle />
        </div>
      </aside>

      {/* ── Mobile topbar ────────────────────────────────────────────────── */}
      <div className="verifia-topbar">
        <div style={{ fontWeight: 800, fontSize: '1rem', color: 'var(--color-text)' }}>
          Verifi<span style={{ color: 'var(--color-accent)' }}>A</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <LangToggle />
          <Avatar src={account?.profile_photo ?? null} name={account?.full_name ?? null} size={30} />
        </div>
      </div>

      {/* ── Push permission prompt ───────────────────────────────────────── */}
      {showPushPrompt && (
        <div style={{
          position: 'fixed', bottom: 80, right: 16, zIndex: 490,
          background: 'var(--color-surface)', border: '1px solid rgba(0,234,242,0.3)',
          borderRadius: 14, padding: '1rem 1.1rem', maxWidth: 320,
          boxShadow: '0 8px 32px rgba(0,0,0,0.4)', animation: 'slideDown 0.35s ease',
        }}>
          <div style={{ fontWeight: 700, fontSize: '0.88rem', color: 'var(--color-text)', marginBottom: '0.35rem' }}>
            🔔 Notificaciones
          </div>
          <div style={{ fontSize: '0.8rem', color: 'var(--color-muted)', marginBottom: '0.85rem', lineHeight: 1.4 }}>
            Activa las notificaciones para recibir alertas cuando alguien complete una verificación.
          </div>
          <div style={{ display: 'flex', gap: '0.5rem' }}>
            <button
              onClick={() => {
                setShowPushPrompt(false);
                void requestPushPermission();
              }}
              style={{
                flex: 1, padding: '0.45rem 0.75rem', borderRadius: 8,
                background: 'rgba(0,234,242,0.15)', border: '1px solid rgba(0,234,242,0.35)',
                color: 'var(--color-accent)', cursor: 'pointer', fontSize: '0.8rem', fontWeight: 600,
              }}
            >
              Activar
            </button>
            <button
              onClick={() => setShowPushPrompt(false)}
              style={{
                padding: '0.45rem 0.75rem', borderRadius: 8,
                background: 'transparent', border: '1px solid var(--color-border)',
                color: 'var(--color-muted)', cursor: 'pointer', fontSize: '0.8rem',
              }}
            >
              {t('dismiss')}
            </button>
          </div>
        </div>
      )}

      {/* ── Main content ─────────────────────────────────────────────────── */}
      <main className="verifia-main">
        <Outlet />
      </main>

      {/* ── Mobile bottom nav ────────────────────────────────────────────── */}
      <nav className="verifia-bottom-nav">
        {NAV_ITEMS.map(({ to, label, Icon, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            className={({ isActive }) => `verifia-bottom-nav-item${isActive ? ' active' : ''}`}
          >
            <div style={{ position: 'relative' }}>
              <Icon />
              {(badgeCounts[to] ?? 0) > 0 && (
                <span style={{
                  position: 'absolute',
                  top: -4,
                  right: -6,
                  width: 14,
                  height: 14,
                  borderRadius: 7,
                  background: '#ef4444',
                  border: '2px solid var(--color-surface)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '0.55rem',
                  fontWeight: 700,
                  color: '#fff',
                  lineHeight: 1,
                }}>
                  {badgeCounts[to]}
                </span>
              )}
            </div>
            <span>{label}</span>
          </NavLink>
        ))}
      </nav>
    </div>
  );
}

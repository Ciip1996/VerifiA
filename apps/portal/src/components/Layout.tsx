import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useEffect } from 'react';
import { useAuth } from '../context/AuthContext.tsx';
import { useInbox } from '../context/InboxContext.tsx';
import { useSentChanges } from '../context/SentChangesContext.tsx';

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

// ── Nav items config ──────────────────────────────────────────────────────────

const NAV_ITEMS = [
  { to: '/', label: 'Verificar', Icon: ShieldIcon, end: true },
  { to: '/solicitudes', label: 'Solicitudes', Icon: BellIcon, end: false },
  { to: '/buscar', label: 'Buscar', Icon: SearchIcon, end: false },
  { to: '/perfil', label: 'Mi perfil', Icon: UserIcon, end: false },
] as const;

// ── Layout ────────────────────────────────────────────────────────────────────

export function Layout() {
  const { account, logout } = useAuth();
  const { unseenCount, isOffline, latestNew, consumeLatestNew } = useInbox();
  const { latestChange, consumeLatestChange } = useSentChanges();
  const navigate = useNavigate();

  function handleLogout() {
    logout();
    navigate('/login', { replace: true });
  }

  const badgeCounts: Record<string, number> = {
    '/solicitudes': unseenCount,
  };

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
          Sin conexión con el servidor
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
            <strong>{latestNew.requester.full_name ?? latestNew.requester.email}</strong> te solicita verificar tu identidad
          </span>
          <button onClick={consumeLatestNew} style={{ background: 'none', border: 'none', color: 'var(--color-muted)', cursor: 'pointer', fontSize: '0.8rem', padding: '0.2rem 0.4rem' }}>Descartar</button>
          <button onClick={() => { navigate('/solicitudes'); consumeLatestNew(); }} style={{ background: 'rgba(0,234,242,0.15)', border: '1px solid rgba(0,234,242,0.3)', color: 'var(--color-accent)', cursor: 'pointer', fontSize: '0.8rem', fontWeight: 600, padding: '0.3rem 0.7rem', borderRadius: 7 }}>Ver</button>
        </div>
      )}

      {/* ── Sent-change banner ───────────────────────────────────────────── */}
      {latestChange && !latestNew && (
        <div style={{
          position: 'fixed', top: isOffline ? 36 : 0, left: 0, right: 0, zIndex: 498,
          background: 'var(--color-surface)', borderBottom: '1px solid rgba(245,158,11,0.35)',
          padding: '0.6rem 1rem', display: 'flex', alignItems: 'center', gap: '0.75rem',
          animation: 'slideDown 0.35s ease', boxShadow: '0 4px 20px rgba(0,0,0,0.3)',
        }}>
          <span style={{ fontSize: '0.85rem', color: 'var(--color-text)', flex: 1 }}>
            <strong>{latestChange.targetEmail ?? 'Alguien'}</strong>{' '}
            {latestChange.newStatus === 'REJECTED' ? 'rechazó' : 'canceló'} tu solicitud de verificación.
          </span>
          <button onClick={consumeLatestChange} style={{ background: 'none', border: 'none', color: 'var(--color-muted)', cursor: 'pointer', fontSize: '0.8rem', padding: '0.2rem 0.4rem' }}>Descartar</button>
          <button onClick={() => { navigate('/solicitudes'); consumeLatestChange(); }} style={{ background: 'rgba(245,158,11,0.12)', border: '1px solid rgba(245,158,11,0.3)', color: '#f59e0b', cursor: 'pointer', fontSize: '0.8rem', fontWeight: 600, padding: '0.3rem 0.7rem', borderRadius: 7 }}>Ver</button>
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
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <div style={{
              width: 30,
              height: 30,
              borderRadius: 8,
              background: 'linear-gradient(135deg, #00EAF2, #147BFF)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              flexShrink: 0,
            }}>
              <VerifyIcon />
            </div>
            <div>
              <div style={{ fontWeight: 800, fontSize: '0.95rem', color: 'var(--color-text)', letterSpacing: '-0.3px' }}>
                Verifi<span style={{ color: 'var(--color-accent)' }}>A</span>
              </div>
              <div style={{ fontSize: '0.62rem', color: 'var(--color-muted)', letterSpacing: 0.3 }}>
                PORTAL DE IDENTIDAD
              </div>
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
            <span>Cerrar sesión</span>
          </button>
        </div>
      </aside>

      {/* ── Mobile topbar ────────────────────────────────────────────────── */}
      <div className="verifia-topbar">
        <div style={{ fontWeight: 800, fontSize: '1rem', color: 'var(--color-text)' }}>
          Verifi<span style={{ color: 'var(--color-accent)' }}>A</span>
        </div>
        <Avatar src={account?.profile_photo ?? null} name={account?.full_name ?? null} size={30} />
      </div>

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

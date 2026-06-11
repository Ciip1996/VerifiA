import { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { searchAccounts, type AccountSearchResult } from '../api/client.ts';

export function SearchPage() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<AccountSearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [searched, setSearched] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const navigate = useNavigate();

  // Focus on mount
  useEffect(() => { inputRef.current?.focus(); }, []);

  // Debounced search
  useEffect(() => {
    if (query.length < 2) {
      setResults([]);
      setSearched(false);
      setError(null);
      return;
    }
    const timer = setTimeout(async () => {
      setLoading(true);
      setError(null);
      try {
        const res = await searchAccounts(query);
        setResults(res.results);
        setSearched(true);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Error en la búsqueda');
        setSearched(true);
      } finally {
        setLoading(false);
      }
    }, 350);
    return () => clearTimeout(timer);
  }, [query]);

  return (
    <div style={{ maxWidth: 680, margin: '0 auto', padding: '2rem 1.5rem' }}>
      {/* Page header */}
      <div style={{ marginBottom: '1.75rem' }}>
        <h1 style={{ fontSize: '1.35rem', fontWeight: 700, color: 'var(--color-text)', marginBottom: '0.25rem' }}>
          Buscar usuarios
        </h1>
        <p style={{ fontSize: '0.88rem', color: 'var(--color-muted)' }}>
          Encuentra usuarios registrados en VerifiA y solicita su verificación.
        </p>
      </div>

      {/* Search bar */}
      <div style={{ position: 'relative', marginBottom: '1.5rem' }}>
        <div style={{ position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)', color: 'var(--color-muted)', pointerEvents: 'none' }}>
          <SearchIcon />
        </div>
        <input
          ref={inputRef}
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Buscar por nombre o correo…"
          style={{
            width: '100%',
            padding: '0.75rem 0.9rem 0.75rem 2.75rem',
            background: 'var(--color-surface)',
            border: '1px solid var(--color-border)',
            borderRadius: 12,
            color: 'var(--color-text)',
            fontSize: '0.95rem',
            outline: 'none',
            transition: 'border-color 0.15s',
          }}
          onFocus={(e) => (e.target.style.borderColor = 'rgba(108,99,255,0.6)')}
          onBlur={(e) => (e.target.style.borderColor = 'var(--color-border)')}
        />
        {loading && (
          <div style={{ position: 'absolute', right: 14, top: '50%', transform: 'translateY(-50%)' }}>
            <div style={{ width: 18, height: 18, border: '2px solid rgba(108,99,255,0.3)', borderTopColor: '#6c63ff', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
          </div>
        )}
      </div>

      {/* Results */}
      {error && (
        <div style={{ padding: '0.7rem 0.9rem', background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.3)', borderRadius: 8, color: '#ef4444', fontSize: '0.85rem', marginBottom: '1rem' }}>
          {error}
        </div>
      )}

      {!searched && !loading && (
        <div style={{ textAlign: 'center', padding: '3rem 1rem', color: 'var(--color-muted)' }}>
          <div style={{ fontSize: '2rem', marginBottom: '0.75rem' }}>🔍</div>
          <div style={{ fontSize: '0.9rem' }}>Escribe al menos 2 caracteres para buscar</div>
        </div>
      )}

      {searched && results.length === 0 && !loading && !error && (
        <div style={{ textAlign: 'center', padding: '3rem 1rem', color: 'var(--color-muted)' }}>
          <div style={{ fontSize: '2rem', marginBottom: '0.75rem' }}>👤</div>
          <div style={{ fontWeight: 600, fontSize: '0.95rem', color: 'var(--color-text)', marginBottom: '0.4rem' }}>Sin resultados</div>
          <div style={{ fontSize: '0.85rem' }}>No se encontraron usuarios con "{query}"</div>
        </div>
      )}

      {results.length > 0 && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.6rem' }}>
          <div style={{ fontSize: '0.75rem', color: 'var(--color-muted)', marginBottom: '0.25rem' }}>
            {results.length} resultado{results.length !== 1 ? 's' : ''}
          </div>
          {results.map((user) => (
            <UserCard
              key={user.id}
              user={user}
              onClick={() => navigate(`/buscar/${user.id}`)}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function UserCard({ user, onClick }: { user: AccountSearchResult; onClick: () => void }) {
  const [hovered, setHovered] = useState(false);

  return (
    <div
      onClick={onClick}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '0.9rem',
        padding: '0.85rem 1rem',
        background: hovered ? 'rgba(255,255,255,0.04)' : 'var(--color-surface)',
        border: `1px solid ${hovered ? 'rgba(108,99,255,0.4)' : 'var(--color-border)'}`,
        borderRadius: 12,
        cursor: 'pointer',
        transition: 'border-color 0.15s, background 0.15s',
      }}
    >
      <UserAvatar src={user.profile_photo} name={user.full_name} size={46} />

      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.15rem', flexWrap: 'wrap' }}>
          <span style={{ fontWeight: 600, fontSize: '0.92rem', color: 'var(--color-text)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
            {user.full_name ?? user.email}
          </span>
          {user.is_self && (
            <span style={{ fontSize: '0.68rem', color: '#a8a4ff', background: 'rgba(108,99,255,0.15)', padding: '1px 7px', borderRadius: 10, fontWeight: 600, flexShrink: 0 }}>
              Tú
            </span>
          )}
          {user.id_type && (
            <span style={{ fontSize: '0.68rem', color: 'var(--color-muted)', background: 'rgba(255,255,255,0.06)', padding: '1px 7px', borderRadius: 10, flexShrink: 0 }}>
              {user.id_type === 'INE' ? 'INE' : 'Pasaporte'}
            </span>
          )}
        </div>
        <div style={{ fontSize: '0.78rem', color: 'var(--color-muted)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
          {user.email}
        </div>
        {user.facetec_match_level != null && (
          <div style={{ marginTop: '0.25rem' }}>
            <span style={{
              fontSize: '0.68rem', fontWeight: 600,
              color: user.facetec_match_level >= 70 ? '#22c55e' : '#f59e0b',
            }}>
              Match ID: {user.facetec_match_level}/100
            </span>
          </div>
        )}
      </div>

      <div style={{ color: 'var(--color-muted)', flexShrink: 0, fontSize: '0.9rem' }}>›</div>
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

function SearchIcon() {
  return (
    <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="11" cy="11" r="8" />
      <line x1="21" y1="21" x2="16.65" y2="16.65" />
    </svg>
  );
}

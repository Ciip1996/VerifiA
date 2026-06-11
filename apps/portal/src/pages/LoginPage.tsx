import { useState, FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { login } from '../api/client.ts';
import { useAuth } from '../context/AuthContext.tsx';

export function LoginPage() {
  const { login: storeLogin } = useAuth();
  const navigate = useNavigate();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await login(email.trim(), password);
      storeLogin(res.session_token, res.account);
      navigate('/', { replace: true });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Error al iniciar sesión');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{
      minHeight: '100vh',
      background: 'var(--color-bg)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '1.5rem',
    }}>
      <div style={{
        width: '100%',
        maxWidth: 400,
        background: 'var(--color-surface)',
        borderRadius: 16,
        border: '1px solid var(--color-border)',
        padding: '2.5rem 2rem',
        boxShadow: '0 8px 32px rgba(0,0,0,0.24)',
      }}>
        {/* Logo / brand */}
        <div style={{ textAlign: 'center', marginBottom: '2rem' }}>
          <div style={{
            width: 56,
            height: 56,
            borderRadius: '50%',
            background: 'rgba(108,99,255,0.15)',
            border: '2px solid rgba(108,99,255,0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            margin: '0 auto 1rem',
            fontSize: 26,
          }}>
            🛡️
          </div>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 700, color: 'var(--color-text)', margin: 0 }}>
            VerifiA
          </h1>
          <p style={{ color: 'var(--color-muted)', fontSize: '0.9rem', marginTop: '0.4rem' }}>
            Inicia sesión con tu cuenta verificada
          </p>
        </div>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <div>
            <label style={{ display: 'block', fontSize: '0.82rem', color: 'var(--color-muted)', marginBottom: '0.35rem', fontWeight: 600 }}>
              Correo electrónico
            </label>
            <input
              type="email"
              value={email}
              onChange={e => setEmail(e.target.value)}
              placeholder="tu@email.com"
              required
              autoFocus
              style={{
                width: '100%',
                padding: '0.7rem 0.85rem',
                borderRadius: 10,
                border: '1.5px solid var(--color-border)',
                background: 'var(--color-bg)',
                color: 'var(--color-text)',
                fontSize: '0.95rem',
                outline: 'none',
                boxSizing: 'border-box',
              }}
            />
          </div>

          <div>
            <label style={{ display: 'block', fontSize: '0.82rem', color: 'var(--color-muted)', marginBottom: '0.35rem', fontWeight: 600 }}>
              Contraseña
            </label>
            <input
              type="password"
              value={password}
              onChange={e => setPassword(e.target.value)}
              placeholder="••••••••"
              required
              style={{
                width: '100%',
                padding: '0.7rem 0.85rem',
                borderRadius: 10,
                border: '1.5px solid var(--color-border)',
                background: 'var(--color-bg)',
                color: 'var(--color-text)',
                fontSize: '0.95rem',
                outline: 'none',
                boxSizing: 'border-box',
              }}
            />
          </div>

          {error && (
            <div style={{
              padding: '0.65rem 0.85rem',
              borderRadius: 8,
              background: 'rgba(239,68,68,0.1)',
              border: '1px solid rgba(239,68,68,0.3)',
              color: '#ef4444',
              fontSize: '0.85rem',
            }}>
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            style={{
              padding: '0.8rem',
              borderRadius: 10,
              border: 'none',
              background: '#6c63ff',
              color: '#fff',
              fontSize: '0.95rem',
              fontWeight: 700,
              cursor: loading ? 'not-allowed' : 'pointer',
              opacity: loading ? 0.7 : 1,
              marginTop: '0.5rem',
            }}
          >
            {loading ? 'Iniciando sesión…' : 'Iniciar sesión'}
          </button>
        </form>

        <p style={{ textAlign: 'center', color: 'var(--color-muted)', fontSize: '0.82rem', marginTop: '1.5rem', lineHeight: 1.5 }}>
          ¿No tienes cuenta? Regístrate desde la app móvil de VerifiA escaneando tu INE con FaceTec.
        </p>
      </div>
    </div>
  );
}

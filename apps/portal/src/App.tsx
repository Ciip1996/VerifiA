import { Routes, Route, Navigate } from 'react-router-dom';
import { VerifierPage } from './pages/VerifierPage.tsx';
import { LoginPage } from './pages/LoginPage.tsx';
import { useAuth } from './context/AuthContext.tsx';

function AuthGuard({ children }: { children: React.ReactNode }) {
  const { sessionToken, loading } = useAuth();
  if (loading) return null;
  if (!sessionToken) return <Navigate to="/login" replace />;
  return <>{children}</>;
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/"
        element={
          <AuthGuard>
            <VerifierPage />
          </AuthGuard>
        }
      />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

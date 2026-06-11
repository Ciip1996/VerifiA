import { Routes, Route, Navigate } from 'react-router-dom';
import { Layout } from './components/Layout.tsx';
import { VerifierPage } from './pages/VerifierPage.tsx';
import { SolicitudesPage } from './pages/SolicitudesPage.tsx';
import { SearchPage } from './pages/SearchPage.tsx';
import { PublicProfilePage } from './pages/PublicProfilePage.tsx';
import { ProfilePage } from './pages/ProfilePage.tsx';
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
            <Layout />
          </AuthGuard>
        }
      >
        <Route index element={<VerifierPage />} />
        <Route path="solicitudes" element={<SolicitudesPage />} />
        <Route path="buscar" element={<SearchPage />} />
        <Route path="buscar/:accountId" element={<PublicProfilePage />} />
        <Route path="perfil" element={<ProfilePage />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

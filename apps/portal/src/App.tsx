import { Routes, Route, Navigate } from 'react-router-dom';
import { VerifierPage } from './pages/VerifierPage.tsx';

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<VerifierPage />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

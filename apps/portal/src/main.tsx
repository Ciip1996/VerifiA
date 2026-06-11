import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App.tsx';
import { AuthProvider } from './context/AuthContext.tsx';
import { InboxProvider } from './context/InboxContext.tsx';
import './index.css';

const root = document.getElementById('root');
if (!root) throw new Error('#root element not found');

createRoot(root).render(
  <StrictMode>
    <BrowserRouter>
      <AuthProvider>
        <InboxProvider>
          <App />
        </InboxProvider>
      </AuthProvider>
    </BrowserRouter>
  </StrictMode>
);

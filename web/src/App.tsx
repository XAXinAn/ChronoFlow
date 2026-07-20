import { Suspense, lazy } from 'react';
import { HashRouter, Routes, Route, Navigate } from 'react-router-dom';
import Layout from './components/Layout';
import LoginPage from './pages/LoginPage';

const FeedbacksPage = lazy(() => import('./pages/FeedbacksPage'));
const FeedbackDetailPage = lazy(() => import('./pages/FeedbackDetailPage'));
const UsersPage = lazy(() => import('./pages/UsersPage'));
const GroupsPage = lazy(() => import('./pages/GroupsPage'));
const MessagesPage = lazy(() => import('./pages/MessagesPage'));

const Loading = () => <p style={{ color: '#999', textAlign: 'center', padding: 40 }}>加载中...</p>;

function AuthGuard({ children }: { children: React.ReactNode }) {
  const stored = localStorage.getItem('admin_token');
  if (!stored) return <Navigate to="/login" replace />;
  return <Layout>{children}</Layout>;
}

export default function App() {
  return (
    <HashRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/feedbacks" element={<AuthGuard><Suspense fallback={<Loading />}><FeedbacksPage /></Suspense></AuthGuard>} />
        <Route path="/feedbacks/:id" element={<AuthGuard><Suspense fallback={<Loading />}><FeedbackDetailPage /></Suspense></AuthGuard>} />
        <Route path="/users" element={<AuthGuard><Suspense fallback={<Loading />}><UsersPage /></Suspense></AuthGuard>} />
        <Route path="/groups" element={<AuthGuard><Suspense fallback={<Loading />}><GroupsPage /></Suspense></AuthGuard>} />
        <Route path="/messages" element={<AuthGuard><Suspense fallback={<Loading />}><MessagesPage /></Suspense></AuthGuard>} />
        <Route path="*" element={<Navigate to="/feedbacks" replace />} />
      </Routes>
    </HashRouter>
  );
}

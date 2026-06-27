import { HashRouter, Routes, Route, Navigate } from 'react-router-dom';
import Layout from './components/Layout';
import LoginPage from './pages/LoginPage';
import FeedbacksPage from './pages/FeedbacksPage';
import FeedbackDetailPage from './pages/FeedbackDetailPage';
import UsersPage from './pages/UsersPage';
import GroupsPage from './pages/GroupsPage';
import SchedulesPage from './pages/SchedulesPage';

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
        <Route path="/feedbacks" element={<AuthGuard><FeedbacksPage /></AuthGuard>} />
        <Route path="/feedbacks/:id" element={<AuthGuard><FeedbackDetailPage /></AuthGuard>} />
        <Route path="/users" element={<AuthGuard><UsersPage /></AuthGuard>} />
        <Route path="/groups" element={<AuthGuard><GroupsPage /></AuthGuard>} />
        <Route path="/schedules" element={<AuthGuard><SchedulesPage /></AuthGuard>} />
        <Route path="*" element={<Navigate to="/feedbacks" replace />} />
      </Routes>
    </HashRouter>
  );
}

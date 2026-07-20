import { NavLink, useNavigate } from 'react-router-dom';

export default function Layout({ children }: { children: React.ReactNode }) {
  const navigate = useNavigate();
  const stored = localStorage.getItem('admin_token');
  const user = stored ? JSON.parse(stored) : null;

  const logout = () => {
    localStorage.removeItem('admin_token');
    navigate('/login');
  };

  return (
    <div style={{ display: 'flex', minHeight: '100vh' }}>
      <aside style={{
        width: 220, background: '#1a1a1a', color: '#fff',
        display: 'flex', flexDirection: 'column', flexShrink: 0,
      }}>
        <div style={{ padding: '20px 16px', fontSize: 18, fontWeight: 700, borderBottom: '1px solid #333' }}>
          ChronoFlow
        </div>
        <nav style={{ flex: 1, padding: '8px 0' }}>
          <NavLink to="/feedbacks" style={navStyle}>反馈管理</NavLink>
          <NavLink to="/users" style={navStyle}>用户管理</NavLink>
          <NavLink to="/groups" style={navStyle}>群组管理</NavLink>
          <NavLink to="/messages" style={navStyle}>消息通知</NavLink>
        </nav>
        <div style={{ padding: 16, borderTop: '1px solid #333', fontSize: 13, color: '#999' }}>
          {user?.nickname || user?.username || '管理员'}
          <button onClick={logout} style={{ ...btnStyle, width: '100%', marginTop: 8 }}>退出登录</button>
        </div>
      </aside>
      <main style={{ flex: 1, background: '#f5f5f5', padding: 24, overflow: 'auto' }}>
        {children}
      </main>
    </div>
  );
}

const navStyle = ({ isActive }: { isActive: boolean }) => ({
  display: 'block', padding: '10px 16px', color: isActive ? '#fff' : '#999',
  background: isActive ? '#333' : 'transparent',
  textDecoration: 'none', fontSize: 14, borderLeft: isActive ? '3px solid #fff' : '3px solid transparent',
});

const btnStyle: React.CSSProperties = {
  background: '#444', color: '#fff', border: 'none', padding: '6px 12px',
  borderRadius: 4, cursor: 'pointer', fontSize: 12,
};

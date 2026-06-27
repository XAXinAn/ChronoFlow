import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api/client';

export default function LoginPage() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const login = async () => {
    if (!username || !password) { setError('请输入用户名和密码'); return; }
    setLoading(true);
    setError('');
    try {
      const res = await api.post('/admin/login', { username, password });
      const data = res.data.data || res.data;
      localStorage.setItem('admin_token', JSON.stringify(data));
      navigate('/feedbacks');
    } catch (e: any) {
      setError(e.response?.data?.message || '登录失败');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '100vh', background: '#f5f5f5' }}>
      <div style={{ width: 360, padding: 32, background: '#fff', borderRadius: 12, boxShadow: '0 2px 12px rgba(0,0,0,0.08)' }}>
        <h2 style={{ textAlign: 'center', marginBottom: 24, fontWeight: 600 }}>ChronoFlow 管理后台</h2>
        <input style={inputStyle} placeholder="用户名" value={username} onChange={e => setUsername(e.target.value)} onKeyDown={e => e.key === 'Enter' && login()} />
        <input style={inputStyle} type="password" placeholder="密码" value={password} onChange={e => setPassword(e.target.value)} onKeyDown={e => e.key === 'Enter' && login()} />
        {error && <p style={{ color: '#e74c3c', fontSize: 13, margin: '8px 0' }}>{error}</p>}
        <button disabled={loading} onClick={login} style={{
          width: '100%', padding: 10, marginTop: 12, background: '#1a1a1a', color: '#fff',
          border: 'none', borderRadius: 6, fontSize: 15, cursor: 'pointer',
        }}>
          {loading ? '登录中...' : '登录'}
        </button>
      </div>
    </div>
  );
}

const inputStyle: React.CSSProperties = {
  width: '100%', padding: 10, marginBottom: 12, border: '1px solid #ddd',
  borderRadius: 6, fontSize: 14, outline: 'none', boxSizing: 'border-box',
};

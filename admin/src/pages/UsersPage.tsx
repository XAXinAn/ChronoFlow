import { useEffect, useState } from 'react';
import api from '../api/client';
import Pagination from '../components/Pagination';
import type { User } from '../types/user';

export default function UsersPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [toast, setToast] = useState('');

  const load = async (p = 1) => {
    setLoading(true);
    setError('');
    try {
      const res = await api.get('/admin/users', { params: { page: p, size: 20 } });
      const d = res.data.data || res.data;
      setUsers(d.records || []);
      setTotal(d.total || 0);
      setPage(p);
    } catch (e: any) {
      setError(e.response?.data?.message || '加载失败');
    } finally { setLoading(false); }
  };

  useEffect(() => { load(); }, []);

  const changeRole = async (userId: number, role: string) => {
    if (!confirm(`确定将用户 ${userId} 的角色改为 ${role}？`)) return;
    try {
      await api.post(`/admin/users/${userId}/role`, { role });
      setToast('角色已更新');
      load();
    } catch { setToast('操作失败'); }
  };

  if (loading) return <p style={{ color: '#999', textAlign: 'center', padding: 40 }}>加载中...</p>;
  if (error) return <p style={{ color: '#e74c3c', textAlign: 'center', padding: 40 }}>{error} <button onClick={() => load()} style={{ cursor: 'pointer', background: 'none', border: 'none', color: '#2980b9' }}>重试</button></p>;

  return (
    <div>
      <h2 style={{ fontSize: 22, fontWeight: 600, marginBottom: 16 }}>用户管理</h2>
      {users.map(u => (
        <div key={u.id} style={cardStyle}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <strong style={{ fontSize: 15 }}>{u.nickname || u.username}</strong>
              <span style={{ fontSize: 13, color: '#999', marginLeft: 8 }}>@{u.username}</span>
              {u.realNameVerified && <span style={{ fontSize: 12, color: '#27ae60', marginLeft: 8 }}>✓ 已实名</span>}
            </div>
            <span style={{
              padding: '2px 10px', borderRadius: 12, fontSize: 12, fontWeight: 500,
              color: u.role === 'ADMIN' ? '#8e44ad' : '#7f8c8d',
              background: u.role === 'ADMIN' ? '#f3eaf8' : '#f0f0f0',
            }}>
              {u.role}
            </span>
          </div>
          <div style={{ fontSize: 13, color: '#666', marginTop: 6 }}>
            #{u.id} · {u.phone} · {u.email || '无邮箱'}
          </div>
          <button onClick={() => changeRole(u.id, u.role === 'ADMIN' ? 'USER' : 'ADMIN')}
            style={{
              marginTop: 8, padding: '4px 12px', fontSize: 12, cursor: 'pointer',
              background: u.role === 'ADMIN' ? '#e74c3c' : '#27ae60', color: '#fff',
              border: 'none', borderRadius: 4,
            }}>
            {u.role === 'ADMIN' ? '降级为普通用户' : '升级为管理员'}
          </button>
        </div>
      ))}
      <Pagination page={page} total={total} size={20} onChange={load} />
      {toast && (
        <div style={{ position: 'fixed', bottom: 24, right: 24, padding: '10px 20px', borderRadius: 8, background: '#333', color: '#fff', fontSize: 14 }}
          onClick={() => setToast('')}>{toast}</div>
      )}
    </div>
  );
}

const cardStyle: React.CSSProperties = {
  background: '#fff', padding: 16, marginBottom: 10, borderRadius: 8, border: '1px solid #eee',
};

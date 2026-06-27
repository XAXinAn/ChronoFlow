import { useEffect, useState, useCallback } from 'react';
import api from '../api/client';
import Pagination from '../components/Pagination';

export default function UsersPage() {
  const [users, setUsers] = useState<any[]>([]);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [keyword, setKeyword] = useState('');

  const load = useCallback(async (p = 1) => {
    setLoading(true);
    try {
      const res = await api.get('/admin/users', { params: { page: p, size: 20, keyword: keyword || undefined } });
      const d = res.data.data || res.data;
      setUsers(d.records || []);
      setTotal(d.total || 0);
      setPage(p);
    } catch {} finally { setLoading(false); }
  }, [keyword]);

  useEffect(() => { load(); }, [load]);

  return (
    <div>
      <h2 style={{ fontSize: 22, fontWeight: 600, marginBottom: 16 }}>用户管理</h2>
      <input placeholder="搜索用户名/昵称/手机/邮箱..." value={keyword} onChange={e => setKeyword(e.target.value)}
        onKeyDown={e => e.key === 'Enter' && load()}
        style={{ width: '100%', padding: '8px 12px', marginBottom: 12, border: '1px solid #ddd', borderRadius: 6, fontSize: 13, outline: 'none', boxSizing: 'border-box' }} />
      <table style={{ width: '100%', borderCollapse: 'collapse', background: '#fff', borderRadius: 8 }}>
        <thead><tr style={{ background: '#f5f5f5', textAlign: 'left' }}>
          <th style={th}>ID</th><th style={th}>用户名</th><th style={th}>昵称</th><th style={th}>手机</th><th style={th}>邮箱</th><th style={th}>实名</th><th style={th}>注册时间</th>
        </tr></thead>
        <tbody>{users.map(u => (
          <tr key={u.id} style={{ borderBottom: '1px solid #eee' }}>
            <td style={td}>{u.id}</td><td style={td}>{u.username}</td><td style={td}>{u.nickname}</td>
            <td style={td}>{u.phone}</td><td style={td}>{u.email || '-'}</td>
            <td style={td}>{u.realNameVerified ? '✓' : '-'}</td><td style={td}>{u.createdAt?.slice(0, 10)}</td>
          </tr>
        ))}</tbody>
      </table>
      <Pagination page={page} total={total} size={20} onChange={load} />
    </div>
  );
}
const th: React.CSSProperties = { padding: '10px 12px', fontSize: 13, fontWeight: 600, color: '#666' };
const td: React.CSSProperties = { padding: '10px 12px', fontSize: 13, color: '#333' };

import { useEffect, useState, useCallback } from 'react';
import api from '../api/client';
import Pagination from '../components/Pagination';

export default function UsersPage() {
  const [users, setUsers] = useState<any[]>([]);
  const [page, setPage] = useState(1);
  const [size, setSize] = useState(20);
  const [total, setTotal] = useState(0);
  const [keyword, setKeyword] = useState('');
  const [loading, setLoading] = useState(false);

  const load = useCallback(async (p = 1) => {
    setLoading(true);
    try {
      const res = await api.get('/admin/users', { params: { page: p, size, keyword: keyword || undefined } });
      const d = res.data.data || res.data;
      setUsers(d.records || []);
      setTotal(d.total || 0);
      setPage(p);
    } catch {} finally { setLoading(false); }
  }, [keyword, size]);

  useEffect(() => { load(); }, [load]);

  const resetPassword = async (id: number, username: string) => {
    if (!confirm(`确定将用户「${username}」的密码重置为 SJL123 吗？`)) return;
    try {
      await api.post(`/admin/users/${id}/reset-password`);
      alert('密码已重置为 SJL123');
    } catch (e: any) {
      alert(e.response?.data?.message || '操作失败');
    }
  };

  const deleteUser = async (id: number, username: string) => {
    if (!confirm(`确定删除用户「${username}」吗？\n此操作不可恢复，该用户的群组将转让给其他成员或解散。`)) return;
    try {
      await api.delete(`/admin/users/${id}`);
      alert('删除成功');
      load(page);
    } catch (e: any) {
      alert(e.response?.data?.message || '删除失败');
    }
  };

  return (
    <div>
      <h2 style={{ fontSize: 22, fontWeight: 600, marginBottom: 16 }}>用户管理</h2>

      <div style={{ display: 'flex', gap: 12, marginBottom: 16, alignItems: 'center' }}>
        <input
          placeholder="搜索用户名 / 昵称 / 手机 / 邮箱..."
          value={keyword}
          onChange={e => setKeyword(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && load()}
          style={searchStyle}
        />
        <span style={{ fontSize: 12, color: '#999', whiteSpace: 'nowrap' }}>共 {total} 人</span>
      </div>

      {loading ? (
        <p style={{ color: '#999', textAlign: 'center', padding: 40 }}>加载中...</p>
      ) : users.length === 0 ? (
        <p style={{ color: '#999', textAlign: 'center', padding: 40 }}>暂无用户</p>
      ) : (
        <table style={{ width: '100%', borderCollapse: 'collapse', background: '#fff', borderRadius: 8, overflow: 'hidden' }}>
          <thead>
            <tr style={{ background: '#f5f5f5', textAlign: 'left' }}>
              <th style={th}>ID</th>
              <th style={th}>用户名</th>
              <th style={th}>昵称</th>
              <th style={th}>手机</th>
              <th style={th}>邮箱</th>
              <th style={th}>实名</th>
              <th style={th}>注册时间</th>
              <th style={{ ...th, width: 140 }}>操作</th>
            </tr>
          </thead>
          <tbody>
            {users.map(u => (
              <tr key={u.id} style={{ borderBottom: '1px solid #eee' }}>
                <td style={td}>{u.id}</td>
                <td style={td}>{u.username}</td>
                <td style={td}>{u.nickname}</td>
                <td style={td}>{u.phone || '-'}</td>
                <td style={td}>{u.email || '-'}</td>
                <td style={td}>{u.realNameVerified ? '✓ 已认证' : '未认证'}</td>
                <td style={td}>{u.createdAt?.slice(0, 10)}</td>
                <td style={td}>
                  <button onClick={() => resetPassword(u.id, u.username)} style={actionBtn}>重置密码</button>
                  <button onClick={() => deleteUser(u.id, u.username)} style={{ ...actionBtn, color: '#e74c3c' }}>删除</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <Pagination page={page} total={total} size={size} onChange={load} onSizeChange={s => setSize(s)} />
    </div>
  );
}

const searchStyle: React.CSSProperties = {
  flex: 1, padding: '8px 12px', border: '1px solid #ddd', borderRadius: 6,
  fontSize: 13, outline: 'none', boxSizing: 'border-box',
};

const th: React.CSSProperties = {
  padding: '10px 12px', fontSize: 12, fontWeight: 600, color: '#999', textTransform: 'uppercase',
};

const td: React.CSSProperties = {
  padding: '10px 12px', fontSize: 13, color: '#333',
};

const actionBtn: React.CSSProperties = {
  background: 'none', border: '1px solid #ddd', borderRadius: 4,
  cursor: 'pointer', fontSize: 11, color: '#333', padding: '4px 10px', marginRight: 6,
};

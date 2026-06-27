import { useEffect, useState, useCallback } from 'react';
import api from '../api/client';
import Pagination from '../components/Pagination';

export default function GroupsPage() {
  const [groups, setGroups] = useState<any[]>([]);
  const [page, setPage] = useState(1);
  const [size, setSize] = useState(20);
  const [total, setTotal] = useState(0);
  const [keyword, setKeyword] = useState('');

  const load = useCallback(async (p = 1) => {
    try {
      const res = await api.get('/admin/groups', { params: { page: p, size, keyword: keyword || undefined } });
      const d = res.data.data || res.data;
      setGroups(d.records || []);
      setTotal(d.total || 0);
      setPage(p);
    } catch {}
  }, [keyword, size]);

  useEffect(() => { load(); }, [load]);

  return (
    <div>
      <h2 style={{ fontSize: 22, fontWeight: 600, marginBottom: 16 }}>群组管理</h2>
      <input placeholder="搜索群组名称..." value={keyword} onChange={e => setKeyword(e.target.value)}
        onKeyDown={e => e.key === 'Enter' && load()}
        style={{ width: '100%', padding: '8px 12px', marginBottom: 12, border: '1px solid #ddd', borderRadius: 6, fontSize: 13, outline: 'none', boxSizing: 'border-box' }} />
      <table style={{ width: '100%', borderCollapse: 'collapse', background: '#fff', borderRadius: 8 }}>
        <thead><tr style={{ background: '#f5f5f5', textAlign: 'left' }}>
          <th style={th}>ID</th><th style={th}>名称</th><th style={th}>创建者</th><th style={th}>成员</th><th style={th}>层级</th><th style={th}>父群组</th><th style={th}>创建时间</th>
        </tr></thead>
        <tbody>{groups.map(g => (
          <tr key={g.id} style={{ borderBottom: '1px solid #eee' }}>
            <td style={td}>{g.id?.slice(0, 8)}</td><td style={td}>{g.name}</td>
            <td style={td}>#{g.creatorId}</td><td style={td}>{g.memberCount}</td>
            <td style={td}>{g.depth ?? 0}</td><td style={td}>{g.parentId?.slice(0, 8) || '-'}</td>
            <td style={td}>{g.createdAt?.slice(0, 10)}</td>
          </tr>
        ))}</tbody>
      </table>
      <Pagination page={page} total={total} size={size} onChange={load} onSizeChange={s => setSize(s)} />
    </div>
  );
}
const th: React.CSSProperties = { padding: '10px 12px', fontSize: 13, fontWeight: 600, color: '#666' };
const td: React.CSSProperties = { padding: '10px 12px', fontSize: 13, color: '#333' };

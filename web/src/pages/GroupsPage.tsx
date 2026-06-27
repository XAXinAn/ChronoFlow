import { useEffect, useState } from 'react';
import api from '../api/client';
import Pagination from '../components/Pagination';

export default function GroupsPage() {
  const [groups, setGroups] = useState<any[]>([]);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);

  const load = async (p = 1) => {
    setLoading(true);
    try {
      const res = await api.get('/admin/groups', { params: { page: p, size: 20 } });
      const d = res.data.data || res.data;
      setGroups(d.records || []);
      setTotal(d.total || 0);
      setPage(p);
    } catch {} finally { setLoading(false); }
  };
  useEffect(() => { load(); }, []);

  if (loading) return <p style={{ color: '#999', textAlign: 'center', padding: 40 }}>加载中...</p>;

  return (
    <div>
      <h2 style={{ fontSize: 22, fontWeight: 600, marginBottom: 16 }}>群组管理</h2>
      {groups.map(g => (
        <div key={g.id} style={cardStyle}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <strong style={{ fontSize: 15 }}>{g.name}</strong>
              <span style={{ fontSize: 12, color: g.parentId ? '#2980b9' : '#27ae60', marginLeft: 8 }}>
                {g.parentId ? '子群组' : '根群组'}
              </span>
            </div>
            <span style={{ fontSize: 13, color: '#999' }}>{g.memberCount} 人</span>
          </div>
          <div style={{ fontSize: 13, color: '#666', marginTop: 6 }}>
            #{g.id?.slice(0, 8)} · 创建者 #{g.creatorId} · L{g.depth ?? 0} · {g.createdAt?.slice(0, 10)}
          </div>
        </div>
      ))}
      <Pagination page={page} total={total} size={20} onChange={load} />
    </div>
  );
}

const cardStyle: React.CSSProperties = {
  background: '#fff', padding: 16, marginBottom: 10, borderRadius: 8, border: '1px solid #eee',
};

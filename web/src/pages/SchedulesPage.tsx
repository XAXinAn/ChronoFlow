import { useEffect, useState } from 'react';
import api from '../api/client';
import Pagination from '../components/Pagination';

export default function SchedulesPage() {
  const [schedules, setSchedules] = useState<any[]>([]);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);

  const load = async (p = 1) => {
    setLoading(true);
    try {
      const res = await api.get('/admin/schedules', { params: { page: p, size: 20 } });
      const d = res.data.data || res.data;
      setSchedules(d.records || []);
      setTotal(d.total || 0);
      setPage(p);
    } catch {} finally { setLoading(false); }
  };
  useEffect(() => { load(); }, []);

  if (loading) return <p style={{ color: '#999', textAlign: 'center', padding: 40 }}>加载中...</p>;

  return (
    <div>
      <h2 style={{ fontSize: 22, fontWeight: 600, marginBottom: 16 }}>日程管理</h2>
      {schedules.map(s => (
        <div key={s.id} style={cardStyle}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <strong style={{ fontSize: 15 }}>{s.title}</strong>
            <span style={{ fontSize: 12, color: s.groupId ? '#2980b9' : '#7f8c8d',
              background: s.groupId ? '#eaf2f8' : '#f0f0f0', padding: '2px 8px', borderRadius: 10 }}>
              {s.groupName || '个人'}
            </span>
          </div>
          <div style={{ fontSize: 13, color: '#666', marginTop: 6 }}>
            用户 #{s.userId} · {s.scheduleTime?.slice(0, 16)} · {s.location || '无地点'}
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

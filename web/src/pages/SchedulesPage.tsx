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
      <table style={{ width: '100%', borderCollapse: 'collapse', background: '#fff', borderRadius: 8, overflow: 'hidden' }}>
        <thead>
          <tr style={{ background: '#f5f5f5', textAlign: 'left' }}>
            <th style={th}>ID</th><th style={th}>标题</th><th style={th}>用户</th><th style={th}>群组</th><th style={th}>时间</th><th style={th}>地点</th>
          </tr>
        </thead>
        <tbody>
          {schedules.map(s => (
            <tr key={s.id} style={{ borderBottom: '1px solid #eee' }}>
              <td style={td}>{s.id}</td>
              <td style={td}>{s.title}</td>
              <td style={td}>#{s.userId}</td>
              <td style={td}>{s.groupName || (s.groupId ? '#' + s.groupId?.slice(0, 8) : '个人')}</td>
              <td style={td}>{s.scheduleTime?.slice(0, 16)}</td>
              <td style={td}>{s.location || '-'}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <Pagination page={page} total={total} size={20} onChange={load} />
    </div>
  );
}
const th: React.CSSProperties = { padding: '10px 12px', fontSize: 13, fontWeight: 600, color: '#666' };
const td: React.CSSProperties = { padding: '10px 12px', fontSize: 13, color: '#333' };

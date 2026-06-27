import { useEffect, useState, useCallback } from 'react';
import api from '../api/client';
import Pagination from '../components/Pagination';

export default function SchedulesPage() {
  const [schedules, setSchedules] = useState<any[]>([]);
  const [page, setPage] = useState(1);
  const [size, setSize] = useState(20);
  const [total, setTotal] = useState(0);
  const [keyword, setKeyword] = useState('');
  const [showCreate, setShowCreate] = useState(false);
  const [editId, setEditId] = useState<number | null>(null);
  const [form, setForm] = useState({ userId: '', title: '', description: '', location: '', scheduleTime: '' });

  const load = useCallback(async (p = 1) => {
    try {
      const res = await api.get('/admin/schedules', { params: { page: p, size, keyword: keyword || undefined } });
      const d = res.data.data || res.data;
      setSchedules(d.records || []);
      setTotal(d.total || 0);
      setPage(p);
    } catch {}
  }, [keyword, size]);

  useEffect(() => { load(); }, [load]);

  const resetForm = () => setForm({ userId: '', title: '', description: '', location: '', scheduleTime: '' });
  const del = async (id: number) => {
    if (!confirm('确定删除该日程？')) return;
    try { await api.delete(`/admin/schedules/${id}`); load(); } catch (e: any) { alert(e.response?.data?.message || '删除失败'); }
  };
  const create = async () => {
    try { await api.post('/admin/schedules', form); setShowCreate(false); resetForm(); load(); } catch {}
  };
  const saveEdit = async () => {
    if (!editId) return;
    try { await api.put(`/admin/schedules/${editId}`, form); setEditId(null); resetForm(); load(); } catch {}
  };
  const startEdit = (s: any) => {
    setEditId(s.id);
    setForm({ userId: String(s.userId || ''), title: s.title || '', description: s.description || '', location: s.location || '', scheduleTime: s.scheduleTime?.slice(0, 16) || '' });
  };

  const f = (k: string, v: string) => setForm({ ...form, [k]: v });

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
        <h2 style={{ fontSize: 22, fontWeight: 600, margin: 0 }}>日程管理</h2>
        <button onClick={() => { resetForm(); setShowCreate(true); }} style={{ padding: '6px 16px', background: '#1a1a1a', color: '#fff', border: 'none', borderRadius: 6, fontWeight:500, cursor: 'pointer' }}>+ 新建日程</button>
      </div>
      <input placeholder="搜索标题/描述..." value={keyword} onChange={e => setKeyword(e.target.value)} onKeyDown={e => e.key === 'Enter' && load()}
        style={{ width: '100%', padding: '8px 12px', marginBottom: 12, border: '1px solid #ddd', borderRadius: 6, fontSize: 13, outline: 'none', boxSizing: 'border-box' }} />

      {/* Create Modal */}
      {showCreate && <Modal title="新建日程" form={form} f={f} onSave={create} onClose={() => setShowCreate(false)} />}
      {/* Edit Modal */}
      {editId && <Modal title="编辑日程" form={form} f={f} onSave={saveEdit} onClose={() => setEditId(null)} />}

      <table style={{ width: '100%', borderCollapse: 'collapse', background: '#fff', borderRadius: 8 }}>
        <thead><tr style={{ background: '#f5f5f5', textAlign: 'left' }}>
          <th style={th}>ID</th><th style={th}>标题</th><th style={th}>用户</th><th style={th}>群组</th><th style={th}>时间</th><th style={th}>地点</th><th style={th}>创建时间</th><th style={th}>操作</th>
        </tr></thead>
        <tbody>{schedules.map(s => (
          <tr key={s.id} style={{ borderBottom: '1px solid #eee' }}>
            <td style={td}>{s.id}</td><td style={td}>{s.title}</td>
            <td style={td}>#{s.userId}</td>
            <td style={td}>{s.groupName || (s.groupId ? '#' + s.groupId?.slice(0, 8) : '个人')}</td>
            <td style={td}>{s.scheduleTime?.slice(0, 16)}</td>
            <td style={td}>{s.location || '-'}</td>
            <td style={td}>{s.createdAt?.slice(0, 10)}</td>
            <td style={td}>
              <button onClick={() => startEdit(s)} style={actBtn}>编辑</button>
              <button onClick={() => del(s.id)} style={{ ...actBtn, color: '#e74c3c' }}>删除</button>
            </td>
          </tr>
        ))}</tbody>
      </table>
      <Pagination page={page} total={total} size={size} onChange={load} onSizeChange={s => setSize(s)} />
    </div>
  );
}

function Modal({ title, form, f, onSave, onClose }: { title: string; form: any; f: (k: string, v: string) => void; onSave: () => void; onClose: () => void }) {
  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.3)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100 }}>
      <div style={{ background: '#fff', padding: 24, borderRadius: 12, width: 420, boxShadow: '0 4px 20px rgba(0,0,0,0.15)' }}>
        <h3 style={{ margin: '0 0 16px' }}>{title}</h3>
        <input placeholder="用户ID" value={form.userId} onChange={e => f('userId', e.target.value)} style={inputStyle} />
        <input placeholder="标题" value={form.title} onChange={e => f('title', e.target.value)} style={inputStyle} />
        <input placeholder="描述" value={form.description} onChange={e => f('description', e.target.value)} style={inputStyle} />
        <input placeholder="地点" value={form.location} onChange={e => f('location', e.target.value)} style={inputStyle} />
        <input type="datetime-local" value={form.scheduleTime} onChange={e => f('scheduleTime', e.target.value)} style={inputStyle} />
        <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end', marginTop: 16 }}>
          <button onClick={onClose} style={{ padding: '6px 16px', background: '#eee', border: 'none', borderRadius: 6, cursor: 'pointer' }}>取消</button>
          <button onClick={onSave} style={{ padding: '6px 16px', background: '#1a1a1a', color: '#fff', border: 'none', borderRadius: 6, cursor: 'pointer' }}>保存</button>
        </div>
      </div>
    </div>
  );
}

const inputStyle: React.CSSProperties = { width: '100%', padding: '8px 10px', marginBottom: 8, border: '1px solid #ddd', borderRadius: 6, fontSize: 13, outline: 'none', boxSizing: 'border-box' };
const th: React.CSSProperties = { padding: '10px 12px', fontSize: 13, fontWeight: 600, color: '#666' };
const td: React.CSSProperties = { padding: '10px 12px', fontSize: 13, color: '#333' };
const actBtn: React.CSSProperties = { background: 'none', border: 'none', cursor: 'pointer', fontSize: 12, color: '#2980b9', padding: '2px 6px' };

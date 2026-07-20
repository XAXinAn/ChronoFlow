import { useEffect, useState, useCallback } from 'react';
import api from '../api/client';
import Pagination from '../components/Pagination';

export default function GroupsPage() {
  const [groups, setGroups] = useState<any[]>([]);
  const [page, setPage] = useState(1);
  const [size, setSize] = useState(20);
  const [total, setTotal] = useState(0);
  const [keyword, setKeyword] = useState('');
  const [editId, setEditId] = useState<string | null>(null);
  const [editName, setEditName] = useState('');
  const [loading, setLoading] = useState(false);

  const load = useCallback(async (p = 1) => {
    setLoading(true);
    try {
      const res = await api.get('/admin/groups', { params: { page: p, size, keyword: keyword || undefined } });
      const d = res.data.data || res.data;
      setGroups(d.records || []);
      setTotal(d.total || 0);
      setPage(p);
    } catch {} finally { setLoading(false); }
  }, [keyword, size]);

  useEffect(() => { load(); }, [load]);

  const del = async (id: string, name: string) => {
    if (!confirm(`确定删除群组「${name}」吗？`)) return;
    try {
      await api.delete(`/admin/groups/${id}`);
      alert('删除成功');
      load(page);
    } catch (e: any) {
      alert(e.response?.data?.message || '删除失败');
    }
  };

  const saveEdit = async () => {
    if (!editId || !editName.trim()) return;
    try {
      await api.put(`/admin/groups/${editId}`, { name: editName.trim() });
      setEditId(null);
      load(page);
    } catch {}
  };

  return (
    <div>
      <h2 style={{ fontSize: 22, fontWeight: 600, marginBottom: 16 }}>群组管理</h2>

      <div style={{ display: 'flex', gap: 12, marginBottom: 16, alignItems: 'center' }}>
        <input
          placeholder="搜索群组名称..."
          value={keyword}
          onChange={e => setKeyword(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && load()}
          style={searchStyle}
        />
        <span style={{ fontSize: 12, color: '#999', whiteSpace: 'nowrap' }}>共 {total} 个群组</span>
      </div>

      {loading ? (
        <p style={{ color: '#999', textAlign: 'center', padding: 40 }}>加载中...</p>
      ) : groups.length === 0 ? (
        <p style={{ color: '#999', textAlign: 'center', padding: 40 }}>暂无群组</p>
      ) : (
        <table style={{ width: '100%', borderCollapse: 'collapse', background: '#fff', borderRadius: 8, overflow: 'hidden' }}>
          <thead>
            <tr style={{ background: '#f5f5f5', textAlign: 'left' }}>
              <th style={th}>群组名称</th>
              <th style={th}>成员数</th>
              <th style={th}>层级</th>
              <th style={th}>创建时间</th>
              <th style={{ ...th, width: 120 }}>操作</th>
            </tr>
          </thead>
          <tbody>
            {groups.map(g => (
              <tr key={g.id} style={{ borderBottom: '1px solid #eee' }}>
                <td style={td}>
                  {editId === g.id ? (
                    <input
                      value={editName}
                      onChange={e => setEditName(e.target.value)}
                      onKeyDown={e => e.key === 'Enter' && saveEdit()}
                      style={{ width: 160, padding: '4px 8px', fontSize: 13, border: '1px solid #333', borderRadius: 4 }}
                      autoFocus
                    />
                  ) : (
                    <span style={{ fontWeight: 500 }}>{g.name}</span>
                  )}
                </td>
                <td style={td}>{g.memberCount} 人</td>
                <td style={td}>{g.depth != null ? `${g.depth} 级` : '顶级'}</td>
                <td style={td}>{g.createdAt?.slice(0, 10)}</td>
                <td style={td}>
                  {editId === g.id ? (
                    <span>
                      <button onClick={saveEdit} style={actionBtn}>保存</button>
                      <button onClick={() => setEditId(null)} style={{ ...actionBtn, border: '1px solid #ddd', color: '#999' }}>取消</button>
                    </span>
                  ) : (
                    <span>
                      <button onClick={() => { setEditId(g.id); setEditName(g.name); }} style={actionBtn}>编辑</button>
                      <button onClick={() => del(g.id, g.name)} style={{ ...actionBtn, color: '#e74c3c' }}>删除</button>
                    </span>
                  )}
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

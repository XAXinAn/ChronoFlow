import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api/client';
import StatusBadge from '../components/StatusBadge';
import Pagination from '../components/Pagination';
import type { Feedback } from '../types/feedback';

export default function FeedbacksPage() {
  const [feedbacks, setFeedbacks] = useState<Feedback[]>([]);
  const [page, setPage] = useState(1);
  const [size, setSize] = useState(20);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [status, setStatus] = useState('');
  const [type, setType] = useState('');
  const [keyword, setKeyword] = useState('');
  const navigate = useNavigate();

  const load = async (p = 1) => {
    setLoading(true);
    setError('');
    try {
      const res = await api.get('/admin/feedbacks', { params: { page: p, size, status: status || undefined, type: type || undefined, keyword: keyword || undefined } });
      const d = res.data.data || res.data;
      setFeedbacks(d.records || []);
      setTotal(d.total || 0);
      setPage(p);
    } catch (e: any) {
      setError(e.response?.data?.message || '加载失败');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, [status, type, keyword, size]);

  if (loading) return <p style={{ color: '#999', textAlign: 'center', padding: 40 }}>加载中...</p>;
  if (error) return <p style={{ color: '#e74c3c', textAlign: 'center', padding: 40 }}>{error} <button onClick={() => load()} style={{ cursor: 'pointer', background: 'none', border: 'none', color: '#2980b9' }}>重试</button></p>;

  return (
    <div>
      <h2 style={{ fontSize: 22, fontWeight: 600, marginBottom: 16 }}>反馈管理</h2>
      <div style={{ display: 'flex', gap: 12, marginBottom: 16 }}>
        <select value={status} onChange={e => setStatus(e.target.value)} style={selectStyle}>
          <option value="">全部状态</option>
          <option value="pending">待处理</option>
          <option value="processing">处理中</option>
          <option value="resolved">已解决</option>
          <option value="closed">已关闭</option>
        </select>
        <select value={type} onChange={e => setType(e.target.value)} style={selectStyle}>
          <option value="">全部类型</option>
          <option value="bug">Bug</option>
          <option value="suggestion">建议</option>
          <option value="other">其他</option>
        </select>
        <input placeholder="搜索内容..." value={keyword} onChange={e => setKeyword(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && load()}
          style={{ padding: '6px 12px', border: '1px solid #ddd', borderRadius: 6, fontSize: 13, outline: 'none', flex: 1, boxSizing: 'border-box' }} />
      </div>
      {feedbacks.length === 0 ? (
        <p style={{ color: '#999', textAlign: 'center', padding: 40 }}>暂无反馈</p>
      ) : (
        feedbacks.map(f => (
          <div key={f.id} onClick={() => navigate(`/feedbacks/${f.id}`)} style={cardStyle}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
              <span style={{ fontSize: 12, color: '#999' }}>#{f.id} · 用户 {f.userId}</span>
              <StatusBadge status={f.status} />
            </div>
            <p style={{ fontSize: 14, color: '#333', margin: '0 0 4px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
              {f.content}
            </p>
            <div style={{ fontSize: 12, color: '#999', display: 'flex', gap: 12 }}>
              <span>📁 {f.type === 'bug' ? 'Bug' : f.type === 'suggestion' ? '建议' : '其他'}</span>
              {f.imageUrls.length > 0 && <span>🖼 {f.imageUrls.length} 张图片</span>}
              <span>{f.createdAt?.slice(0, 10)}</span>
            </div>
          </div>
        ))
      )}
      <Pagination page={page} total={total} size={size} onChange={load} onSizeChange={s => setSize(s)} />
    </div>
  );
}

const cardStyle: React.CSSProperties = {
  background: '#fff', padding: 16, marginBottom: 10, borderRadius: 8,
  border: '1px solid #eee', cursor: 'pointer',
};
const selectStyle: React.CSSProperties = {
  padding: '6px 12px', border: '1px solid #ddd', borderRadius: 6, fontSize: 13, background: '#fff',
};

import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import api from '../api/client';
import StatusBadge from '../components/StatusBadge';
import type { Feedback } from '../types/feedback';

export default function FeedbackDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [feedback, setFeedback] = useState<Feedback | null>(null);
  const [loading, setLoading] = useState(true);
  const [reply, setReply] = useState('');
  const [sending, setSending] = useState(false);
  const [toast, setToast] = useState('');

  const load = async () => {
    setLoading(true);
    try {
      const res = await api.get(`/admin/feedbacks/${id}`);
      setFeedback((res.data.data || res.data) as Feedback);
    } catch { setToast('加载失败'); } finally { setLoading(false); }
  };

  useEffect(() => { load(); }, [id]);

  const updateStatus = async (status: string) => {
    try {
      await api.post(`/admin/feedbacks/${id}/status`, { status });
      setToast('状态已更新');
      load();
    } catch { setToast('更新失败'); }
  };

  const submitReply = async () => {
    if (!reply.trim()) return;
    setSending(true);
    try {
      await api.post(`/admin/feedbacks/${id}/reply`, { reply: reply.trim() });
      setToast('回复已发送');
      setReply('');
      load();
    } catch { setToast('回复失败'); } finally { setSending(false); }
  };

  if (loading) return <p style={{ color: '#999', textAlign: 'center', padding: 40 }}>加载中...</p>;
  if (!feedback) return <p style={{ color: '#999', textAlign: 'center', padding: 40 }}>反馈不存在</p>;

  return (
    <div style={{ maxWidth: 720 }}>
      <button onClick={() => navigate('/feedbacks')} style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: 14, color: '#2980b9', marginBottom: 12 }}>
        ← 返回列表
      </button>

      {/* 头部 */}
      <div style={{ background: '#fff', padding: 20, borderRadius: 10, border: '1px solid #eee', marginBottom: 12 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
          <span style={{ fontSize: 13, color: '#999' }}>#{feedback.id} · 用户 {feedback.userId} · {feedback.createdAt?.slice(0, 16)}</span>
          <StatusBadge status={feedback.status} />
        </div>
        <span style={{
          display: 'inline-block', padding: '2px 8px', borderRadius: 4, fontSize: 12,
          background: '#f0f0f0', color: '#666', marginBottom: 8,
        }}>
          {feedback.type === 'bug' ? 'Bug 反馈' : feedback.type === 'suggestion' ? '功能建议' : '其他'}
        </span>
        <p style={{ fontSize: 15, lineHeight: 1.6, whiteSpace: 'pre-wrap', margin: 0 }}>{feedback.content}</p>
      </div>

      {/* 图片 */}
      {feedback.imageUrls.length > 0 && (
        <div style={{ background: '#fff', padding: 16, borderRadius: 10, border: '1px solid #eee', marginBottom: 12 }}>
          <h4 style={{ margin: '0 0 8px', fontSize: 14 }}>📷 附件图片 ({feedback.imageUrls.length})</h4>
          <div style={{ display: 'flex', gap: 8, overflow: 'auto' }}>
            {feedback.imageUrls.map((url, i) => (
              <a key={i} href={url} target="_blank" rel="noopener noreferrer">
                <img src={url} alt={`图片 ${i + 1}`} style={{ width: 100, height: 100, objectFit: 'cover', borderRadius: 6, border: '1px solid #eee' }} />
              </a>
            ))}
          </div>
        </div>
      )}

      {/* 状态管理 */}
      <div style={{ background: '#fff', padding: 16, borderRadius: 10, border: '1px solid #eee', marginBottom: 12 }}>
        <h4 style={{ margin: '0 0 8px', fontSize: 14 }}>状态管理</h4>
        <div style={{ display: 'flex', gap: 8 }}>
          {['pending', 'processing', 'resolved', 'closed'].map(s => {
            const labels: Record<string, string> = { pending: '待处理', processing: '处理中', resolved: '已解决', closed: '已关闭' };
            return (
              <button key={s} onClick={() => updateStatus(s)}
                style={{
                  padding: '4px 14px', borderRadius: 14, fontSize: 13, cursor: 'pointer', border: '1px solid #ddd',
                  background: feedback.status === s ? '#1a1a1a' : '#fff',
                  color: feedback.status === s ? '#fff' : '#333',
                }}>
                {labels[s]}
              </button>
            );
          })}
        </div>
      </div>

      {/* 回复 */}
      {feedback.adminReply ? (
        <div style={{ background: '#f8fafb', padding: 16, borderRadius: 10, border: '1px solid #e0e0e0', marginBottom: 12 }}>
          <h4 style={{ margin: '0 0 6px', fontSize: 14 }}>💬 管理员回复</h4>
          <p style={{ fontSize: 14, whiteSpace: 'pre-wrap', margin: 0 }}>{feedback.adminReply}</p>
        </div>
      ) : (
        <div style={{ background: '#fff', padding: 16, borderRadius: 10, border: '1px solid #eee', marginBottom: 12 }}>
          <h4 style={{ margin: '0 0 8px', fontSize: 14 }}>💬 回复反馈</h4>
          <textarea value={reply} onChange={e => setReply(e.target.value)} placeholder="输入回复内容..."
            style={{ width: '100%', minHeight: 100, padding: 10, border: '1px solid #ddd', borderRadius: 6, fontSize: 14, resize: 'vertical', boxSizing: 'border-box' }} />
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 8 }}>
            <span style={{ fontSize: 12, color: '#999' }}>{reply.length}/1000</span>
            <button onClick={submitReply} disabled={sending || !reply.trim()}
              style={{ padding: '8px 20px', background: '#1a1a1a', color: '#fff', border: 'none', borderRadius: 6, cursor: 'pointer', fontSize: 14 }}>
              {sending ? '发送中...' : '发送回复'}
            </button>
          </div>
        </div>
      )}

      {toast && (
        <div style={{
          position: 'fixed', bottom: 24, right: 24, padding: '10px 20px', borderRadius: 8,
          background: '#333', color: '#fff', fontSize: 14,
        }} onClick={() => setToast('')}>{toast}</div>
      )}
    </div>
  );
}

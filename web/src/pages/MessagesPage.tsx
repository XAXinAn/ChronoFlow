import { useEffect, useState, useCallback } from 'react';
import api from '../api/client';

function getAdminId(): number {
  const stored = localStorage.getItem('admin_token');
  if (!stored) return 0;
  try { return JSON.parse(stored).userId || 0; } catch { return 0; }
}

export default function MessagesPage() {
  const [messages, setMessages] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [showSend, setShowSend] = useState(false);
  const [detail, setDetail] = useState<any>(null);
  const [receiverId, setReceiverId] = useState('');
  const [sendToAll, setSendToAll] = useState(false);
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [replyContent, setReplyContent] = useState('');
  const adminId = getAdminId();

  const load = useCallback(async () => {
    if (!adminId) return;
    setLoading(true);
    try {
      const res = await api.get('/admin/messages', { params: { adminId } });
      const d = res.data.data || res.data;
      setMessages(d || []);
    } catch {} finally { setLoading(false); }
  }, [adminId]);

  useEffect(() => { load(); }, [load]);

  const send = async () => {
    if (!sendToAll && !receiverId) { alert('请输入用户ID或勾选发送给全部用户'); return; }
    if (!title.trim() || !content.trim()) { alert('请填写标题和内容'); return; }
    try {
      const body: any = { adminId, title: title.trim(), content: content.trim() };
      if (sendToAll) {
        body.receiverId = 'all';
      } else {
        body.receiverId = Number(receiverId);
      }
      await api.post('/admin/messages', body);
      alert(sendToAll ? '已发送给全部用户' : '发送成功');
      setShowSend(false); setReceiverId(''); setSendToAll(false); setTitle(''); setContent('');
      load();
    } catch (e: any) { alert(e.response?.data?.message || '发送失败'); }
  };

  const openDetail = async (id: number) => {
    try {
      const res = await api.get(`/admin/messages/${id}`, { params: { adminId } });
      setDetail(res.data.data || res.data);
    } catch {}
  };

  const reply = async () => {
    if (!detail || !replyContent.trim()) return;
    try {
      await api.post(`/messages/${detail.id}/reply`, { content: replyContent.trim() });
      alert('回复成功');
      setReplyContent('');
      openDetail(detail.id);
    } catch (e: any) { alert(e.response?.data?.message || '回复失败'); }
  };

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
        <h2 style={{ fontSize: 22, fontWeight: 600, margin: 0 }}>消息通知</h2>
        <button onClick={() => setShowSend(!showSend)} style={sendBtn}>
          {showSend ? '取消' : '+ 发送消息'}
        </button>
      </div>

      {showSend && (
        <div style={modalStyle}>
          <h3 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>发送新消息</h3>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 10 }}>
            <input placeholder="接收用户 ID" value={receiverId} onChange={e => setReceiverId(e.target.value)}
              disabled={sendToAll} style={{ ...inputStyle, marginBottom: 0, flex: 1 }} />
            <label style={{ display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer', whiteSpace: 'nowrap', fontSize: 13, color: '#333' }}>
              <input type="checkbox" checked={sendToAll} onChange={e => setSendToAll(e.target.checked)}
                style={{ width: 16, height: 16, cursor: 'pointer' }} />
              发送给全部用户
            </label>
          </div>
          <input placeholder="消息标题" value={title} onChange={e => setTitle(e.target.value)} style={inputStyle} />
          <textarea placeholder="消息内容" value={content} onChange={e => setContent(e.target.value)} rows={4} style={{ ...inputStyle, resize: 'vertical' }} />
          <button onClick={send} style={{ ...sendBtn, width: '100%' }}>确认发送</button>
        </div>
      )}

      {loading ? <p style={{ color: '#999', textAlign: 'center', padding: 40 }}>加载中...</p>
       : messages.length === 0 ? <p style={{ color: '#999', textAlign: 'center', padding: 40 }}>暂无消息</p>
       : (
        <table style={{ width: '100%', borderCollapse: 'collapse', background: '#fff', borderRadius: 8, overflow: 'hidden' }}>
          <thead>
            <tr style={{ background: '#f5f5f5', textAlign: 'left' }}>
              <th style={th}>接收用户</th>
              <th style={th}>标题</th>
              <th style={th}>内容</th>
              <th style={th}>状态</th>
              <th style={th}>回复</th>
              <th style={th}>时间</th>
              <th style={th}>操作</th>
            </tr>
          </thead>
          <tbody>
            {messages.map(m => (
              <tr key={m.id} style={{ borderBottom: '1px solid #eee' }}>
                <td style={td}>#{m.receiverId} {m.receiverName}</td>
                <td style={td}>{m.title}</td>
                <td style={{ ...td, maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{m.content}</td>
                <td style={td}>{m.isRead ? '已读' : '未读'}</td>
                <td style={td}>{m.replyCount} 条</td>
                <td style={td}>{m.createdAt?.slice(0, 16)}</td>
                <td style={td}>
                  <button onClick={() => openDetail(m.id)} style={actionBtn}>详情</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {detail && (
        <div style={overlayStyle} onClick={() => setDetail(null)}>
          <div style={detailStyle} onClick={e => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <h3 style={{ margin: 0, fontSize: 18 }}>{detail.title}</h3>
              <button onClick={() => setDetail(null)} style={closeBtn}>✕</button>
            </div>
            <p style={{ color: '#666', fontSize: 14, marginBottom: 20, lineHeight: 1.6, whiteSpace: 'pre-wrap' }}>{detail.content}</p>

            {(detail.replies || []).length > 0 && (
              <div style={{ marginBottom: 16 }}>
                <h4 style={{ fontSize: 14, color: '#999', marginBottom: 8 }}>回复记录</h4>
                {detail.replies.map((r: any) => (
                  <div key={r.id} style={{ background: '#f9f9f9', padding: 10, borderRadius: 6, marginBottom: 6 }}>
                    <div style={{ fontSize: 11, color: '#999', marginBottom: 4 }}>{r.isAdmin ? '管理员' : '用户'} · {r.createdAt?.slice(0, 16)}</div>
                    <div style={{ fontSize: 13, color: '#333', whiteSpace: 'pre-wrap' }}>{r.content}</div>
                  </div>
                ))}
              </div>
            )}

            {detail.canReply && (
              <div>
                <textarea placeholder="输入回复..." value={replyContent} onChange={e => setReplyContent(e.target.value)} rows={2}
                  style={{ ...inputStyle, width: '100%', resize: 'vertical', marginBottom: 8 }} />
                <button onClick={reply} style={{ ...sendBtn, width: '100%' }}>回复</button>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

const th: React.CSSProperties = { padding: '10px 12px', fontSize: 12, fontWeight: 600, color: '#999', textTransform: 'uppercase' };
const td: React.CSSProperties = { padding: '10px 12px', fontSize: 13, color: '#333' };
const actionBtn: React.CSSProperties = { background: 'none', border: '1px solid #ddd', borderRadius: 4, cursor: 'pointer', fontSize: 11, color: '#333', padding: '4px 10px' };
const sendBtn: React.CSSProperties = { background: '#1a1a1a', color: '#fff', border: 'none', padding: '8px 20px', borderRadius: 6, fontSize: 13, cursor: 'pointer' };
const inputStyle: React.CSSProperties = { width: '100%', padding: '8px 12px', border: '1px solid #ddd', borderRadius: 6, fontSize: 13, outline: 'none', marginBottom: 10, boxSizing: 'border-box' };
const modalStyle: React.CSSProperties = { background: '#fff', padding: 20, borderRadius: 8, border: '1px solid #eee', marginBottom: 16 };
const overlayStyle: React.CSSProperties = { position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.4)', display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 1000 };
const detailStyle: React.CSSProperties = { background: '#fff', padding: 24, borderRadius: 12, width: 560, maxHeight: '80vh', overflow: 'auto' };
const closeBtn: React.CSSProperties = { background: 'none', border: 'none', fontSize: 18, cursor: 'pointer', color: '#999' };

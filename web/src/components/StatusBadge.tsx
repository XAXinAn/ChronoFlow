const statusMap: Record<string, { label: string; color: string; bg: string }> = {
  pending:    { label: '待处理', color: '#e67e22', bg: '#fef3e2' },
  processing: { label: '处理中', color: '#2980b9', bg: '#eaf2f8' },
  resolved:   { label: '已解决', color: '#27ae60', bg: '#eafaf1' },
  closed:     { label: '已关闭', color: '#7f8c8d', bg: '#f0f0f0' },
};

export default function StatusBadge({ status }: { status: string }) {
  const s = statusMap[status] || statusMap.pending;
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 4,
      padding: '2px 10px', borderRadius: 12, fontSize: 12, fontWeight: 500,
      color: s.color, background: s.bg,
    }}>
      <span style={{ width: 6, height: 6, borderRadius: '50%', background: s.color }} />
      {s.label}
    </span>
  );
}

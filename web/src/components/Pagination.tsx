export default function Pagination({
  page, total, size, onChange, onSizeChange,
}: {
  page: number; total: number; size: number; onChange: (p: number) => void; onSizeChange: (s: number) => void;
}) {
  const totalPages = Math.ceil(total / size) || 1;

  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 12, marginTop: 16 }}>
      <button disabled={page <= 1} onClick={() => onChange(page - 1)} style={btnStyle}>上一页</button>
      <span style={{ fontSize: 13, color: '#666' }}>第 {page}/{totalPages} 页，共 {total} 条</span>
      <button disabled={page >= totalPages} onClick={() => onChange(page + 1)} style={btnStyle}>下一页</button>
      <select value={size} onChange={e => onSizeChange(Number(e.target.value))} style={selectStyle}>
        {[10, 20, 50, 100].map(n => <option key={n} value={n}>{n}条/页</option>)}
      </select>
    </div>
  );
}

const btnStyle: React.CSSProperties = {
  padding: '6px 14px', border: '1px solid #ddd', borderRadius: 4, background: '#fff', cursor: 'pointer', fontSize: 13,
};
const selectStyle: React.CSSProperties = {
  padding: '5px 8px', border: '1px solid #ddd', borderRadius: 4, fontSize: 13, background: '#fff',
};

export default function Pagination({
  page, total, size, onChange,
}: {
  page: number; total: number; size: number; onChange: (p: number) => void;
}) {
  const totalPages = Math.ceil(total / size);
  if (totalPages <= 1) return null;

  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, marginTop: 16 }}>
      <button disabled={page <= 1} onClick={() => onChange(page - 1)} style={btnStyle}>
        上一页
      </button>
      <span style={{ fontSize: 13, color: '#666' }}>
        第 {page} 页，共 {total} 条
      </span>
      <button disabled={page >= totalPages} onClick={() => onChange(page + 1)} style={btnStyle}>
        下一页
      </button>
    </div>
  );
}

const btnStyle: React.CSSProperties = {
  padding: '6px 14px', border: '1px solid #ddd', borderRadius: 4,
  background: '#fff', cursor: 'pointer', fontSize: 13,
};

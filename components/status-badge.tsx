export function StatusBadge({ isActive }: { isActive: boolean }) {
  return (
    <span className={`status-badge ${isActive ? "active" : "inactive"}`}>
      {isActive ? "Ativo" : "Inativo"}
    </span>
  );
}

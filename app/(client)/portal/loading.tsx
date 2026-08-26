export default function PortalLoading() {
  return (
    <main className="app-shell client-portal-shell" aria-busy="true">
      <div className="portal-loading-header" />
      <div className="portal-loading-grid">
        <span />
        <span />
        <span />
        <span />
      </div>
      <div className="portal-loading-panel" />
      <p className="sr-only">Carregando os registros da empresa…</p>
    </main>
  );
}

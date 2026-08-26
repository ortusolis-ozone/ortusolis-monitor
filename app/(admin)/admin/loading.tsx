export default function AdminLoading() {
  return (
    <main className="admin-main" aria-busy="true" aria-live="polite">
      <section className="page-heading loading-heading">
        <p className="eyebrow">Carregando</p>
        <h1>Atualizando o painel...</h1>
        <p>Buscando os dados operacionais mais recentes.</p>
      </section>
      <div className="loading-grid" aria-hidden="true">
        <span />
        <span />
        <span />
      </div>
    </main>
  );
}

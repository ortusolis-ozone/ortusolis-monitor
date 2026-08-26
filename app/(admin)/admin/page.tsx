import Link from "next/link";

import { formatAdminDateTime } from "@/lib/admin/format";
import { getAdminOverview } from "@/lib/admin/queries";

function importStatusLabel(status: string) {
  if (status === "confirmed") return "Confirmada";
  if (status === "failed") return "Falhou";
  return "Processando";
}

export default async function AdminPage() {
  const overview = await getAdminOverview();

  return (
    <main className="admin-main">
      <section className="page-heading page-heading-row">
        <div>
          <p className="eyebrow">Visão geral</p>
          <h1>Painel administrativo</h1>
          <p>
            Acompanhe a operação e acesse rapidamente os fluxos que precisam de
            atenção.
          </p>
        </div>
        <Link className="primary-button" href="/admin/importacoes">
          Nova importação
        </Link>
      </section>

      <section className="metric-grid" aria-label="Indicadores operacionais">
        <Link className="metric-card" href="/admin/clientes">
          <span>Clientes ativos</span>
          <strong>{overview.activeClients.toLocaleString("pt-BR")}</strong>
          <small>Ver clientes e instalações</small>
        </Link>
        <Link className="metric-card" href="/admin/geradores">
          <span>Geradores ativos</span>
          <strong>{overview.activeGenerators.toLocaleString("pt-BR")}</strong>
          <small>Ver geradores e alocações</small>
        </Link>
        <Link
          className={`metric-card ${overview.pendingInconsistencies > 0 ? "attention" : ""}`}
          href="/admin/inconsistencias"
        >
          <span>Inconsistências pendentes</span>
          <strong>
            {overview.pendingInconsistencies.toLocaleString("pt-BR")}
          </strong>
          <small>Revisar pendências</small>
        </Link>
      </section>

      <section className="dashboard-grid">
        <div className="listing-card dashboard-imports">
          <div className="section-title-row">
            <div>
              <p className="eyebrow">Operação recente</p>
              <h2>Últimas importações</h2>
            </div>
            <Link className="secondary-button compact-button" href="/admin/importacoes">
              Ver histórico
            </Link>
          </div>

          {overview.recentImports.length === 0 ? (
            <p className="empty-state">Nenhuma importação registrada ainda.</p>
          ) : (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Arquivo</th>
                    <th>Contexto</th>
                    <th>Resultado</th>
                    <th>Recebido em</th>
                  </tr>
                </thead>
                <tbody>
                  {overview.recentImports.map((batch) => (
                    <tr key={batch.id}>
                      <td>
                        <strong>{batch.fileName}</strong>
                        <small className="table-secondary-line">
                          por {batch.authorName}
                        </small>
                      </td>
                      <td>
                        {batch.clientName} · {batch.locationName}
                        <small className="table-secondary-line">
                          {batch.generatorName} · {batch.controllerName}
                        </small>
                      </td>
                      <td>
                        <span className={`import-status ${batch.status}`}>
                          {importStatusLabel(batch.status)}
                        </span>
                        {batch.status === "failed" ? (
                          <small className="table-secondary-line failure-detail">
                            {batch.errorMessage ?? "Falha sem mensagem registrada."}
                          </small>
                        ) : (
                          <small className="table-secondary-line">
                            {batch.insertedRows.toLocaleString("pt-BR")} inserida(s) ·{" "}
                            {batch.duplicateRows.toLocaleString("pt-BR")} duplicada(s)
                          </small>
                        )}
                      </td>
                      <td>{formatAdminDateTime(batch.createdAt)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        <aside className="listing-card quick-access" aria-labelledby="quick-access-title">
          <div className="section-title-row">
            <div>
              <p className="eyebrow">Cadastros</p>
              <h2 id="quick-access-title">Clientes e instalações</h2>
            </div>
          </div>
          <nav aria-label="Atalhos dos cadastros operacionais">
            <Link href="/admin/clientes">Clientes</Link>
            <Link href="/admin/locais">Unidades</Link>
            <Link href="/admin/camaras">Câmaras</Link>
            <Link href="/admin/geradores">Geradores e alocações</Link>
            <Link href="/admin/controladores">Controladores</Link>
          </nav>
        </aside>
      </section>
    </main>
  );
}

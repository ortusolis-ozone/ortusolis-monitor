import Link from "next/link";

import { correlationLabels, operationalLabels } from "@/lib/admin/power-diagnostic-labels";
import { getAdminApplicationDiagnostics, parseDiagnosticPage } from "@/lib/admin/power-diagnostics";
import { formatPowerDate } from "@/lib/operations/power-profiles/format";

export default async function ApplicationsPage({ searchParams }: {
  searchParams: Promise<{ page?: string }>;
}) {
  const page = parseDiagnosticPage((await searchParams).page);
  const applications = await getAdminApplicationDiagnostics(page);

  return (
    <main className="admin-main">
      <section className="page-heading">
        <p className="eyebrow">Registros importados</p>
        <h1>Aplicações</h1>
        <p>Consulte todas as aplicações identificadas nas importações confirmadas e abra o diagnóstico técnico de cada registro.</p>
      </section>

      <section className="listing-card" aria-labelledby="applications-title">
        <div className="section-title-row">
          <div>
            <p className="eyebrow">Histórico operacional</p>
            <h2 id="applications-title">Aplicações registradas</h2>
          </div>
        </div>
        {applications.length ? (
          <div className="table-wrap"><table>
            <thead><tr><th>Aplicação</th><th>Cliente e instalação</th><th>Gerador</th><th>Início</th><th>Avaliação operacional</th></tr></thead>
            <tbody>{applications.map((application) => <tr key={application.application_id}>
              <td><Link className="text-link" href={`/admin/aplicacoes/${application.application_id}`}>#{application.application_id}</Link></td>
              <td>{application.client_name}<small className="table-secondary-line">{application.location_name} · {application.cold_room_name}</small></td>
              <td><Link className="text-link" href={`/admin/geradores/${application.generator_id}#aplicacoes`}>{application.generator_identifier}</Link></td>
              <td>{formatPowerDate(application.start_at)}</td>
              <td>{operationalLabels[application.operational_status] ?? application.operational_status}<small className="table-secondary-line">{correlationLabels[application.correlation_status] ?? application.correlation_status}</small></td>
            </tr>)}</tbody>
          </table></div>
        ) : <p className="empty-state">Nenhuma aplicação foi identificada nas importações confirmadas.</p>}
        <nav className="filter-actions" aria-label="Páginas de aplicações">
          {page > 0 ? <Link href={`/admin/aplicacoes?page=${page - 1}`}>Página anterior</Link> : null}
          {applications.length === 50 ? <Link href={`/admin/aplicacoes?page=${page + 1}`}>Próxima página</Link> : null}
        </nav>
      </section>
    </main>
  );
}

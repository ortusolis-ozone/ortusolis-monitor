import Link from "next/link";
import { notFound } from "next/navigation";
import { PowerProfileVersionForm } from "@/components/power-profile-version-form";
import { getGeneratorPowerConfigurations, getGeneratorPowerHistory } from "@/lib/operations/power-profiles/queries";
import { formatPower, formatPowerDate } from "@/lib/operations/power-profiles/format";
import { isUuid } from "@/lib/operations/power-profiles/validation";

import { getGeneratorApplicationDiagnostics, parseDiagnosticPage } from "@/lib/admin/power-diagnostics";
import { correlationLabels, operationalLabels } from "@/lib/admin/power-diagnostic-labels";

export default async function GeneratorPowerPage({ params, searchParams }: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ applications_page?: string }>;
}) {
  const { id } = await params;
  if (!isUuid(id)) notFound();
  const page = parseDiagnosticPage((await searchParams).applications_page);
  const [configurations, history, applications] = await Promise.all([
    getGeneratorPowerConfigurations({ generatorId: id }),
    getGeneratorPowerHistory(id),
    getGeneratorApplicationDiagnostics(id, page),
  ]);
  const current = configurations[0];
  if (!current) notFound();
  const openProfile = history.find((profile) => profile.valid_until === null);

  return (
    <main className="admin-main">
      <section className="page-heading page-heading-row">
        <div>
          <p className="eyebrow">Potência do gerador</p>
          <h1>{current.identifier}</h1>
          <p>Configure a referência nominal e acompanhe as vigências sem sobrescrever os valores anteriores.</p>
        </div>
        <Link href="/admin/geradores" className="secondary-button">Voltar aos geradores</Link>
      </section>

      <div className="power-detail-grid">
        <section className="power-detail-card" aria-labelledby="current-power-title">
          <h2 id="current-power-title">Potência vigente</h2>
          <p className={current.power_profile_id ? "power-configured" : "power-pending"}>
            {current.power_profile_id ? "Configurada" : "Configuração pendente"}
          </p>
          <dl className="power-values">
            <div><dt>Potência nominal</dt><dd>{formatPower(current.nominal_power_w)}</dd></div>
            <div><dt>Potência mínima calculada</dt><dd>{formatPower(current.minimum_acceptable_power_w)}</dd></div>
          </dl>
          {current.valid_from ? <p>Vigência: {formatPowerDate(current.valid_from)} — {formatPowerDate(current.valid_until)}</p> : <p>Não há perfil nominal válido neste momento. Nenhum valor é inferido das leituras.</p>}
          <p className="field-hint">O mínimo corresponde a 85% da potência nominal. Os limites de liga/desliga pertencem ao controlador e permanecem separados desta configuração.</p>
        </section>

        <section className="power-detail-card" aria-labelledby="edit-power-title">
          <h2 id="edit-power-title">{openProfile ? "Nova vigência" : "Configurar potência nominal"}</h2>
          {openProfile ? <p>Último perfil aberto: {formatPower(openProfile.nominal_power_w)}, desde {formatPowerDate(openProfile.valid_from)}. Escolha um início posterior.</p> : null}
          {current.is_active ? (
            <PowerProfileVersionForm generatorId={id} expectedProfileId={openProfile?.id ?? null} />
          ) : <p>Reative o gerador para registrar uma nova configuração.</p>}
        </section>
      </div>

      <section className="power-detail-card" aria-labelledby="power-history-title">
        <h2 id="power-history-title">Histórico de potência nominal</h2>
        <p className="field-hint">Horários de Fortaleza (UTC−03:00). O início é inclusivo; o término pertence à próxima vigência.</p>
        {history.length ? <ol className="power-history-list">
          {history.map((profile) => <li key={profile.id}>
            <strong>{formatPower(profile.nominal_power_w)}</strong>
            <span>Mínimo: {formatPower(profile.minimum_acceptable_power_w)}</span>
            <span>{formatPowerDate(profile.valid_from)} — {formatPowerDate(profile.valid_until)}</span>
            {profile.id === current.power_profile_id ? <span className="power-configured">Vigente agora</span> : null}
            <small>Registrado em {formatPowerDate(profile.created_at)}</small>
          </li>)}
        </ol> : <p className="empty-state">Este gerador ainda não possui perfil nominal.</p>}
      </section>
      <section className="power-detail-card" id="aplicacoes" aria-labelledby="applications-title">
        <h2 id="applications-title">Aplicações e diagnóstico de potência</h2>
        {applications.length ? <div className="table-wrap"><table>
          <thead><tr><th>Aplicação</th><th>Início</th><th>Correlação elétrica</th><th>Avaliação operacional</th></tr></thead>
          <tbody>{applications.map(application => <tr key={application.application_id}>
            <td><Link className="text-link" href={`/admin/aplicacoes/${application.application_id}`}>Diagnóstico #{application.application_id}</Link></td>
            <td>{formatPowerDate(application.start_at)}</td>
            <td>{correlationLabels[application.correlation_status] ?? application.correlation_status}</td>
            <td>{operationalLabels[application.operational_status] ?? application.operational_status}</td>
          </tr>)}</tbody>
        </table></div> : <p>Nenhuma aplicação nesta página.</p>}
        <nav className="filter-actions" aria-label="Páginas de aplicações">
          {page > 0 ? <Link href={`?applications_page=${page - 1}#aplicacoes`}>Página anterior</Link> : null}
          {applications.length === 50 ? <Link href={`?applications_page=${page + 1}#aplicacoes`}>Próxima página</Link> : null}
        </nav>
      </section>
    </main>
  );
}

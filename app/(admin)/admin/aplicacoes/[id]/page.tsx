import Link from "next/link";
import { notFound } from "next/navigation";
import { ApplicationPowerDiagnostic } from "@/components/application-power-diagnostic";
import { getApplicationPowerDiagnostic, parseDiagnosticPage } from "@/lib/admin/power-diagnostics";

export default async function ApplicationDiagnosticPage({ params, searchParams }: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ history_page?: string }>;
}) {
  const { id } = await params;
  const applicationId = Number(id);
  if (!/^\d+$/.test(id) || !Number.isSafeInteger(applicationId) || applicationId <= 0) notFound();
  const page = parseDiagnosticPage((await searchParams).history_page);
  const data = await getApplicationPowerDiagnostic(applicationId, page);
  if (!data.diagnostic) notFound();
  const d = data.diagnostic;
  return <main className="admin-main application-diagnostic">
    <section className="page-heading">
      <p className="eyebrow">Diagnóstico técnico do Master</p>
      <h1>Aplicação #{d.application_id}</h1>
      <p>{d.client_name} · {d.location_name} · {d.cold_room_name} · {d.generator_identifier}</p>
      <Link className="text-link" href={`/admin/geradores/${d.generator_id}#aplicacoes`}>Voltar às aplicações do gerador</Link>
    </section>
    <ApplicationPowerDiagnostic {...data} diagnostic={d} />
    <nav aria-label="Páginas do histórico de reprocessamento" className="filter-actions">
      {page > 0 ? <Link href={`?history_page=${page - 1}#reprocessamentos`}>Reprocessamentos anteriores</Link> : null}
      {data.runs.length === 20 ? <Link href={`?history_page=${page + 1}#reprocessamentos`}>Mais reprocessamentos</Link> : null}
    </nav>
  </main>;
}

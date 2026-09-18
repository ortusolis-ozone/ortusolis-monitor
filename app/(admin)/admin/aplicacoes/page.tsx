import Link from "next/link";
import { getAdminClientApplicationCalendar } from "@/lib/admin/application-calendar";
import { requireMaster } from "@/lib/auth/profile";
import { createClient } from "@/lib/supabase/server";

type Search = { client?: string; month?: string; location?: string; room?: string; generator?: string };
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const first = (value: string | string[] | undefined) => Array.isArray(value) ? value[0] : value;
const month = (value: string | undefined) => Boolean(value && /^\d{4}-(0[1-9]|1[0-2])$/.test(value));
const labelMonth = (value: string) => new Intl.DateTimeFormat("pt-BR", { month: "long", year: "numeric", timeZone: "UTC" }).format(new Date(`${value}-01T00:00:00Z`));
const labelDay = (value: string) => new Intl.DateTimeFormat("pt-BR", { weekday: "long", day: "numeric", month: "long", timeZone: "UTC" }).format(new Date(`${value}T00:00:00Z`));
const shift = (value: string, amount: number) => { const [year, number] = value.split("-").map(Number); return new Date(Date.UTC(year, number - 1 + amount, 1)).toISOString().slice(0, 7); };
const href = (values: Record<string, string | undefined>) => `/admin/aplicacoes?${new URLSearchParams(Object.entries(values).filter((entry): entry is [string, string] => Boolean(entry[1])))}`;

export default async function ApplicationsPage({ searchParams }: { searchParams: Promise<Search> }) {
  await requireMaster();
  const values = await searchParams;
  const clientId = first(values.client);
  const supabase = await createClient();
  const { data: clients, error } = await supabase.from("clients").select("id, legal_name").eq("is_active", true).order("legal_name");
  if (error || clients === null) throw new Error("Não foi possível carregar os clientes.");
  const selectedClient = clientId && uuid.test(clientId) ? clientId : undefined;
  const data = selectedClient ? await getAdminClientApplicationCalendar(selectedClient, {
    ...(month(first(values.month)) ? { month: first(values.month) } : {}),
    ...(uuid.test(first(values.location) ?? "") ? { locationId: first(values.location) } : {}),
    ...(uuid.test(first(values.room) ?? "") ? { coldRoomId: first(values.room) } : {}),
    ...(uuid.test(first(values.generator) ?? "") ? { generatorId: first(values.generator) } : {}),
  }) : null;
  const query = data ? { client: selectedClient, month: data.filters.month, location: data.filters.locationId, room: data.filters.coldRoomId, generator: data.filters.generatorId } : {};
  return <main className="admin-main">
    <section className="page-heading"><p className="eyebrow">Registros importados</p><h1>Aplicações</h1><p>Escolha um cliente para consultar a agenda no mesmo formato do portal.</p></section>
    <section className="listing-card"><form className="portal-filters" method="get"><label>Cliente<select defaultValue={selectedClient ?? ""} name="client"><option value="">Selecione um cliente</option>{clients.map((client) => <option key={client.id} value={client.id}>{client.legal_name}</option>)}</select></label><button className="primary-button" type="submit">Consultar aplicações</button></form></section>
    {!data ? <section className="listing-card"><p className="empty-state">Escolha um cliente para visualizar suas aplicações.</p></section> : <section className="portal-calendar" aria-labelledby="calendar-title">
      <header className="portal-calendar-header"><div><p className="eyebrow">Agenda de aplicações</p><h2 id="calendar-title">{data.clientName} · {labelMonth(data.filters.month)}</h2><p className="portal-section-description">Exibimos somente aplicações registradas para o cliente selecionado.</p></div><nav className="portal-month-navigation"><Link href={href({ ...query, month: shift(data.filters.month, -1) })}>Mês anterior</Link><Link href={href({ ...query, month: shift(data.filters.month, 1) })}>Próximo mês</Link></nav></header>
      <dl className="portal-calendar-summary"><div><dt>Aplicações registradas</dt><dd>{data.applicationCount}</dd></div><div><dt>Geradores com aplicação</dt><dd>{data.generatorCount}</dd></div><div><dt>Atenção necessária</dt><dd>{data.attentionCount}</dd></div></dl>
      <form className="portal-filters portal-calendar-filters" method="get"><input name="client" type="hidden" value={selectedClient}/><label>Mês<input defaultValue={data.filters.month} name="month" type="month"/></label><label>Unidade<select defaultValue={data.filters.locationId ?? ""} name="location"><option value="">Todas</option>{data.options.locations.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label><label>Câmara<select defaultValue={data.filters.coldRoomId ?? ""} name="room"><option value="">Todas</option>{data.options.coldRooms.map((item) => <option key={item.id} value={item.id}>{item.locationName} · {item.name}</option>)}</select></label><label>Gerador<select defaultValue={data.filters.generatorId ?? ""} name="generator"><option value="">Todos</option>{data.options.generators.map((item) => <option key={item.id} value={item.id}>{item.identifier}</option>)}</select></label><button className="primary-button" type="submit">Aplicar filtros</button></form>
      {data.applications.length ? <div className="portal-application-day-list">{data.applications.map((day) => <section className="portal-application-day" key={day.date}><h3><time dateTime={day.date}>{labelDay(day.date)}</time></h3><div className="portal-application-day-items">{day.applications.map((app) => <article className="portal-application-card" key={`${app.generatorId}-${app.startedAt}`}><div><span className="portal-hierarchy-label">Gerador</span><strong>{app.generatorIdentifier}</strong><span className="portal-application-context">{app.locationName} · {app.coldRoomName}</span><dl className="portal-application-measurements"><div><dt>Horário local</dt><dd>{app.startedAt?.slice(0, 5) ?? "Não disponível"} – {app.endedAt?.slice(0, 5) ?? "Não disponível"}</dd></div><div><dt>Maior potência medida</dt><dd>{app.maxMeasuredPowerW === null ? "Não disponível" : `${Number(app.maxMeasuredPowerW).toLocaleString("pt-BR")} W`}</dd></div></dl></div>{app.attentionStatus === "attention" ? <span className="portal-attention"><strong>Aplicação registrada — atenção necessária</strong><small>O consumo elétrico registrado ficou abaixo do esperado.</small></span> : <span className="public-status-badge registered">Aplicação registrada</span>}</article>)}</div></section>)}</div> : <div className="portal-empty-state"><strong>Nenhuma aplicação registrada em {labelMonth(data.filters.month)}</strong><p>Não foram encontradas aplicações concluídas para os filtros selecionados.</p></div>}
    </section>}
  </main>;
}

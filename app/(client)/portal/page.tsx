import Link from "next/link";
import { parseFilters } from "@/lib/portal/filters";

import { AppHeader } from "@/components/app-header";
import { PublicStatusBadge } from "@/components/public-status-badge";
import { requireClientProfile } from "@/lib/auth/profile";
import { getPortalPageData } from "@/lib/portal/queries";
import type {
  PortalApplicationItem,
  PortalCalendarDay,
  PortalFilterOptions,
  PortalPageData,
  ResolvedPortalFilters,
} from "@/lib/portal/types";

export const dynamic = "force-dynamic";

type PortalPageProps = {
  searchParams: Promise<{
    month?: string | string[];
    from?: string | string[];
    to?: string | string[];
    location?: string | string[];
    room?: string | string[];
    generator?: string | string[];
  }>;
};

function formatPortalDate(value: string) {
  const [year, month, day] = value.split("-");
  return `${day}/${month}/${year}`;
}

function formatMonth(value: string) {
  const [year, month] = value.split("-").map(Number);
  return new Intl.DateTimeFormat("pt-BR", {
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  }).format(new Date(Date.UTC(year, month - 1, 1)));
}

function formatApplicationDay(value: string) {
  const [year, month, day] = value.split("-").map(Number);
  return new Intl.DateTimeFormat("pt-BR", {
    weekday: "long",
    day: "numeric",
    month: "long",
    timeZone: "UTC",
  }).format(new Date(Date.UTC(year, month - 1, day)));
}

function formatTime(value: string | null) {
  return value ? value.slice(0, 5) : "Não disponível";
}

function formatPower(value: string | null) {
  if (value === null) return "Não disponível";

  return `${new Intl.NumberFormat("pt-BR", {
    maximumFractionDigits: 2,
  }).format(Number(value))} W`;
}

function shiftMonth(value: string, amount: number) {
  const [year, month] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1 + amount, 1));
  return date.toISOString().slice(0, 7);
}

function portalHref(
  filters: ResolvedPortalFilters,
  overrides: Partial<Pick<ResolvedPortalFilters, "month" | "locationId" | "coldRoomId" | "generatorId">> = {},
) {
  const selection = { ...filters, ...overrides };
  const params = new URLSearchParams({ month: selection.month });

  if (selection.locationId) params.set("location", selection.locationId);
  if (selection.coldRoomId) params.set("room", selection.coldRoomId);
  if (selection.generatorId) params.set("generator", selection.generatorId);

  return `/portal?${params.toString()}`;
}

function ApplicationStatus({
  attentionStatus,
}: Pick<PortalApplicationItem, "attentionStatus">) {
  if (attentionStatus === "attention") {
    return (
      <span className="portal-attention" role="status">
        <strong>Aplicação registrada — atenção necessária</strong>
        <small>
          O consumo elétrico registrado ficou abaixo do esperado. A Ortusolis
          deve verificar o equipamento.
        </small>
      </span>
    );
  }

  return <PublicStatusBadge compact status="registered" />;
}

function ApplicationCard({ application }: { application: PortalApplicationItem }) {
  return (
    <article className="portal-application-card">
      <div>
        <span className="portal-hierarchy-label">Gerador</span>
        <strong>{application.generatorIdentifier}</strong>
        <span className="portal-application-context">
          {application.locationName} · {application.coldRoomName}
        </span>
        <dl className="portal-application-measurements">
          <div>
            <dt>Horário local</dt>
            <dd>
              {application.startedAt && application.endedAt
                ? `${formatTime(application.startedAt)} – ${formatTime(application.endedAt)}`
                : "Não disponível"}
            </dd>
          </div>
          <div>
            <dt>Maior potência medida</dt>
            <dd>{formatPower(application.maxMeasuredPowerW)}</dd>
          </div>
        </dl>
      </div>
      <ApplicationStatus attentionStatus={application.attentionStatus} />
    </article>
  );
}

function ApplicationDay({ day }: { day: PortalCalendarDay }) {
  return (
    <section className="portal-application-day">
      <h3>
        <time dateTime={day.date}>{formatApplicationDay(day.date)}</time>
      </h3>
      <div className="portal-application-day-items">
        {day.applications.map((application) => (
          <ApplicationCard
            application={application}
            key={`${application.generatorId}:${application.statusDate}:${application.startedAt}`}
          />
        ))}
      </div>
    </section>
  );
}

function ApplicationDayList({
  applications,
}: {
  applications: PortalCalendarDay[];
}) {
  return (
    <div className="portal-application-day-list">
      {applications.map((day) => (
        <ApplicationDay day={day} key={day.date} />
      ))}
    </div>
  );
}

function CalendarFilters({
  filters,
  options,
  retention,
}: {
  filters: ResolvedPortalFilters;
  options: PortalFilterOptions;
  retention: PortalPageData["retention"];
}) {
  return (
    <form className="portal-filters portal-calendar-filters" method="get">
      <label>
        Mês
        <input
          defaultValue={filters.month}
          max={retention?.lastMonth}
          min={retention?.firstMonth}
          name="month"
          type="month"
        />
      </label>
      <label>
        Unidade
        <select defaultValue={filters.locationId ?? ""} name="location">
          <option value="">Todas</option>
          {options.locations.map((location) => (
            <option key={location.id} value={location.id}>
              {location.name}
            </option>
          ))}
        </select>
      </label>
      <label>
        Câmara
        <select defaultValue={filters.coldRoomId ?? ""} name="room">
          <option value="">Todas</option>
          {options.coldRooms.map((room) => (
            <option key={room.id} value={room.id}>
              {room.locationName} · {room.name}
            </option>
          ))}
        </select>
      </label>
      <label>
        Gerador
        <select defaultValue={filters.generatorId ?? ""} name="generator">
          <option value="">Todos</option>
          {options.generators.map((generator) => (
            <option key={generator.id} value={generator.id}>
              {generator.identifier}
            </option>
          ))}
        </select>
      </label>
      <div className="portal-filter-actions">
        <button className="primary-button" type="submit">
          Aplicar filtros
        </button>
        <Link className="text-link" href={portalHref(filters, {
          locationId: undefined,
          coldRoomId: undefined,
          generatorId: undefined,
        })}>
          Limpar
        </Link>
      </div>
    </form>
  );
}

function CalendarSummary({
  applicationCount,
  generatorCount,
  attentionCount,
}: {
  applicationCount: number;
  generatorCount: number;
  attentionCount: number;
}) {
  return (
    <dl className="portal-calendar-summary">
      <div>
        <dt>Aplicações registradas</dt>
        <dd>{applicationCount}</dd>
      </div>
      <div>
        <dt>Geradores com aplicação</dt>
        <dd>{generatorCount}</dd>
      </div>
      <div>
        <dt>Atenção necessária</dt>
        <dd>{attentionCount}</dd>
      </div>
    </dl>
  );
}

function CalendarEmptyState({
  hasPublishedStatus,
  month,
}: {
  hasPublishedStatus: boolean;
  month: string;
}) {
  return (
    <div className="portal-empty-state">
      <strong>
        {hasPublishedStatus
          ? `Nenhuma aplicação registrada em ${formatMonth(month)}`
          : "Aguardando a primeira atualização"}
      </strong>
      <p>
        {hasPublishedStatus
          ? "Não foram encontradas aplicações concluídas para os filtros selecionados."
          : "Assim que uma importação for processada, as aplicações realizadas aparecerão aqui."}
      </p>
    </div>
  );
}

export default async function PortalPage({ searchParams }: PortalPageProps) {
  const profile = await requireClientProfile();
  const data = await getPortalPageData(parseFilters(await searchParams));
  const previousMonth = shiftMonth(data.filters.month, -1);
  const nextMonth = shiftMonth(data.filters.month, 1);

  return (
    <main className="app-shell client-portal-shell">
      <AppHeader
        area="Portal do cliente"
        homeHref="/portal"
        userName={profile.fullName}
      />

      <div className="client-portal-main">
        <section className="client-portal-hero">
          <div>
            <p className="eyebrow">Aplicações realizadas</p>
            <h1>{data.clientName}</h1>
            <p>
              Acompanhe as aplicações importadas e processadas para seus
              geradores.
            </p>
          </div>
          <div className="portal-update-card">
            <span>Último dia publicado</span>
            <strong>
              {data.updatedThrough
                ? `Registros publicados até ${formatPortalDate(data.updatedThrough)}`
                : "Registros ainda não atualizados"}
            </strong>
          </div>
        </section>

        <section aria-label="Disponibilidade do histórico" className="portal-update-card">
          <p>O histórico fica disponível por 35 dias. Baixe o PDF para guardar seus registros.</p>
          {!data.retention?.active && (
            <p>{data.retention?.activatesAt
              ? `Até ${new Intl.DateTimeFormat("pt-BR", { timeZone: "America/Fortaleza" }).format(new Date(data.retention.activatesAt))}, o histórico anterior continua disponível para consulta e download.`
              : "O histórico anterior permanece disponível. A data de início da política será informada com 35 dias de antecedência."}</p>
          )}
          {data.retention?.active && data.retention.periods.map(period => (
            <p key={period.locationName}>{period.locationName}: {formatPortalDate(period.from)} a {formatPortalDate(period.to)}. Datas fora desse intervalo estão fora do período disponível.</p>
          ))}
          {data.applicationCount > 0 ? (
            <a className="primary-button" href={portalHref(data.filters).replace("/portal?", "/portal/relatorio?")}>Baixar PDF</a>
          ) : <p>Sem registros disponíveis para exportar.</p>}
        </section>

        <section aria-labelledby="calendar-title" className="portal-calendar">
          <header className="portal-calendar-header">
            <div>
              <p className="eyebrow">Agenda de aplicações</p>
              <h2 id="calendar-title">{formatMonth(data.filters.month)}</h2>
              <p className="portal-section-description">
                Exibimos somente aplicações registradas. Datas sem cartão não
                indicam falha ou ausência de aplicação.
              </p>
            </div>
            <nav aria-label="Navegação de meses" className="portal-month-navigation">
              {(!data.retention?.firstMonth || previousMonth >= data.retention.firstMonth) && (
                <Link href={portalHref(data.filters, { month: previousMonth })}>
                  Mês anterior
                </Link>
              )}
              {(!data.retention?.lastMonth || nextMonth <= data.retention.lastMonth) && (
                <Link href={portalHref(data.filters, { month: nextMonth })}>
                  Próximo mês
                </Link>
              )}
            </nav>
          </header>

          <CalendarSummary
            applicationCount={data.applicationCount}
            attentionCount={data.attentionCount}
            generatorCount={data.generatorCount}
          />
          <CalendarFilters filters={data.filters} options={data.options} retention={data.retention} />

          {data.retention?.outsideWindow ? (
            <div className="portal-empty-state"><strong>Fora do período disponível</strong><p>Selecione um mês que inclua os últimos 35 dias.</p></div>
          ) : data.applications.length > 0 ? (
            <ApplicationDayList applications={data.applications} />
          ) : (
            <CalendarEmptyState
              hasPublishedStatus={data.hasPublishedStatus}
              month={data.filters.month}
            />
          )}
        </section>
      </div>
    </main>
  );
}

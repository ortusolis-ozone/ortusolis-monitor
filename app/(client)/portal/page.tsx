import Link from "next/link";

import { AppHeader } from "@/components/app-header";
import { PublicStatusBadge } from "@/components/public-status-badge";
import { requireClientProfile } from "@/lib/auth/profile";
import {
  portalStatuses,
  portalStatusDetails,
} from "@/lib/portal/constants";
import { getPortalPageData } from "@/lib/portal/queries";
import type {
  PortalFilterOptions,
  PortalFilters,
  PortalHistoryItem,
  PortalLocationOverview,
  PortalVerificationItem,
  ResolvedPortalFilters,
} from "@/lib/portal/types";

export const dynamic = "force-dynamic";

type PortalPageProps = {
  searchParams: Promise<{
    from?: string | string[];
    to?: string | string[];
    location?: string | string[];
    room?: string | string[];
    generator?: string | string[];
  }>;
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const datePattern = /^\d{4}-\d{2}-\d{2}$/;

function firstValue(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

function isValidIsoDate(value: string | undefined): value is string {
  if (!value || !datePattern.test(value)) return false;

  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));

  return date.toISOString().slice(0, 10) === value;
}

function parseFilters(
  values: Awaited<PortalPageProps["searchParams"]>,
): PortalFilters {
  const from = firstValue(values.from);
  const to = firstValue(values.to);
  const location = firstValue(values.location);
  const room = firstValue(values.room);
  const generator = firstValue(values.generator);

  return {
    ...(isValidIsoDate(from) ? { startDate: from } : {}),
    ...(isValidIsoDate(to) ? { endDate: to } : {}),
    ...(location && uuidPattern.test(location) ? { locationId: location } : {}),
    ...(room && uuidPattern.test(room) ? { coldRoomId: room } : {}),
    ...(generator && uuidPattern.test(generator)
      ? { generatorId: generator }
      : {}),
  };
}

function formatPortalDate(value: string) {
  const [year, month, day] = value.split("-");
  return `${day}/${month}/${year}`;
}

function historyHref(
  filters: ResolvedPortalFilters,
  selection: {
    locationId?: string;
    coldRoomId?: string;
    generatorId?: string;
  },
) {
  const params = new URLSearchParams({
    from: filters.startDate,
    to: filters.endDate,
  });

  if (selection.locationId) params.set("location", selection.locationId);
  if (selection.coldRoomId) params.set("room", selection.coldRoomId);
  if (selection.generatorId) params.set("generator", selection.generatorId);

  return `/portal?${params.toString()}#historico`;
}

function EmptyPublicStatus() {
  return <span className="public-status-empty">Sem registros publicados</span>;
}

function ApplicationStatus({ status, attentionStatus }: Pick<PortalHistoryItem, "status" | "attentionStatus">) {
  if (attentionStatus === "attention") {
    return (
      <span className="portal-attention" role="status">
        <strong>Aplicação registrada — atenção necessária</strong>
        <small>O consumo elétrico registrado ficou abaixo do esperado. A Ortusolis deve verificar o equipamento.</small>
      </span>
    );
  }
  return <PublicStatusBadge compact status={status} />;
}

function StatusLegend() {
  return (
    <section aria-labelledby="status-legend-title" className="status-legend">
      <div className="section-title-row">
        <div>
          <p className="eyebrow">Como interpretar</p>
          <h2 id="status-legend-title">Estados dos registros</h2>
        </div>
      </div>
      <div className="status-legend-grid">
        {portalStatuses.map((status) => (
          <article className={`status-legend-item ${status}`} key={status}>
            <PublicStatusBadge compact status={status} />
            <p>{portalStatusDetails[status].description}</p>
          </article>
        ))}
      </div>
    </section>
  );
}

function VerificationPanel({
  items,
  filters,
}: {
  items: PortalVerificationItem[];
  filters: ResolvedPortalFilters;
}) {
  if (items.length === 0) return null;

  return (
    <section
      aria-labelledby="verification-title"
      className="portal-verification-panel"
    >
      <header>
        <div>
          <p className="eyebrow">Atenção nos registros</p>
          <h2 id="verification-title">Itens que requerem verificação</h2>
          <p>
            Há uma inconsistência nos registros destes geradores. Isso não
            confirma falha do equipamento.
          </p>
        </div>
        <PublicStatusBadge status="verification_required" />
      </header>
      <ul>
        {items.map((item) => (
          <li key={item.generatorId}>
            <div>
              <strong>{item.generatorIdentifier}</strong>
              <span>
                {item.locationName} · {item.coldRoomName} · referência de{" "}
                {formatPortalDate(item.statusDate)}
              </span>
            </div>
            <Link
              href={historyHref(
                {
                  ...filters,
                  startDate: item.statusDate,
                  endDate: item.statusDate,
                },
                {
                  locationId: item.locationId,
                  coldRoomId: item.coldRoomId,
                  generatorId: item.generatorId,
                },
              )}
            >
              Consultar registro
            </Link>
          </li>
        ))}
      </ul>
    </section>
  );
}

function GeneratorRow({
  generator,
  locationId,
  coldRoomId,
  filters,
}: {
  generator: PortalLocationOverview["coldRooms"][number]["generators"][number];
  locationId: string;
  coldRoomId: string;
  filters: ResolvedPortalFilters;
}) {
  return (
    <li className="portal-generator-row">
      <div>
        <span className="portal-hierarchy-label">Gerador</span>
        <strong>{generator.identifier}</strong>
      </div>
      <div className="portal-node-actions">
        <ApplicationStatus status={generator.status} attentionStatus={generator.attentionStatus} />
        <Link
          href={historyHref(filters, {
            locationId,
            coldRoomId,
            generatorId: generator.id,
          })}
        >
          Ver histórico
        </Link>
      </div>
    </li>
  );
}

function LocationOverview({
  location,
  filters,
}: {
  location: PortalLocationOverview;
  filters: ResolvedPortalFilters;
}) {
  return (
    <details
      className="portal-location"
      open={location.status === "verification_required" || location.coldRooms.some((room) => room.generators.some((generator) => generator.attentionStatus === "attention"))}
    >
      <summary>
        <div>
          <span className="portal-hierarchy-label">Unidade</span>
          <h3>{location.name}</h3>
        </div>
        <div className="portal-node-actions">
          {location.status ? (
            <PublicStatusBadge compact status={location.status} />
          ) : (
            <EmptyPublicStatus />
          )}
          <span aria-hidden="true" className="details-indicator">
            Abrir
          </span>
        </div>
      </summary>

      <div className="portal-room-list">
        {location.coldRooms.map((room) => (
          <details
            className="portal-room"
            key={room.id}
            open={room.status === "verification_required" || room.generators.some((generator) => generator.attentionStatus === "attention")}
          >
            <summary>
              <div>
                <span className="portal-hierarchy-label">Câmara</span>
                <h4>{room.name}</h4>
              </div>
              <div className="portal-node-actions">
                {room.status ? (
                  <PublicStatusBadge compact status={room.status} />
                ) : (
                  <EmptyPublicStatus />
                )}
                <span aria-hidden="true" className="details-indicator">
                  Abrir
                </span>
              </div>
            </summary>

            {room.generators.length > 0 ? (
              <ul className="portal-generator-list">
                {room.generators.map((generator) => (
                  <GeneratorRow
                    coldRoomId={room.id}
                    filters={filters}
                    generator={generator}
                    key={generator.id}
                    locationId={location.id}
                  />
                ))}
              </ul>
            ) : (
              <p className="portal-node-empty">
                Esta câmara ainda não possui registros públicos para a data da
                visão geral.
              </p>
            )}
          </details>
        ))}

        {location.coldRooms.length === 0 ? (
          <p className="portal-node-empty">
            Esta unidade ainda não possui câmaras cadastradas.
          </p>
        ) : null}
      </div>
    </details>
  );
}

function HistoryFilters({
  filters,
  options,
}: {
  filters: ResolvedPortalFilters;
  options: PortalFilterOptions;
}) {
  return (
    <form className="portal-filters" method="get">
      <label>
        De
        <input
          defaultValue={filters.startDate}
          key={`from:${filters.startDate}`}
          name="from"
          type="date"
        />
      </label>
      <label>
        Até
        <input
          defaultValue={filters.endDate}
          key={`to:${filters.endDate}`}
          name="to"
          type="date"
        />
      </label>
      <label>
        Unidade
        <select
          defaultValue={filters.locationId ?? ""}
          key={`location:${filters.locationId ?? "all"}`}
          name="location"
        >
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
        <select
          defaultValue={filters.coldRoomId ?? ""}
          key={`room:${filters.coldRoomId ?? "all"}`}
          name="room"
        >
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
        <select
          defaultValue={filters.generatorId ?? ""}
          key={`generator:${filters.generatorId ?? "all"}`}
          name="generator"
        >
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
        <Link className="text-link" href="/portal#historico">
          Limpar
        </Link>
      </div>
    </form>
  );
}

function HistoryTable({ history }: { history: PortalHistoryItem[] }) {
  return (
    <div className="portal-history-wrap">
      <table className="portal-history-table">
        <thead>
          <tr>
            <th>Data</th>
            <th>Unidade</th>
            <th>Câmara</th>
            <th>Gerador</th>
            <th>Estado</th>
          </tr>
        </thead>
        <tbody>
          {history.map((item) => (
            <tr key={`${item.generatorId}:${item.statusDate}`}>
              <td data-label="Data">{formatPortalDate(item.statusDate)}</td>
              <td data-label="Unidade">{item.locationName}</td>
              <td data-label="Câmara">{item.coldRoomName}</td>
              <td data-label="Gerador">{item.generatorIdentifier}</td>
              <td data-label="Estado">
                <ApplicationStatus status={item.status} attentionStatus={item.attentionStatus} />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function HistoryEmptyState({
  hasPublishedStatus,
  overviewDate,
  filters,
}: {
  hasPublishedStatus: boolean;
  overviewDate: string | null;
  filters: ResolvedPortalFilters;
}) {
  if (!hasPublishedStatus) {
    return (
      <div className="portal-empty-state">
        <strong>Aguardando a primeira atualização</strong>
        <p>
          Ainda não há registros públicos disponíveis para esta empresa. Assim
          que uma importação for processada, os estados diários aparecerão aqui.
        </p>
      </div>
    );
  }

  if (overviewDate && filters.startDate > overviewDate) {
    return (
      <div className="portal-empty-state">
        <strong>Período ainda não publicado</strong>
        <p>
          O intervalo selecionado começa depois da data mais recente disponível.
          Isso significa que a atualização ainda não alcançou o período.
        </p>
      </div>
    );
  }

  return (
    <div className="portal-empty-state">
      <strong>Nenhum registro para estes filtros</strong>
      <p>
        “Sem dados” aparece quando o período já foi importado, mas não há
        registro completo. “Aguardando atualização” aparece quando a importação
        ainda não alcançou a data.
      </p>
    </div>
  );
}

export default async function PortalPage({ searchParams }: PortalPageProps) {
  const profile = await requireClientProfile();
  const data = await getPortalPageData(parseFilters(await searchParams));

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
            <p className="eyebrow">Registros da empresa</p>
            <h1>{data.clientName}</h1>
            <p>
              Consulte os estados públicos por unidade, câmara, gerador e data.
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

        <VerificationPanel
          filters={data.filters}
          items={data.verificationItems}
        />

        <StatusLegend />

        <section aria-labelledby="overview-title" className="portal-overview">
          <div className="section-title-row">
            <div>
              <p className="eyebrow">Empresa → unidade → câmara → gerador</p>
              <h2 id="overview-title">Visão consolidada</h2>
              <p className="portal-section-description">
                {data.overviewDate
                  ? `Estado mais relevante em ${formatPortalDate(data.overviewDate)}.`
                  : "Os estados aparecerão após a primeira atualização."}
              </p>
            </div>
            {data.overallStatus ? (
              <PublicStatusBadge status={data.overallStatus} />
            ) : (
              <EmptyPublicStatus />
            )}
          </div>

          {data.overview.length > 0 ? (
            <div className="portal-location-list">
              {data.overview.map((location) => (
                <LocationOverview
                  filters={data.filters}
                  key={location.id}
                  location={location}
                />
              ))}
            </div>
          ) : (
            <div className="portal-empty-state">
              <strong>Nenhuma unidade cadastrada</strong>
              <p>A hierarquia da empresa ainda não está disponível.</p>
            </div>
          )}

          {data.generatorsWithoutPublishedContext.length > 0 ? (
            <aside className="portal-unpublished-note">
              <strong>Geradores ainda sem contexto publicado</strong>
              <p>
                Estes geradores aparecerão dentro da unidade e da câmara assim
                que houver um primeiro estado público:{" "}
                {data.generatorsWithoutPublishedContext
                  .map((generator) => generator.identifier)
                  .join(", ")}.
              </p>
            </aside>
          ) : null}
        </section>

        <section
          aria-labelledby="history-title"
          className="portal-history"
          id="historico"
        >
          <div className="section-title-row">
            <div>
              <p className="eyebrow">Consulta por dia</p>
              <h2 id="history-title">Histórico diário</h2>
              <p className="portal-section-description">
                Filtre o período e os níveis da hierarquia que deseja consultar.
              </p>
            </div>
          </div>

          <HistoryFilters filters={data.filters} options={data.options} />

          {data.filters.dateRangeWasAdjusted ? (
            <p className="portal-filter-notice" role="status">
              As datas estavam invertidas e foram reorganizadas para a consulta.
            </p>
          ) : null}

          {data.history.length > 0 ? (
            <HistoryTable history={data.history} />
          ) : (
            <HistoryEmptyState
              filters={data.filters}
              hasPublishedStatus={data.hasPublishedStatus}
              overviewDate={data.overviewDate}
            />
          )}
        </section>
      </div>
    </main>
  );
}

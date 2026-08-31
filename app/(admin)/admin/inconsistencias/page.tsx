import Link from "next/link";

import { FieldError, OperationalForm } from "@/components/operational-form";
import {
  reopenInconsistencyAction,
  reviewInconsistencyAction,
} from "@/lib/admin/actions";
import {
  inconsistencyStatuses,
  inconsistencyStatusLabel,
  inconsistencyTypes,
  inconsistencyTypeLabel,
  sourceClassificationLabel,
  type InconsistencyStatus,
  type InconsistencyType,
} from "@/lib/admin/constants";
import {
  eventOperationLabel,
  formatAdminDate,
  formatAdminDateTime,
} from "@/lib/admin/format";
import { getInconsistencyPageData } from "@/lib/admin/queries";
import type {
  AdminInconsistency,
  InconsistencyFilters,
} from "@/lib/admin/types";

type InconsistenciesPageProps = {
  searchParams: Promise<{
    status?: string;
    type?: string;
    client?: string;
    location?: string;
    generator?: string;
    start?: string;
    end?: string;
  }>;
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const datePattern = /^\d{4}-\d{2}-\d{2}$/;

function parseFilters(
  values: Awaited<InconsistenciesPageProps["searchParams"]>,
): InconsistencyFilters {
  const status = inconsistencyStatuses.some(
    (option) => option.value === values.status,
  )
    ? (values.status as InconsistencyStatus)
    : "pending";
  const type = inconsistencyTypes.some((option) => option.value === values.type)
    ? (values.type as InconsistencyType)
    : "all";

  return {
    status,
    type,
    ...(values.client && uuidPattern.test(values.client)
      ? { clientId: values.client }
      : {}),
    ...(values.location && uuidPattern.test(values.location)
      ? { locationId: values.location }
      : {}),
    ...(values.generator && uuidPattern.test(values.generator)
      ? { generatorId: values.generator }
      : {}),
    ...(values.start && datePattern.test(values.start)
      ? { startDate: values.start }
      : {}),
    ...(values.end && datePattern.test(values.end)
      ? { endDate: values.end }
      : {}),
  };
}

function TechnicalEvent({
  title,
  eventId,
  occurredAt,
  operation,
  sourceOriginal,
  sourceClassification,
  controllerIdentifier,
}: {
  title: string;
  eventId: number | null;
  occurredAt: string | null;
  operation: string | null;
  sourceOriginal: string | null;
  sourceClassification: string | null;
  controllerIdentifier: string | null;
}) {
  if (!eventId) return null;

  return (
    <div className="technical-event">
      <h3>{title}</h3>
      <dl>
        <div>
          <dt>Horário</dt>
          <dd>{formatAdminDateTime(occurredAt)}</dd>
        </div>
        <div>
          <dt>Operação</dt>
          <dd>{eventOperationLabel(operation)}</dd>
        </div>
        <div>
          <dt>Acionado por</dt>
          <dd>{sourceOriginal ?? "—"}</dd>
        </div>
        <div>
          <dt>Classificação</dt>
          <dd>{sourceClassificationLabel(sourceClassification ?? "unknown")}</dd>
        </div>
        <div>
          <dt>Controlador</dt>
          <dd>{controllerIdentifier ?? "—"}</dd>
        </div>
      </dl>
    </div>
  );
}

function TechnicalPower({ item }: { item: AdminInconsistency }) {
  if (!item.power_reading_id && !item.verification_status) return null;

  return (
    <div className="technical-event">
      <h3>Telemetria de potência</h3>
      <dl>
        <div>
          <dt>Leitura observada</dt>
          <dd>
            {item.power_w === null
              ? "—"
              : `${new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 3 }).format(item.power_w)} W`}
          </dd>
        </div>
        <div>
          <dt>Horário</dt>
          <dd>{formatAdminDateTime(item.power_occurred_at)}</dd>
        </div>
        <div>
          <dt>Dispositivo</dt>
          <dd>{item.power_device_name ?? "—"} · {item.power_device_id ?? "—"}</dd>
        </div>
        <div>
          <dt>Controlador</dt>
          <dd>{item.power_controller_identifier ?? "—"}</dd>
        </div>
        <div>
          <dt>Correlação</dt>
          <dd>{item.verification_status ?? "Transição sem aplicação compatível"}</dd>
        </div>
        <div>
          <dt>Motivo técnico</dt>
          <dd>{item.verification_reason ?? "unexpected_power"}</dd>
        </div>
        <div>
          <dt>Evidência ligada</dt>
          <dd>
            {item.correlated_power_on_w === null
              ? "—"
              : `${item.correlated_power_on_w} W em ${formatAdminDateTime(item.correlated_power_on_at)}`}
          </dd>
        </div>
        <div>
          <dt>Evidência desligada</dt>
          <dd>
            {item.correlated_power_off_w === null
              ? "—"
              : `${item.correlated_power_off_w} W em ${formatAdminDateTime(item.correlated_power_off_at)}`}
          </dd>
        </div>
      </dl>
      <p>
        Potência é evidência de energização; não comprova produção ou
        concentração de ozônio.
      </p>
    </div>
  );
}

function InconsistencyCard({ item }: { item: AdminInconsistency }) {
  return (
    <article className="inconsistency-card">
      <header>
        <div>
          <p className="eyebrow">#{item.id}</p>
          <h2>{inconsistencyTypeLabel(item.type)}</h2>
        </div>
        <span className={`review-status ${item.status}`}>
          {inconsistencyStatusLabel(item.status)}
        </span>
      </header>

      <p className="inconsistency-context">
        <strong>{item.client_name}</strong> · {item.location_name} ·{" "}
        {item.generator_identifier} · referência de {formatAdminDate(item.public_date)}
      </p>

      <div className="technical-event-grid">
        <TechnicalEvent
          controllerIdentifier={item.event_controller_identifier}
          eventId={item.event_id}
          occurredAt={item.event_occurred_at}
          operation={item.event_operation}
          sourceClassification={item.event_source_classification}
          sourceOriginal={item.event_source_original}
          title="Evento principal"
        />
        <TechnicalEvent
          controllerIdentifier={item.related_event_controller_identifier}
          eventId={item.related_event_id}
          occurredAt={item.related_event_occurred_at}
          operation={item.related_event_operation}
          sourceClassification={item.related_event_source_classification}
          sourceOriginal={item.related_event_source_original}
          title="Evento relacionado"
        />
        <TechnicalPower item={item} />
      </div>

      {item.status === "pending" ? (
        <OperationalForm
          action={reviewInconsistencyAction}
          className="review-form"
          confirmation="Marcar esta inconsistência como revisada? Os estados afetados serão reprocessados imediatamente."
          pendingLabel="Revisando..."
          submitLabel="Marcar como revisada"
        >
          <input name="inconsistency_id" type="hidden" value={item.id} />
          <label>
            Nota interna (opcional)
            <textarea
              maxLength={2000}
              name="review_note"
              placeholder="Registre o que foi conferido ou a decisão tomada."
              rows={3}
            />
            <FieldError name="review_note" />
          </label>
        </OperationalForm>
      ) : null}

      {item.status === "reviewed" ? (
        <div className="review-record">
          <div>
            <p>
              Revisada por <strong>{item.reviewed_by_name ?? "Usuário indisponível"}</strong>{" "}
              em {formatAdminDateTime(item.reviewed_at)}.
            </p>
            <p>{item.review_note || "Sem nota interna."}</p>
          </div>
          <OperationalForm
            action={reopenInconsistencyAction}
            buttonClassName="secondary-button compact-button"
            className="inline-action-form"
            confirmation="Reabrir esta revisão? A nota e os dados da revisão serão removidos e os estados serão reprocessados."
            pendingLabel="Reabrindo..."
            submitLabel="Reabrir revisão"
          >
            <input name="inconsistency_id" type="hidden" value={item.id} />
          </OperationalForm>
        </div>
      ) : null}
    </article>
  );
}

export default async function InconsistenciesPage({
  searchParams,
}: InconsistenciesPageProps) {
  const filters = parseFilters(await searchParams);
  const { inconsistencies, options } = await getInconsistencyPageData(filters);

  return (
    <main className="admin-main">
      <section className="page-heading">
        <p className="eyebrow">Revisão operacional</p>
        <h1>Inconsistências</h1>
        <p>
          A lista abre nas pendências. Revise os eventos técnicos, registre uma
          nota interna e reabra revisões feitas por engano quando necessário.
        </p>
      </section>

      <form className="list-filters inconsistency-filters">
        <label>
          Estado
          <select defaultValue={filters.status} name="status">
            {inconsistencyStatuses.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
        <label>
          Tipo
          <select defaultValue={filters.type} name="type">
            {inconsistencyTypes.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
        <label>
          Cliente
          <select defaultValue={filters.clientId ?? ""} name="client">
            <option value="">Todos</option>
            {options.clients.map((client) => (
              <option key={client.id} value={client.id}>
                {client.legalName}
              </option>
            ))}
          </select>
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
        <label>
          Desde
          <input defaultValue={filters.startDate} name="start" type="date" />
        </label>
        <label>
          Até
          <input defaultValue={filters.endDate} name="end" type="date" />
        </label>
        <div className="filter-actions">
          <button className="secondary-button" type="submit">
            Filtrar
          </button>
          <Link className="text-link" href="/admin/inconsistencias">
            Limpar
          </Link>
        </div>
      </form>

      <section className="inconsistency-list" aria-live="polite">
        {inconsistencies.map((item) => (
          <InconsistencyCard item={item} key={item.id} />
        ))}

        {inconsistencies.length === 0 ? (
          <div className="listing-card empty-state">
            Nenhuma inconsistência encontrada para os filtros selecionados.
          </div>
        ) : null}
      </section>

      {inconsistencies.length === 500 ? (
        <p className="result-limit-note">
          Exibindo os 500 registros mais recentes. Restrinja o período para uma
          revisão mais precisa.
        </p>
      ) : null}
    </main>
  );
}

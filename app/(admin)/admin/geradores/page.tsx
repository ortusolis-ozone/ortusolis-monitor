import { FieldError, OperationalForm } from "@/components/operational-form";
import { ListFilters } from "@/components/list-filters";
import { StatusBadge } from "@/components/status-badge";
import {
  createGeneratorAction,
  editGeneratorAction,
  reassignGeneratorAction,
  setGeneratorStatusAction,
} from "@/lib/operations/actions";
import { parseStatusFilter } from "@/lib/operations/constants";
import { formatOperationalDate } from "@/lib/operations/format";
import {
  getGenerators,
  getOperationalFormOptions,
} from "@/lib/operations/queries";

type GeneratorsPageProps = {
  searchParams: Promise<{ status?: string }>;
};

function todayInFortaleza() {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Fortaleza",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

export default async function GeneratorsPage({
  searchParams,
}: GeneratorsPageProps) {
  const filters = await searchParams;
  const status = parseStatusFilter(filters.status);
  const [generators, options] = await Promise.all([
    getGenerators(status),
    getOperationalFormOptions(),
  ]);
  const clientNames = new Map(
    options.clients.map((client) => [client.id, client.legal_name]),
  );
  const locationNames = new Map(
    options.locations.map((location) => [location.id, location.name]),
  );
  const today = todayInFortaleza();

  return (
    <main className="admin-main">
      <section className="page-heading page-heading-row">
        <div>
          <p className="eyebrow">Quarto nível</p>
          <h1>Geradores e alocações</h1>
          <p>
            Todo novo gerador nasce alocado e com os controladores de estado e
            potência criados na mesma transação.
          </p>
        </div>

        <details className="create-panel">
          <summary>Novo gerador</summary>
          <OperationalForm
            action={createGeneratorAction}
            submitLabel="Cadastrar e alocar"
          >
            <label>
              Câmara inicial
              <select name="cold_room_id" required>
                <option value="">Selecione</option>
                {options.coldRooms.map((room) => (
                  <option key={room.id} value={room.id}>
                    {clientNames.get(room.client_id)} —{" "}
                    {locationNames.get(room.location_id)} — {room.name}
                  </option>
                ))}
              </select>
              <FieldError name="cold_room_id" />
            </label>
            <label>
              Identificação do gerador
              <input name="identifier" required />
              <FieldError name="identifier" />
            </label>
            <label>
              Início da alocação
              <input
                defaultValue={today}
                name="valid_from"
                required
                type="date"
              />
              <FieldError name="valid_from" />
            </label>
            <label>
              Controlador de estado
              <input name="state_controller_identifier" required />
              <FieldError name="state_controller_identifier" />
            </label>
            <label>
              Controlador de potência
              <input name="power_controller_identifier" required />
              <FieldError name="power_controller_identifier" />
            </label>
            <label>
              Device ID da potência
              <input name="power_controller_device_id" required />
              <FieldError name="power_controller_device_id" />
            </label>
            <label>
              Limite ligado (W)
              <input defaultValue="5" min="0.001" name="power_on_threshold_w" required step="0.001" type="number" />
              <FieldError name="power_on_threshold_w" />
            </label>
            <label>
              Limite desligado (W)
              <input defaultValue="1" min="0" name="power_off_threshold_w" required step="0.001" type="number" />
              <FieldError name="power_off_threshold_w" />
            </label>
            <label>
              Tolerância (segundos)
              <input defaultValue="120" max="86400" min="0" name="correlation_tolerance_seconds" required step="1" type="number" />
              <FieldError name="correlation_tolerance_seconds" />
            </label>
          </OperationalForm>
        </details>
      </section>

      <ListFilters status={status} />

      <section className="listing-card">
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Gerador</th>
                <th>Cliente</th>
                <th>Alocação atual</th>
                <th>Desde</th>
                <th>Telemetria</th>
                <th>Status</th>
                <th>Ações</th>
              </tr>
            </thead>
            <tbody>
              {generators.map((generator) => {
                const targetRooms = options.coldRooms.filter(
                  (room) =>
                    room.client_id === generator.client_id &&
                    room.id !== generator.currentAssignment?.cold_room_id,
                );

                return (
                  <tr key={generator.id}>
                    <td>
                      <strong>{generator.identifier}</strong>
                      <details className="history-details table-history">
                        <summary>
                          {generator.assignmentHistory.length} alocação(ões)
                        </summary>
                        {generator.assignmentHistory.map((assignment) => (
                          <p key={assignment.id}>
                            {assignment.locationName} / {assignment.coldRoomName}
                            : {formatOperationalDate(assignment.valid_from)} —{" "}
                            {formatOperationalDate(assignment.valid_until)}
                          </p>
                        ))}
                      </details>
                    </td>
                    <td>{generator.clientName}</td>
                    <td>
                      {generator.currentAssignment
                        ? `${generator.currentAssignment.locationName} / ${generator.currentAssignment.coldRoomName}`
                        : "Sem alocação ativa"}
                    </td>
                    <td>
                      {formatOperationalDate(
                        generator.currentAssignment?.valid_from ?? null,
                      )}
                    </td>
                    <td>
                      <span className={`import-status ${generator.telemetry_status === "ready" ? "confirmed" : "processing"}`}>
                        {generator.telemetry_status === "ready"
                          ? "Pronto"
                          : "Telemetria pendente"}
                      </span>
                    </td>
                    <td>
                      <StatusBadge isActive={generator.is_active} />
                    </td>
                    <td>
                      <div className="row-actions">
                        <details className="row-details">
                          <summary>Editar</summary>
                          <OperationalForm
                            action={editGeneratorAction}
                            className="operational-form compact-form"
                            submitLabel="Salvar"
                          >
                            <input
                              name="id"
                              type="hidden"
                              value={generator.id}
                            />
                            <label>
                              Identificação
                              <input
                                defaultValue={generator.identifier}
                                name="identifier"
                                required
                              />
                              <FieldError name="identifier" />
                            </label>
                          </OperationalForm>
                        </details>

                        {generator.is_active && generator.currentAssignment ? (
                          <details className="row-details">
                            <summary>Realocar</summary>
                            <OperationalForm
                              action={reassignGeneratorAction}
                              className="operational-form compact-form"
                              confirmation="Confirmar a realocação? A alocação atual será encerrada na data informada e o histórico não poderá ser excluído."
                              submitLabel="Confirmar realocação"
                            >
                              <input
                                name="generator_id"
                                type="hidden"
                                value={generator.id}
                              />
                              <label>
                                Câmara de destino
                                <select name="cold_room_id" required>
                                  <option value="">Selecione</option>
                                  {targetRooms.map((room) => (
                                    <option key={room.id} value={room.id}>
                                      {locationNames.get(room.location_id)} —{" "}
                                      {room.name}
                                    </option>
                                  ))}
                                </select>
                                <FieldError name="cold_room_id" />
                              </label>
                              <label>
                                Data efetiva
                                <input
                                  defaultValue={today}
                                  name="effective_on"
                                  required
                                  type="date"
                                />
                                <FieldError name="effective_on" />
                              </label>
                            </OperationalForm>
                          </details>
                        ) : null}

                        <OperationalForm
                          action={setGeneratorStatusAction}
                          buttonClassName={
                            generator.is_active
                              ? "danger-button compact-button"
                              : "secondary-button compact-button"
                          }
                          className="inline-action-form"
                          confirmation={
                            generator.is_active
                              ? "Inativar este gerador? Seu histórico será preservado."
                              : "Reativar este gerador?"
                          }
                          submitLabel={
                            generator.is_active ? "Inativar" : "Reativar"
                          }
                        >
                          <input
                            name="id"
                            type="hidden"
                            value={generator.id}
                          />
                          <input
                            name="is_active"
                            type="hidden"
                            value={String(!generator.is_active)}
                          />
                        </OperationalForm>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        {generators.length === 0 ? (
          <p className="empty-state">Nenhum gerador encontrado.</p>
        ) : null}
      </section>
    </main>
  );
}

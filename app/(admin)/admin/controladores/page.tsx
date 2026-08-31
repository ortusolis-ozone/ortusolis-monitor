import { FieldError, OperationalForm } from "@/components/operational-form";
import { ListFilters } from "@/components/list-filters";
import { StatusBadge } from "@/components/status-badge";
import {
  createControllerAction,
  deactivateControllerAction,
  editControllerAction,
  reactivateControllerAction,
  replaceControllerAction,
} from "@/lib/operations/actions";
import { parseStatusFilter } from "@/lib/operations/constants";
import { formatOperationalDate } from "@/lib/operations/format";
import {
  getControllers,
  getOperationalFormOptions,
} from "@/lib/operations/queries";

type ControllersPageProps = {
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

export default async function ControllersPage({
  searchParams,
}: ControllersPageProps) {
  const filters = await searchParams;
  const status = parseStatusFilter(filters.status);
  const [controllers, options] = await Promise.all([
    getControllers(status),
    getOperationalFormOptions(),
  ]);
  const clientNames = new Map(
    options.clients.map((client) => [client.id, client.legal_name]),
  );
  const today = todayInFortaleza();

  return (
    <main className="admin-main">
      <section className="page-heading page-heading-row">
        <div>
          <p className="eyebrow">Quinto nível</p>
          <h1>Controladores</h1>
          <p>
            Estado e potência possuem vigências independentes. Cadastre o papel
            ausente ou substitua apenas o controlador correspondente.
          </p>
        </div>

        <details className="create-panel">
          <summary>Novo controlador</summary>
          <OperationalForm
            action={createControllerAction}
            submitLabel="Cadastrar controlador"
          >
            <label>
              Gerador
              <select name="generator_id" required>
                <option value="">Selecione</option>
                {options.generators.map((generator) => (
                  <option key={generator.id} value={generator.id}>
                    {clientNames.get(generator.client_id)} —{" "}
                    {generator.identifier}
                  </option>
                ))}
              </select>
              <FieldError name="generator_id" />
            </label>
            <label>
              Papel
              <select name="role" required>
                <option value="state">Estado liga/desliga</option>
                <option value="power_telemetry">Telemetria de potência</option>
              </select>
              <FieldError name="role" />
            </label>
            <label>
              Identificação
              <input name="identifier" required />
              <FieldError name="identifier" />
            </label>
            <label>
              Data de ativação
              <input
                defaultValue={today}
                name="activated_on"
                required
                type="date"
              />
              <FieldError name="activated_on" />
            </label>
            <label>
              Device ID (somente potência)
              <input name="external_device_id" />
              <FieldError name="external_device_id" />
            </label>
            <label>
              Limite ligado (W)
              <input defaultValue="5" min="0.001" name="power_on_threshold_w" step="0.001" type="number" />
              <FieldError name="power_on_threshold_w" />
            </label>
            <label>
              Limite desligado (W)
              <input defaultValue="1" min="0" name="power_off_threshold_w" step="0.001" type="number" />
              <FieldError name="power_off_threshold_w" />
            </label>
            <label>
              Tolerância (segundos)
              <input defaultValue="120" max="86400" min="0" name="correlation_tolerance_seconds" step="1" type="number" />
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
                <th>Controlador</th>
                <th>Papel</th>
                <th>Gerador</th>
                <th>Cliente</th>
                <th>Ativação</th>
                <th>Desativação</th>
                <th>Configuração</th>
                <th>Status</th>
                <th>Ações</th>
              </tr>
            </thead>
            <tbody>
              {controllers.map((controller) => {
                const hasOtherActiveController = options.controllers.some(
                  (other) =>
                    other.generator_id === controller.generator_id &&
                    other.role === controller.role &&
                    other.id !== controller.id &&
                    other.deactivated_at === null,
                );

                return (
                  <tr key={controller.id}>
                    <td>{controller.identifier}</td>
                    <td>
                      {controller.role === "state"
                        ? "Estado liga/desliga"
                        : "Telemetria de potência"}
                    </td>
                    <td>{controller.generatorName}</td>
                    <td>{controller.clientName}</td>
                    <td>{formatOperationalDate(controller.activated_at)}</td>
                    <td>{formatOperationalDate(controller.deactivated_at)}</td>
                    <td>
                      {controller.role === "power_telemetry" ? (
                        <span>
                          Device ID: {controller.external_device_id}
                          <small className="table-secondary-line">
                            ≥ {controller.power_on_threshold_w} W · ≤ {controller.power_off_threshold_w} W · ±{controller.correlation_tolerance_seconds}s
                          </small>
                        </span>
                      ) : (
                        "Rotina liga/desliga"
                      )}
                    </td>
                    <td>
                      <StatusBadge isActive={controller.is_active} />
                    </td>
                    <td>
                      <div className="row-actions">
                        <details className="row-details">
                          <summary>Editar</summary>
                          <OperationalForm
                            action={editControllerAction}
                            className="operational-form compact-form"
                            submitLabel="Salvar"
                          >
                            <input
                              name="id"
                              type="hidden"
                              value={controller.id}
                            />
                            <input name="role" type="hidden" value={controller.role} />
                            <label>
                              Identificação
                              <input
                                defaultValue={controller.identifier}
                                name="identifier"
                                required
                              />
                              <FieldError name="identifier" />
                            </label>
                            {controller.role === "power_telemetry" ? (
                              <>
                                <label>
                                  Device ID
                                  <input defaultValue={controller.external_device_id ?? ""} name="external_device_id" required />
                                  <FieldError name="external_device_id" />
                                </label>
                                <label>
                                  Limite ligado (W)
                                  <input defaultValue={controller.power_on_threshold_w ?? 5} min="0.001" name="power_on_threshold_w" required step="0.001" type="number" />
                                </label>
                                <label>
                                  Limite desligado (W)
                                  <input defaultValue={controller.power_off_threshold_w ?? 1} min="0" name="power_off_threshold_w" required step="0.001" type="number" />
                                </label>
                                <label>
                                  Tolerância (segundos)
                                  <input defaultValue={controller.correlation_tolerance_seconds ?? 120} max="86400" min="0" name="correlation_tolerance_seconds" required step="1" type="number" />
                                </label>
                              </>
                            ) : null}
                          </OperationalForm>
                        </details>

                        {controller.is_active ? (
                          <>
                            <details className="row-details">
                              <summary>Substituir</summary>
                              <OperationalForm
                                action={replaceControllerAction}
                                className="operational-form compact-form"
                                confirmation="Confirmar a substituição? O controlador atual será encerrado e o novo será ativado na data informada."
                                submitLabel="Confirmar substituição"
                              >
                                <input
                                  name="generator_id"
                                  type="hidden"
                                  value={controller.generator_id}
                                />
                                <input name="role" type="hidden" value={controller.role} />
                                <label>
                                  Identificação do novo controlador
                                  <input name="identifier" required />
                                  <FieldError name="identifier" />
                                </label>
                                <label>
                                  Data de ativação do novo
                                  <input
                                    defaultValue={today}
                                    name="activated_on"
                                    required
                                    type="date"
                                  />
                                  <FieldError name="activated_on" />
                                </label>
                                {controller.role === "power_telemetry" ? (
                                  <>
                                    <label>
                                      Device ID do novo controlador
                                      <input name="external_device_id" required />
                                      <FieldError name="external_device_id" />
                                    </label>
                                    <label>
                                      Limite ligado (W)
                                      <input defaultValue={controller.power_on_threshold_w ?? 5} min="0.001" name="power_on_threshold_w" required step="0.001" type="number" />
                                    </label>
                                    <label>
                                      Limite desligado (W)
                                      <input defaultValue={controller.power_off_threshold_w ?? 1} min="0" name="power_off_threshold_w" required step="0.001" type="number" />
                                    </label>
                                    <label>
                                      Tolerância (segundos)
                                      <input defaultValue={controller.correlation_tolerance_seconds ?? 120} max="86400" min="0" name="correlation_tolerance_seconds" required step="1" type="number" />
                                    </label>
                                  </>
                                ) : null}
                              </OperationalForm>
                            </details>
                            <details className="row-details">
                              <summary>Inativar</summary>
                              <OperationalForm
                                action={deactivateControllerAction}
                                buttonClassName="danger-button"
                                className="operational-form compact-form"
                                confirmation="Inativar este controlador na data informada? O histórico será preservado."
                                submitLabel="Confirmar inativação"
                              >
                                <input
                                  name="controller_id"
                                  type="hidden"
                                  value={controller.id}
                                />
                                <label>
                                  Data de desativação
                                  <input
                                    defaultValue={today}
                                    name="deactivated_on"
                                    required
                                    type="date"
                                  />
                                  <FieldError name="deactivated_on" />
                                </label>
                              </OperationalForm>
                            </details>
                          </>
                        ) : !hasOtherActiveController ? (
                          <OperationalForm
                            action={reactivateControllerAction}
                            buttonClassName="secondary-button compact-button"
                            className="inline-action-form"
                            confirmation="Reativar este controlador e reabrir sua vigência?"
                            submitLabel="Reativar"
                          >
                            <input
                              name="controller_id"
                              type="hidden"
                              value={controller.id}
                            />
                          </OperationalForm>
                        ) : (
                          <span className="muted-label">Histórico</span>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        {controllers.length === 0 ? (
          <p className="empty-state">Nenhum controlador encontrado.</p>
        ) : null}
      </section>
    </main>
  );
}

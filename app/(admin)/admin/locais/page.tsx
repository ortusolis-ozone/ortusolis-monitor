import { FieldError, OperationalForm } from "@/components/operational-form";
import { ListFilters } from "@/components/list-filters";
import { StatusBadge } from "@/components/status-badge";
import {
  createLocationAction,
  editLocationAction,
  setLocationStatusAction,
} from "@/lib/operations/actions";
import { parseStatusFilter } from "@/lib/operations/constants";
import {
  getLocations,
  getOperationalFormOptions,
} from "@/lib/operations/queries";

type LocationsPageProps = {
  searchParams: Promise<{ status?: string }>;
};

export default async function LocationsPage({
  searchParams,
}: LocationsPageProps) {
  const filters = await searchParams;
  const status = parseStatusFilter(filters.status);
  const [locations, options] = await Promise.all([
    getLocations(status),
    getOperationalFormOptions(),
  ]);

  return (
    <main className="admin-main">
      <section className="page-heading page-heading-row">
        <div>
          <p className="eyebrow">Segundo nível</p>
          <h1>Locais e unidades</h1>
          <p>Defina a localização e o fuso usados nas datas operacionais.</p>
        </div>

        <details className="create-panel">
          <summary>Nova unidade</summary>
          <OperationalForm
            action={createLocationAction}
            submitLabel="Cadastrar unidade"
          >
            <label>
              Cliente
              <select name="client_id" required>
                <option value="">Selecione</option>
                {options.clients.map((client) => (
                  <option key={client.id} value={client.id}>
                    {client.legal_name}
                  </option>
                ))}
              </select>
              <FieldError name="client_id" />
            </label>
            <label>
              Nome da unidade
              <input name="name" required />
              <FieldError name="name" />
            </label>
            <label>
              Identificação ou localização
              <textarea name="description" rows={2} />
            </label>
            <label>
              Fuso IANA
              <input
                defaultValue="America/Fortaleza"
                name="time_zone"
                required
              />
              <FieldError name="time_zone" />
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
                <th>Unidade</th>
                <th>Cliente</th>
                <th>Localização</th>
                <th>Fuso</th>
                <th>Status</th>
                <th>Ações</th>
              </tr>
            </thead>
            <tbody>
              {locations.map((location) => (
                <tr key={location.id}>
                  <td>{location.name}</td>
                  <td>{location.clientName}</td>
                  <td>{location.description || "—"}</td>
                  <td>{location.time_zone}</td>
                  <td>
                    <StatusBadge isActive={location.is_active} />
                  </td>
                  <td>
                    <div className="row-actions">
                      <details className="row-details">
                        <summary>Editar</summary>
                        <OperationalForm
                          action={editLocationAction}
                          className="operational-form compact-form"
                          submitLabel="Salvar"
                        >
                          <input name="id" type="hidden" value={location.id} />
                          <label>
                            Nome
                            <input
                              defaultValue={location.name}
                              name="name"
                              required
                            />
                            <FieldError name="name" />
                          </label>
                          <label>
                            Identificação ou localização
                            <textarea
                              defaultValue={location.description ?? ""}
                              name="description"
                              rows={2}
                            />
                          </label>
                          <label>
                            Fuso IANA
                            <input
                              defaultValue={location.time_zone}
                              name="time_zone"
                              required
                            />
                            <FieldError name="time_zone" />
                          </label>
                        </OperationalForm>
                      </details>
                      <OperationalForm
                        action={setLocationStatusAction}
                        buttonClassName={
                          location.is_active
                            ? "danger-button compact-button"
                            : "secondary-button compact-button"
                        }
                        className="inline-action-form"
                        confirmation={
                          location.is_active
                            ? "Inativar esta unidade? Ela e seus descendentes deixarão de aparecer nos fluxos ativos."
                            : "Reativar esta unidade?"
                        }
                        submitLabel={
                          location.is_active ? "Inativar" : "Reativar"
                        }
                      >
                        <input name="id" type="hidden" value={location.id} />
                        <input
                          name="is_active"
                          type="hidden"
                          value={String(!location.is_active)}
                        />
                      </OperationalForm>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {locations.length === 0 ? (
          <p className="empty-state">Nenhuma unidade encontrada.</p>
        ) : null}
      </section>
    </main>
  );
}

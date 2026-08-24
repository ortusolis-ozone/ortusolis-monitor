import { FieldError, OperationalForm } from "@/components/operational-form";
import { ListFilters } from "@/components/list-filters";
import { StatusBadge } from "@/components/status-badge";
import {
  createColdRoomAction,
  editColdRoomAction,
  setColdRoomStatusAction,
} from "@/lib/operations/actions";
import {
  coldRoomCategories,
  parseStatusFilter,
} from "@/lib/operations/constants";
import { categoryLabel } from "@/lib/operations/format";
import {
  getColdRooms,
  getOperationalFormOptions,
} from "@/lib/operations/queries";

type ColdRoomsPageProps = {
  searchParams: Promise<{ status?: string }>;
};

export default async function ColdRoomsPage({
  searchParams,
}: ColdRoomsPageProps) {
  const filters = await searchParams;
  const status = parseStatusFilter(filters.status);
  const [rooms, options] = await Promise.all([
    getColdRooms(status),
    getOperationalFormOptions(),
  ]);
  const clientNames = new Map(
    options.clients.map((client) => [client.id, client.legal_name]),
  );

  return (
    <main className="admin-main">
      <section className="page-heading page-heading-row">
        <div>
          <p className="eyebrow">Terceiro nível</p>
          <h1>Câmaras frias</h1>
          <p>Cadastre a identificação e a categoria armazenada em cada câmara.</p>
        </div>

        <details className="create-panel">
          <summary>Nova câmara</summary>
          <OperationalForm
            action={createColdRoomAction}
            submitLabel="Cadastrar câmara"
          >
            <label>
              Unidade
              <select name="location_id" required>
                <option value="">Selecione</option>
                {options.locations.map((location) => (
                  <option key={location.id} value={location.id}>
                    {clientNames.get(location.client_id)} — {location.name}
                  </option>
                ))}
              </select>
              <FieldError name="location_id" />
            </label>
            <label>
              Nome ou identificação
              <input name="name" required />
              <FieldError name="name" />
            </label>
            <label>
              Categoria
              <select defaultValue="outros" name="category" required>
                {coldRoomCategories.map((category) => (
                  <option key={category.value} value={category.value}>
                    {category.label}
                  </option>
                ))}
              </select>
              <FieldError name="category" />
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
                <th>Câmara</th>
                <th>Unidade</th>
                <th>Cliente</th>
                <th>Categoria</th>
                <th>Status</th>
                <th>Ações</th>
              </tr>
            </thead>
            <tbody>
              {rooms.map((room) => (
                <tr key={room.id}>
                  <td>{room.name}</td>
                  <td>{room.locationName}</td>
                  <td>{room.clientName}</td>
                  <td>{categoryLabel(room.category)}</td>
                  <td>
                    <StatusBadge isActive={room.is_active} />
                  </td>
                  <td>
                    <div className="row-actions">
                      <details className="row-details">
                        <summary>Editar</summary>
                        <OperationalForm
                          action={editColdRoomAction}
                          className="operational-form compact-form"
                          submitLabel="Salvar"
                        >
                          <input name="id" type="hidden" value={room.id} />
                          <label>
                            Nome ou identificação
                            <input
                              defaultValue={room.name}
                              name="name"
                              required
                            />
                            <FieldError name="name" />
                          </label>
                          <label>
                            Categoria
                            <select
                              defaultValue={room.category}
                              name="category"
                              required
                            >
                              {coldRoomCategories.map((category) => (
                                <option
                                  key={category.value}
                                  value={category.value}
                                >
                                  {category.label}
                                </option>
                              ))}
                            </select>
                            <FieldError name="category" />
                          </label>
                        </OperationalForm>
                      </details>
                      <OperationalForm
                        action={setColdRoomStatusAction}
                        buttonClassName={
                          room.is_active
                            ? "danger-button compact-button"
                            : "secondary-button compact-button"
                        }
                        className="inline-action-form"
                        confirmation={
                          room.is_active
                            ? "Inativar esta câmara? Ela deixará de aparecer nos fluxos ativos."
                            : "Reativar esta câmara?"
                        }
                        submitLabel={room.is_active ? "Inativar" : "Reativar"}
                      >
                        <input name="id" type="hidden" value={room.id} />
                        <input
                          name="is_active"
                          type="hidden"
                          value={String(!room.is_active)}
                        />
                      </OperationalForm>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {rooms.length === 0 ? (
          <p className="empty-state">Nenhuma câmara encontrada.</p>
        ) : null}
      </section>
    </main>
  );
}

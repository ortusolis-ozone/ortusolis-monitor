import { FieldError, OperationalForm } from "@/components/operational-form";
import { ListFilters } from "@/components/list-filters";
import { StatusBadge } from "@/components/status-badge";
import {
  editUserAction,
  inviteUserAction,
  setUserStatusAction,
} from "@/lib/operations/actions";
import {
  assignableClientRoles,
  parseStatusFilter,
} from "@/lib/operations/constants";
import { roleLabel } from "@/lib/operations/format";
import {
  getOperationalFormOptions,
  getUsers,
} from "@/lib/operations/queries";

type UsersPageProps = {
  searchParams: Promise<{ status?: string }>;
};

export default async function UsersPage({ searchParams }: UsersPageProps) {
  const filters = await searchParams;
  const status = parseStatusFilter(filters.status);
  const [users, options] = await Promise.all([
    getUsers(status),
    getOperationalFormOptions(),
  ]);

  return (
    <main className="admin-main">
      <section className="page-heading page-heading-row">
        <div>
          <p className="eyebrow">Acesso individual</p>
          <h1>Usuários dos clientes</h1>
          <p>
            O convite cria uma autenticação individual e vincula o perfil a um
            único cliente.
          </p>
        </div>

        <details className="create-panel">
          <summary>Convidar usuário</summary>
          <OperationalForm action={inviteUserAction} submitLabel="Enviar convite">
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
              Nome completo
              <input autoComplete="name" name="full_name" required />
              <FieldError name="full_name" />
            </label>
            <label>
              E-mail
              <input autoComplete="email" name="email" required type="email" />
              <FieldError name="email" />
            </label>
            <label>
              Papel
              <select defaultValue="viewer" name="role" required>
                {assignableClientRoles.map((role) => (
                  <option key={role.value} value={role.value}>
                    {role.label}
                  </option>
                ))}
              </select>
              <FieldError name="role" />
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
                <th>Usuário</th>
                <th>E-mail</th>
                <th>Cliente</th>
                <th>Papel</th>
                <th>Status</th>
                <th>Ações</th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => (
                <tr key={user.id}>
                  <td>{user.full_name}</td>
                  <td>{user.email}</td>
                  <td>{user.clientName}</td>
                  <td>{roleLabel(user.role)}</td>
                  <td>
                    <StatusBadge isActive={user.is_active} />
                  </td>
                  <td>
                    <div className="row-actions">
                      <details className="row-details">
                        <summary>Editar</summary>
                        <OperationalForm
                          action={editUserAction}
                          className="operational-form compact-form"
                          submitLabel="Salvar"
                        >
                          <input name="id" type="hidden" value={user.id} />
                          <label>
                            Nome completo
                            <input
                              defaultValue={user.full_name}
                              name="full_name"
                              required
                            />
                            <FieldError name="full_name" />
                          </label>
                          <label>
                            Papel
                            <select
                              defaultValue={user.role}
                              name="role"
                              required
                            >
                              {assignableClientRoles.map((role) => (
                                <option key={role.value} value={role.value}>
                                  {role.label}
                                </option>
                              ))}
                            </select>
                            <FieldError name="role" />
                          </label>
                        </OperationalForm>
                      </details>
                      <OperationalForm
                        action={setUserStatusAction}
                        buttonClassName={
                          user.is_active
                            ? "danger-button compact-button"
                            : "secondary-button compact-button"
                        }
                        className="inline-action-form"
                        confirmation={
                          user.is_active
                            ? "Inativar este usuário? Ele perderá o acesso aos dados do cliente."
                            : "Reativar este usuário?"
                        }
                        submitLabel={user.is_active ? "Inativar" : "Reativar"}
                      >
                        <input name="id" type="hidden" value={user.id} />
                        <input
                          name="is_active"
                          type="hidden"
                          value={String(!user.is_active)}
                        />
                      </OperationalForm>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {users.length === 0 ? (
          <p className="empty-state">Nenhum usuário encontrado.</p>
        ) : null}
      </section>
    </main>
  );
}

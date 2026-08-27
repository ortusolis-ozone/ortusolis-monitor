import Link from "next/link";

import { FieldError, OperationalForm } from "@/components/operational-form";
import { ListFilters } from "@/components/list-filters";
import { StatusBadge } from "@/components/status-badge";
import {
  createClientAction,
  editClientAction,
  setClientStatusAction,
} from "@/lib/operations/actions";
import { parseStatusFilter } from "@/lib/operations/constants";
import { getClients } from "@/lib/operations/queries";
import { formatCnpj } from "@/lib/validation/cnpj";

type ClientsPageProps = {
  searchParams: Promise<{ q?: string; status?: string }>;
};

export default async function ClientsPage({ searchParams }: ClientsPageProps) {
  const filters = await searchParams;
  const status = parseStatusFilter(filters.status);
  const clients = await getClients({ query: filters.q, status });

  return (
    <main className="admin-main">
      <section className="page-heading page-heading-row">
        <div>
          <p className="eyebrow">Primeiro nível</p>
          <h1>Clientes</h1>
          <p>Busque por nome ou CNPJ e acesse a hierarquia completa.</p>
        </div>

        <div className="page-heading-actions">
          <Link className="primary-button" href="/admin/clientes/novo">
            Cadastrar estrutura completa
          </Link>
          <details className="create-panel">
            <summary>Cadastrar somente cliente</summary>
            <OperationalForm
              action={createClientAction}
              submitLabel="Cadastrar cliente"
            >
              <label>
                Razão social ou nome
                <input
                  autoComplete="organization"
                  name="legal_name"
                  required
                />
                <FieldError name="legal_name" />
              </label>
              <label>
                CNPJ
                <input
                  autoComplete="off"
                  inputMode="numeric"
                  name="cnpj"
                  placeholder="00.000.000/0000-00"
                  required
                />
                <FieldError name="cnpj" />
              </label>
            </OperationalForm>
          </details>
        </div>
      </section>

      <ListFilters
        query={filters.q}
        status={status}
        withSearch
      />

      <section className="listing-card">
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Cliente</th>
                <th>CNPJ</th>
                <th>Status</th>
                <th>Ações</th>
              </tr>
            </thead>
            <tbody>
              {clients.map((client) => (
                <tr key={client.id}>
                  <td>
                    <Link
                      className="record-link"
                      href={`/admin/clientes/${client.id}`}
                    >
                      {client.legal_name}
                    </Link>
                  </td>
                  <td>{formatCnpj(client.cnpj)}</td>
                  <td>
                    <StatusBadge isActive={client.is_active} />
                  </td>
                  <td>
                    <div className="row-actions">
                      <Link
                        className="secondary-button compact-button"
                        href={`/admin/clientes/${client.id}`}
                      >
                        Ver estrutura
                      </Link>
                      <details className="row-details">
                        <summary>Editar</summary>
                        <OperationalForm
                          action={editClientAction}
                          className="operational-form compact-form"
                          submitLabel="Salvar"
                        >
                          <input name="id" type="hidden" value={client.id} />
                          <label>
                            Razão social ou nome
                            <input
                              defaultValue={client.legal_name}
                              name="legal_name"
                              required
                            />
                            <FieldError name="legal_name" />
                          </label>
                          <label>
                            CNPJ
                            <input
                              defaultValue={formatCnpj(client.cnpj)}
                              name="cnpj"
                              required
                            />
                            <FieldError name="cnpj" />
                          </label>
                        </OperationalForm>
                      </details>
                      <OperationalForm
                        action={setClientStatusAction}
                        buttonClassName={
                          client.is_active
                            ? "danger-button compact-button"
                            : "secondary-button compact-button"
                        }
                        className="inline-action-form"
                        confirmation={
                          client.is_active
                            ? "Inativar este cliente? Ele deixará de aparecer nos fluxos operacionais ativos."
                            : "Reativar este cliente?"
                        }
                        submitLabel={client.is_active ? "Inativar" : "Reativar"}
                      >
                        <input name="id" type="hidden" value={client.id} />
                        <input
                          name="is_active"
                          type="hidden"
                          value={String(!client.is_active)}
                        />
                      </OperationalForm>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {clients.length === 0 ? (
          <p className="empty-state">Nenhum cliente encontrado.</p>
        ) : null}
      </section>
    </main>
  );
}

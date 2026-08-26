import { FieldError, OperationalForm } from "@/components/operational-form";
import { setSourceMappingAction } from "@/lib/admin/actions";
import {
  sourceClassifications,
  sourceClassificationLabel,
} from "@/lib/admin/constants";
import { formatAdminDateTime } from "@/lib/admin/format";
import { getSourceValues } from "@/lib/admin/queries";

export default async function SourceMappingsPage() {
  const sources = await getSourceValues();

  return (
    <main className="admin-main">
      <section className="page-heading">
        <p className="eyebrow">Acionado por</p>
        <h1>Mapeamento de origens</h1>
        <p>
          Classifique os valores encontrados nos arquivos como programação ou
          teste. Valores sem mapeamento ativo continuam desconhecidos.
        </p>
      </section>

      <aside className="reprocess-notice">
        <strong>Reprocessamento automático</strong>
        <p>
          Toda mudança solicita confirmação e reprocessa imediatamente os
          eventos, inconsistências e estados dos geradores afetados.
        </p>
      </aside>

      <section className="listing-card">
        {sources.length === 0 ? (
          <p className="empty-state">
            Nenhuma origem foi encontrada em importações confirmadas.
          </p>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Valor encontrado</th>
                  <th>Valor normalizado</th>
                  <th>Uso</th>
                  <th>Classificação atual</th>
                  <th>Alterar mapeamento</th>
                </tr>
              </thead>
              <tbody>
                {sources.map((source) => {
                  const currentClassification = source.is_active
                    ? source.classification
                    : "unknown";

                  return (
                    <tr key={source.normalized_source}>
                      <td>
                        <strong>{source.example_source}</strong>
                      </td>
                      <td>
                        <code>{source.normalized_source}</code>
                      </td>
                      <td>
                        {source.event_count.toLocaleString("pt-BR")} evento(s)
                        <small className="table-secondary-line">
                          último em {formatAdminDateTime(source.last_seen_at)}
                        </small>
                      </td>
                      <td>
                        <span
                          className={`source-status ${currentClassification}`}
                        >
                          {sourceClassificationLabel(currentClassification)}
                        </span>
                      </td>
                      <td>
                        <OperationalForm
                          action={setSourceMappingAction}
                          buttonClassName="secondary-button compact-button"
                          className="mapping-form"
                          confirmation="Confirmar a alteração? Todos os geradores com esta origem serão reprocessados."
                          pendingLabel="Reprocessando..."
                          submitLabel="Salvar e reprocessar"
                        >
                          <input
                            name="normalized_source"
                            type="hidden"
                            value={source.normalized_source}
                          />
                          <label>
                            <span className="sr-only">Nova classificação</span>
                            <select
                              defaultValue={currentClassification}
                              key={currentClassification}
                              name="classification"
                            >
                              {sourceClassifications.map((option) => (
                                <option key={option.value} value={option.value}>
                                  {option.label}
                                </option>
                              ))}
                            </select>
                            <FieldError name="classification" />
                          </label>
                        </OperationalForm>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </main>
  );
}

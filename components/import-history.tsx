import type {
  ImportBatchListItem,
  ImportSessionListItem,
} from "@/lib/imports/types";

function formatDateTime(value: string | null) {
  if (!value) return "—";

  return new Intl.DateTimeFormat("pt-BR", {
    dateStyle: "short",
    timeStyle: "medium",
  }).format(new Date(value));
}

function batchStatusLabel(status: ImportBatchListItem["status"]) {
  if (status === "confirmed") return "Confirmado";
  if (status === "failed") return "Falhou";
  return "Processando";
}

function controllerRoleLabel(role: ImportBatchListItem["dataKind"]) {
  return role === "state_events"
    ? "Estado liga/desliga"
    : "Telemetria de potência";
}

function coverageLabel(status: ImportSessionListItem["coverageStatus"]) {
  if (status === "full") return "Cobertura completa";
  if (status === "partial") return "Cobertura parcial";
  if (status === "no_intersection") return "Períodos incompatíveis";
  return "Cobertura não calculada";
}

function sessionStatusLabel(status: ImportSessionListItem["status"]) {
  return status === "confirmed" ? "Confirmada" : "Falhou";
}

function SessionBatchDetails({
  title,
  batch,
  fallbackFileName,
}: {
  title: string;
  batch: ImportSessionListItem["stateBatch"];
  fallbackFileName: string | null;
}) {
  if (!batch) {
    return (
      <div>
        <strong>{title}</strong>
        <small className="table-secondary-line">
          {fallbackFileName ?? "Lote não criado"}
        </small>
      </div>
    );
  }

  return (
    <details className="session-batch-details">
      <summary>
        {title}: {batch.fileName}
      </summary>
      <p>{batch.controllerName}</p>
      {batch.sourceTimezone ? <p>Fuso do arquivo: {batch.sourceTimezone}{batch.normalizationVersion === 0 ? " · interpretação anterior do sistema" : " · fuso informado na importação"}.</p> : null}
      <p>
        {formatDateTime(batch.periodStart)} — {formatDateTime(batch.periodEnd)}
      </p>
      <p>
        {batch.totalRows.toLocaleString("pt-BR")} linha(s) ·{" "}
        {batch.insertedRows.toLocaleString("pt-BR")} inserida(s) ·{" "}
        {batch.duplicateRows.toLocaleString("pt-BR")} duplicada(s)
      </p>
    </details>
  );
}

export function ImportHistory({
  recentSessions,
  legacyBatches,
}: {
  recentSessions: ImportSessionListItem[];
  legacyBatches: ImportBatchListItem[];
}) {
  return (
    <>
      <section className="import-panel" aria-labelledby="import-history-title">
        <div className="section-title-row">
          <div>
            <p className="eyebrow">Histórico</p>
            <h2 id="import-history-title">Atualizações conjuntas recentes</h2>
          </div>
        </div>
        {recentSessions.length === 0 ? (
          <p className="empty-state">Nenhuma sessão conjunta registrada ainda.</p>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Data e responsável</th>
                  <th>Contexto</th>
                  <th>Fontes</th>
                  <th>Cobertura</th>
                  <th>Estado</th>
                </tr>
              </thead>
              <tbody>
                {recentSessions.map((session) => (
                  <tr key={session.id}>
                    <td>
                      {formatDateTime(session.confirmedAt ?? session.createdAt)}
                      <small className="table-secondary-line">
                        {session.authorName}
                      </small>
                    </td>
                    <td>
                      {session.clientName} · {session.locationName} ·{" "}
                      {session.coldRoomName}
                      <small className="table-secondary-line">
                        {session.generatorName}
                      </small>
                    </td>
                    <td>
                      <div className="session-batches-stack">
                        <SessionBatchDetails
                          batch={session.stateBatch}
                          fallbackFileName={session.failedStateFileName}
                          title="Estado"
                        />
                        <SessionBatchDetails
                          batch={session.powerBatch}
                          fallbackFileName={session.failedPowerFileName}
                          title="Potência"
                        />
                      </div>
                    </td>
                    <td>
                      {coverageLabel(session.coverageStatus)}
                      {session.intersectionStart ? (
                        <small className="table-secondary-line">
                          Interseção: {formatDateTime(session.intersectionStart)} —{" "}
                          {formatDateTime(session.intersectionEnd)}
                        </small>
                      ) : null}
                    </td>
                    <td>
                      <span className={`import-status ${session.status}`}>
                        {sessionStatusLabel(session.status)}
                      </span>
                      {session.errorMessage ? (
                        <small className="table-secondary-line failure-detail">
                          {session.errorMessage}
                        </small>
                      ) : null}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="import-panel" aria-labelledby="legacy-history-title">
        <div className="section-title-row">
          <div>
            <p className="eyebrow">Legado</p>
            <h2 id="legacy-history-title">Importações individuais anteriores</h2>
          </div>
          <p>Sem sessão conjunta</p>
        </div>
        {legacyBatches.length === 0 ? (
          <p className="empty-state">Nenhum lote individual sem sessão.</p>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Arquivo</th>
                  <th>Tipo</th>
                  <th>Contexto</th>
                  <th>Responsável</th>
                  <th>Período</th>
                  <th>Status</th>
                  <th>Resultado</th>
                  <th>Recebido em</th>
                </tr>
              </thead>
              <tbody>
                {legacyBatches.map((batch) => (
                  <tr key={batch.id}>
                    <td>{batch.fileName}</td>
                    <td>{controllerRoleLabel(batch.dataKind)}</td>
                    <td>
                      {batch.clientName} · {batch.locationName} ·{" "}
                      {batch.coldRoomName}
                      <small className="table-secondary-line">
                        {batch.generatorName} · {batch.controllerName}
                      </small>
                    </td>
                    <td>{batch.authorName}</td>
                    <td>
                      {batch.periodStart
                        ? `${formatDateTime(batch.periodStart)} — ${formatDateTime(
                            batch.periodEnd,
                          )}`
                        : "—"}
                    </td>
                    <td>
                      <span className={`import-status ${batch.status}`}>
                        {batchStatusLabel(batch.status)}
                      </span>
                    </td>
                    <td>
                      {batch.status === "failed" ? (
                        <span className="failure-detail">
                          {batch.errorMessage ??
                            "Falha sem mensagem registrada."}
                        </span>
                      ) : (
                        <span>
                          {batch.insertedRows.toLocaleString("pt-BR")} inserida(s)
                          · {batch.duplicateRows.toLocaleString("pt-BR")} duplicada(s)
                          {batch.dataKind === "state_events"
                            ? ` · ${batch.unknownSourceRows.toLocaleString(
                                "pt-BR",
                              )} desconhecida(s)`
                            : ""}
                          <small className="table-secondary-line">
                            {batch.totalRows.toLocaleString("pt-BR")} linha(s) no
                            total
                          </small>
                        </span>
                      )}
                    </td>
                    <td>{formatDateTime(batch.createdAt)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </>
  );
}

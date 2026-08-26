"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";

import {
  confirmXlsxImport,
  previewXlsxImport,
} from "@/lib/imports/actions";
import {
  IMPORT_BUCKET,
  MAX_IMPORT_FILE_BYTES,
  XLSX_MIME_TYPE,
} from "@/lib/imports/constants";
import type {
  ImportActionResult,
  ImportBatchListItem,
  ImportContext,
  ImportFormOptions,
} from "@/lib/imports/types";
import { createClient } from "@/lib/supabase/client";

type Selection = {
  clientId: string;
  locationId: string;
  coldRoomId: string;
  generatorId: string;
  controllerId: string;
};

const emptySelection: Selection = {
  clientId: "",
  locationId: "",
  coldRoomId: "",
  generatorId: "",
  controllerId: "",
};

function formatDateTime(value: string | null, timeZone?: string) {
  if (!value) {
    return "—";
  }

  return new Intl.DateTimeFormat("pt-BR", {
    dateStyle: "short",
    timeStyle: "medium",
    timeZone,
  }).format(new Date(value));
}

function formatFileSize(bytes: number) {
  if (bytes < 1024 * 1024) {
    return new Intl.NumberFormat("pt-BR", {
      style: "unit",
      unit: "kilobyte",
      maximumFractionDigits: 1,
    }).format(bytes / 1024);
  }

  return new Intl.NumberFormat("pt-BR", {
    style: "unit",
    unit: "megabyte",
    maximumFractionDigits: 2,
  }).format(bytes / 1024 / 1024);
}

function operationLabel(operation: "turn_on" | "turn_off") {
  return operation === "turn_on" ? "Ligar" : "Desligar";
}

function classificationLabel(classification: string) {
  if (classification === "programmed") return "Programada";
  if (classification === "test") return "Teste";
  return "Desconhecida";
}

function batchStatusLabel(status: ImportBatchListItem["status"]) {
  if (status === "confirmed") return "Confirmado";
  if (status === "failed") return "Falhou";
  return "Processando";
}

export function ImportWorkflow({
  profileId,
  options,
  recentBatches,
}: {
  profileId: string;
  options: ImportFormOptions;
  recentBatches: ImportBatchListItem[];
}) {
  const router = useRouter();
  const [selection, setSelection] = useState<Selection>(emptySelection);
  const [file, setFile] = useState<File | null>(null);
  const [result, setResult] = useState<ImportActionResult | null>(null);
  const [previewKey, setPreviewKey] = useState<string | null>(null);
  const [busy, setBusy] = useState<"preview" | "confirm" | null>(null);

  const locations = useMemo(
    () =>
      options.locations.filter(
        (location) => location.clientId === selection.clientId,
      ),
    [options.locations, selection.clientId],
  );
  const coldRooms = useMemo(
    () =>
      options.coldRooms.filter(
        (room) =>
          room.clientId === selection.clientId &&
          room.locationId === selection.locationId,
      ),
    [options.coldRooms, selection.clientId, selection.locationId],
  );
  const generators = useMemo(
    () =>
      options.generators.filter(
        (generator) =>
          generator.clientId === selection.clientId &&
          generator.locationId === selection.locationId &&
          generator.coldRoomId === selection.coldRoomId,
      ),
    [
      options.generators,
      selection.clientId,
      selection.locationId,
      selection.coldRoomId,
    ],
  );
  const controllers = useMemo(
    () =>
      options.controllers.filter(
        (controller) =>
          controller.clientId === selection.clientId &&
          controller.generatorId === selection.generatorId,
      ),
    [options.controllers, selection.clientId, selection.generatorId],
  );
  const contextComplete = Object.values(selection).every(Boolean);
  const currentKey = file
    ? [
        file.name,
        file.size,
        file.lastModified,
        ...Object.values(selection),
      ].join("|")
    : "";
  const currentPreview =
    result?.status === "preview" && previewKey === currentKey
      ? result.preview
      : null;

  function invalidatePreview() {
    setResult(null);
    setPreviewKey(null);
  }

  function updateSelection(next: Selection) {
    setSelection(next);
    invalidatePreview();
  }

  function selectFile(selectedFile: File | null) {
    setFile(selectedFile);
    invalidatePreview();

    if (!selectedFile) return;

    if (!selectedFile.name.toLocaleLowerCase("pt-BR").endsWith(".xlsx")) {
      setResult({ status: "error", message: "Selecione um arquivo .xlsx." });
    } else if (selectedFile.size === 0) {
      setResult({ status: "error", message: "O arquivo selecionado está vazio." });
    } else if (selectedFile.size > MAX_IMPORT_FILE_BYTES) {
      setResult({ status: "error", message: "O arquivo excede o limite de 5 MB." });
    }
  }

  async function sendTemporaryFile(
    action: "preview" | "confirm",
  ): Promise<ImportActionResult> {
    if (!file || !contextComplete) {
      return {
        status: "error",
        message: "Selecione a hierarquia completa e um arquivo XLSX.",
      };
    }

    const objectPath = `${profileId}/${crypto.randomUUID()}.xlsx`;
    const supabase = createClient();
    const { error: uploadError } = await supabase.storage
      .from(IMPORT_BUCKET)
      .upload(objectPath, file, {
        contentType: XLSX_MIME_TYPE,
        upsert: false,
      });

    if (uploadError) {
      return {
        status: "error",
        message: "Não foi possível enviar o arquivo temporário. Tente novamente.",
      };
    }

    const context: ImportContext = selection;

    try {
      if (action === "preview") {
        return await previewXlsxImport({ objectPath, fileName: file.name, context });
      }

      if (!currentPreview) {
        return {
          status: "error",
          message: "A prévia não corresponde à seleção atual.",
        };
      }

      return await confirmXlsxImport({
        objectPath,
        fileName: file.name,
        context,
        expectedFileSha256: currentPreview.fileSha256,
      });
    } finally {
      await supabase.storage.from(IMPORT_BUCKET).remove([objectPath]);
    }
  }

  async function handlePreview() {
    setBusy("preview");
    setResult(null);
    try {
      const response = await sendTemporaryFile("preview");
      setResult(response);
      setPreviewKey(response.status === "preview" ? currentKey : null);
    } catch {
      setResult({
        status: "error",
        message: "A validação foi interrompida. Tente novamente.",
      });
      setPreviewKey(null);
    } finally {
      setBusy(null);
    }
  }

  async function handleConfirmation() {
    if (
      !currentPreview ||
      !window.confirm(
        `Confirmar a importação de ${currentPreview.totalRows.toLocaleString("pt-BR")} evento(s)?`,
      )
    ) {
      return;
    }

    setBusy("confirm");
    try {
      const response = await sendTemporaryFile("confirm");
      setResult(response);
      setPreviewKey(null);

      if (response.status === "confirmed") {
        router.refresh();
      }
    } catch {
      setResult({
        status: "error",
        message: "A confirmação foi interrompida. Tente novamente.",
      });
      setPreviewKey(null);
    } finally {
      setBusy(null);
    }
  }

  const fileIsValid =
    file !== null &&
    file.size > 0 &&
    file.size <= MAX_IMPORT_FILE_BYTES &&
    file.name.toLocaleLowerCase("pt-BR").endsWith(".xlsx");

  return (
    <div className="import-workflow">
      <section className="import-panel" aria-labelledby="import-selection-title">
        <div className="section-title-row">
          <div>
            <p className="eyebrow">Etapa 1</p>
            <h2 id="import-selection-title">Contexto e arquivo</h2>
          </div>
          <p>XLSX de até 5 MB e 25.000 linhas</p>
        </div>

        <div className="import-form">
          <div className="import-selector-grid">
            <label>
              Cliente
              <select
                disabled={busy !== null}
                onChange={(event) =>
                  updateSelection({
                    ...emptySelection,
                    clientId: event.target.value,
                  })
                }
                value={selection.clientId}
              >
                <option value="">Selecione</option>
                {options.clients.map((client) => (
                  <option key={client.id} value={client.id}>
                    {client.legalName}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Unidade
              <select
                disabled={!selection.clientId || busy !== null}
                onChange={(event) =>
                  updateSelection({
                    ...emptySelection,
                    clientId: selection.clientId,
                    locationId: event.target.value,
                  })
                }
                value={selection.locationId}
              >
                <option value="">Selecione</option>
                {locations.map((location) => (
                  <option key={location.id} value={location.id}>
                    {location.name} · {location.timeZone}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Câmara
              <select
                disabled={!selection.locationId || busy !== null}
                onChange={(event) =>
                  updateSelection({
                    ...emptySelection,
                    clientId: selection.clientId,
                    locationId: selection.locationId,
                    coldRoomId: event.target.value,
                  })
                }
                value={selection.coldRoomId}
              >
                <option value="">Selecione</option>
                {coldRooms.map((room) => (
                  <option key={room.id} value={room.id}>
                    {room.name}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Gerador
              <select
                disabled={!selection.coldRoomId || busy !== null}
                onChange={(event) =>
                  updateSelection({
                    ...emptySelection,
                    clientId: selection.clientId,
                    locationId: selection.locationId,
                    coldRoomId: selection.coldRoomId,
                    generatorId: event.target.value,
                  })
                }
                value={selection.generatorId}
              >
                <option value="">Selecione</option>
                {generators.map((generator) => (
                  <option key={generator.id} value={generator.id}>
                    {generator.identifier}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Controlador
              <select
                disabled={!selection.generatorId || busy !== null}
                onChange={(event) =>
                  updateSelection({
                    ...selection,
                    controllerId: event.target.value,
                  })
                }
                value={selection.controllerId}
              >
                <option value="">Selecione</option>
                {controllers.map((controller) => (
                  <option key={controller.id} value={controller.id}>
                    {controller.identifier}
                  </option>
                ))}
              </select>
            </label>
          </div>

          <label className="file-picker">
            <span>Arquivo eWeLink</span>
            <input
              accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
              disabled={busy !== null}
              onChange={(event) => selectFile(event.target.files?.[0] ?? null)}
              type="file"
            />
            <small>
              {file
                ? `${file.name} · ${formatFileSize(file.size)}`
                : "Cabeçalhos: Tempo, Operação e Acionado por."}
            </small>
          </label>

          {result?.status === "error" ? (
            <p className="form-message error" role="alert">
              {result.message}
            </p>
          ) : null}

          {result?.status === "confirmed" ? (
            <p className="form-message success" role="status">
              {result.confirmation.alreadyConfirmed
                ? "Este arquivo já havia sido confirmado neste contexto. Nenhum evento foi duplicado."
                : `Importação confirmada: ${result.confirmation.insertedRows.toLocaleString("pt-BR")} evento(s) inserido(s) e ${result.confirmation.duplicateRows.toLocaleString("pt-BR")} ignorado(s) como duplicata.`}
            </p>
          ) : null}

          <button
            className="primary-button import-action"
            disabled={!contextComplete || !fileIsValid || busy !== null}
            onClick={handlePreview}
            type="button"
          >
            {busy === "preview" ? "Validando arquivo..." : "Validar e gerar prévia"}
          </button>
        </div>
      </section>

      {currentPreview ? (
        <section className="import-panel" aria-labelledby="import-preview-title">
          <div className="section-title-row">
            <div>
              <p className="eyebrow">Etapa 2</p>
              <h2 id="import-preview-title">Prévia transitória</h2>
            </div>
            <p>
              Aba “{currentPreview.sheetName}” · hash {currentPreview.fileSha256.slice(0, 10)}…
            </p>
          </div>

          <dl className="import-summary-grid">
            <div>
              <dt>Linhas válidas</dt>
              <dd>{currentPreview.totalRows.toLocaleString("pt-BR")}</dd>
            </div>
            <div>
              <dt>Já existentes</dt>
              <dd>
                {currentPreview.existingDuplicateRows.toLocaleString("pt-BR")}
              </dd>
            </div>
            <div>
              <dt>Repetidas no arquivo</dt>
              <dd>{currentPreview.repeatedFileRows.toLocaleString("pt-BR")}</dd>
            </div>
            <div>
              <dt>Origens desconhecidas</dt>
              <dd>{currentPreview.unknownSourceRows.toLocaleString("pt-BR")}</dd>
            </div>
            <div>
              <dt>Primeiro evento</dt>
              <dd>
                {formatDateTime(
                  currentPreview.periodStart,
                  currentPreview.timeZone,
                )}
              </dd>
            </div>
            <div>
              <dt>Último evento</dt>
              <dd>
                {formatDateTime(
                  currentPreview.periodEnd,
                  currentPreview.timeZone,
                )}
              </dd>
            </div>
          </dl>

          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Linha</th>
                  <th>Tempo original</th>
                  <th>Horário interpretado</th>
                  <th>Operação</th>
                  <th>Acionado por</th>
                  <th>Classificação</th>
                </tr>
              </thead>
              <tbody>
                {currentPreview.sample.map((row) => (
                  <tr key={row.rowNumber}>
                    <td>{row.rowNumber}</td>
                    <td>{row.occurredAtRaw}</td>
                    <td>
                      {formatDateTime(row.occurredAt, currentPreview.timeZone)}
                    </td>
                    <td title={`Original: ${row.operationRaw}`}>
                      {operationLabel(row.operation)}
                    </td>
                    <td>{row.sourceOriginal || "(vazio)"}</td>
                    <td>{classificationLabel(row.sourceClassification)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="import-confirmation-bar">
            <p>
              O arquivo será enviado e validado novamente. Apenas a confirmação
              cria o lote e os eventos.
            </p>
            <button
              className="primary-button"
              disabled={busy !== null}
              onClick={handleConfirmation}
              type="button"
            >
              {busy === "confirm" ? "Confirmando..." : "Confirmar importação"}
            </button>
          </div>
        </section>
      ) : null}

      <section className="import-panel" aria-labelledby="import-history-title">
        <div className="section-title-row">
          <div>
            <p className="eyebrow">Histórico</p>
            <h2 id="import-history-title">Importações recentes</h2>
          </div>
        </div>
        {recentBatches.length === 0 ? (
          <p className="empty-state">Nenhuma importação registrada ainda.</p>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Arquivo</th>
                  <th>Contexto</th>
                  <th>Responsável</th>
                  <th>Período</th>
                  <th>Status</th>
                  <th>Resultado</th>
                  <th>Recebido em</th>
                </tr>
              </thead>
              <tbody>
                {recentBatches.map((batch) => (
                  <tr key={batch.id}>
                    <td>{batch.fileName}</td>
                    <td>
                      {batch.clientName} · {batch.locationName} · {batch.coldRoomName}
                      <small className="table-secondary-line">
                        {batch.generatorName} · {batch.controllerName}
                      </small>
                    </td>
                    <td>{batch.authorName}</td>
                    <td>
                      {batch.periodStart
                        ? `${formatDateTime(batch.periodStart)} — ${formatDateTime(batch.periodEnd)}`
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
                          {batch.errorMessage ?? "Falha sem mensagem registrada."}
                        </span>
                      ) : (
                        <span>
                          {batch.insertedRows.toLocaleString("pt-BR")} inserida(s) ·{" "}
                          {batch.duplicateRows.toLocaleString("pt-BR")} duplicada(s) ·{" "}
                          {batch.unknownSourceRows.toLocaleString("pt-BR")} desconhecida(s)
                          <small className="table-secondary-line">
                            {batch.totalRows.toLocaleString("pt-BR")} linha(s) no total
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
    </div>
  );
}

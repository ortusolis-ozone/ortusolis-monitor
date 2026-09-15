"use client";

import { useMemo, useState } from "react";
import { POWER_TIMEZONES } from "@/lib/imports/timezone";
import { useRouter } from "next/navigation";

import {
  confirmImportSession,
  previewXlsxImport,
  previewImportSession,
} from "@/lib/imports/actions";
import {
  IMPORT_BUCKET,
  MAX_IMPORT_FILE_BYTES,
  XLSX_MIME_TYPE,
} from "@/lib/imports/constants";
import {
  aggregateImportSessionStatus,
  compareImportPeriods,
  missingImportSourceMessage,
  type ImportCoverage,
} from "@/lib/imports/session";
import type {
  ImportOperationalSummary,
  ImportContext,
  ImportControllerOption,
  ImportFormOptions,
  ImportPreview,
  ImportSessionConfirmation,
  ImportSourceStatus,
  LatestImportSource,
} from "@/lib/imports/types";
import { createClient } from "@/lib/supabase/client";

import { ImportOperationalPreview } from "./import-operational-preview";

type SourceKey = "state" | "power";

type Selection = {
  clientId: string;
  locationId: string;
  coldRoomId: string;
  generatorId: string;
};

type SourceSlot = {
  controllerId: string;
  file: File | null;
  preview: ImportPreview | null;
  error: string | null;
  validating: boolean;
  confirmed: boolean;
};

const emptySelection: Selection = {
  clientId: "",
  locationId: "",
  coldRoomId: "",
  generatorId: "",
};

const emptySourceSlot: SourceSlot = {
  controllerId: "",
  file: null,
  preview: null,
  error: null,
  validating: false,
  confirmed: false,
};

const sourceStatusLabels: Record<ImportSourceStatus, string> = {
  empty: "Não selecionado",
  selected: "Pronto para validar",
  validating: "Validando",
  valid: "Validado",
  already_imported: "Já importado",
  invalid: "Arquivo incompatível",
  confirmed: "Importado com sucesso",
};

function formatDateTime(value: string | null, timeZone?: string) {
  if (!value) return "—";

  return new Intl.DateTimeFormat("pt-BR", {
    dateStyle: "short",
    timeStyle: "medium",
    timeZone,
  }).format(new Date(value));
}

function formatControllerDateTime(value: string, timeZone?: string) {
  return new Intl.DateTimeFormat("pt-BR", {
    dateStyle: "short",
    timeStyle: "short",
    timeZone,
  }).format(new Date(value));
}

function controllerValidityLabel(
  controller: ImportControllerOption,
  timeZone?: string,
) {
  const activatedAt = formatControllerDateTime(controller.activatedAt, timeZone);

  if (controller.isActive) return `ativo desde ${activatedAt}`;
  if (!controller.deactivatedAt) return `histórico desde ${activatedAt}`;

  return `histórico: ${activatedAt} até antes de ${formatControllerDateTime(
    controller.deactivatedAt,
    timeZone,
  )}`;
}

function controllerOptionLabel(
  controller: ImportControllerOption,
  timeZone?: string,
) {
  return `${controller.identifier} — ${controllerValidityLabel(
    controller,
    timeZone,
  )}`;
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

function electricalStateLabel(state: "on" | "off" | "hysteresis") {
  if (state === "on") return "Ligada";
  if (state === "off") return "Desligada";
  return "Zona de histerese";
}

function formatPower(power: number) {
  return `${new Intl.NumberFormat("pt-BR", {
    maximumFractionDigits: 3,
  }).format(power)} W`;
}

function sourceStatus(slot: SourceSlot): ImportSourceStatus {
  if (slot.validating) return "validating";
  if (slot.error) return "invalid";
  if (slot.confirmed) return "confirmed";
  if (slot.preview?.alreadyImported) return "already_imported";
  if (slot.preview) return "valid";
  if (slot.file) return "selected";
  return "empty";
}

function LatestSourceSummary({
  source,
  timeZone,
}: {
  source: LatestImportSource | undefined;
  timeZone?: string;
}) {
  if (!source) {
    return (
      <p className="source-persisted-empty">
        Nenhuma confirmação anterior para este controlador.
      </p>
    );
  }

  return (
    <div className="source-persisted-summary">
      <p>
        <strong>Última confirmação</strong> · {formatDateTime(source.confirmedAt)}
      </p>
      <p>{source.fileName}</p>
      <p>
        {formatDateTime(source.periodStart, timeZone)} —{" "}
        {formatDateTime(source.periodEnd, timeZone)} ·{" "}
        {source.totalRows.toLocaleString("pt-BR")} linha(s)
      </p>
      <p>Responsável: {source.authorName}</p>
    </div>
  );
}

function StatePreview({ preview }: { preview: ImportPreview }) {
  if (preview.dataKind !== "state_events") return null;

  return (
    <div className="source-preview" aria-label="Prévia do arquivo de estado">
      <dl className="source-preview-summary">
        <div>
          <dt>Linhas válidas</dt>
          <dd>{preview.totalRows.toLocaleString("pt-BR")}</dd>
        </div>
        <div>
          <dt>Já existentes</dt>
          <dd>{preview.existingDuplicateRows.toLocaleString("pt-BR")}</dd>
        </div>
        <div>
          <dt>Repetidas</dt>
          <dd>{preview.repeatedFileRows.toLocaleString("pt-BR")}</dd>
        </div>
        <div>
          <dt>Origens desconhecidas</dt>
          <dd>{preview.unknownSourceRows.toLocaleString("pt-BR")}</dd>
        </div>
      </dl>
      <div className="table-wrap source-preview-table">
        <table>
          <thead>
            <tr>
              <th>Linha</th>
              <th>Horário</th>
              <th>Operação</th>
              <th>Acionado por</th>
              <th>Classificação</th>
            </tr>
          </thead>
          <tbody>
            {preview.sample.map((row) => (
              <tr key={row.rowNumber}>
                <td>{row.rowNumber}</td>
                <td title={`Original: ${row.occurredAtRaw}`}>
                  {formatDateTime(row.occurredAt, preview.timeZone)}
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
    </div>
  );
}

function PowerPreview({ preview }: { preview: ImportPreview }) {
  if (preview.dataKind !== "power_readings") return null;

  return (
    <div className="source-preview" aria-label="Prévia do arquivo de potência">
      <p>Fuso do arquivo: {preview.sourceTimezone}. Horários exibidos em {preview.timeZone}.</p>
      <p>Período original: {preview.rawPeriodStart} — {preview.rawPeriodEnd}.</p>
      <dl className="source-preview-summary">
        <div>
          <dt>Linhas válidas</dt>
          <dd>{preview.totalRows.toLocaleString("pt-BR")}</dd>
        </div>
        <div>
          <dt>Já existentes</dt>
          <dd>{preview.existingDuplicateRows.toLocaleString("pt-BR")}</dd>
        </div>
        <div>
          <dt>Potência mínima</dt>
          <dd>{formatPower(preview.minPowerW)}</dd>
        </div>
        <div>
          <dt>Potência máxima</dt>
          <dd>{formatPower(preview.maxPowerW)}</dd>
        </div>
      </dl>
      <p className="source-preview-note">
        {preview.deviceName} · {preview.onRows} ligada(s) · {preview.offRows}{" "}
        desligada(s) · {preview.hysteresisRows} em histerese
      </p>
      <div className="table-wrap source-preview-table">
        <table>
          <thead>
            <tr>
              <th>Linha</th>
              <th>Horário</th>
              <th>Potência</th>
              <th>Estado elétrico</th>
              <th>Dispositivo</th>
            </tr>
          </thead>
          <tbody>
            {preview.sample.map((row) => (
              <tr key={row.rowNumber}>
                <td>{row.rowNumber}</td>
                <td title={`Original: ${row.occurredAtRaw}`}>
                  {formatDateTime(row.occurredAt, preview.timeZone)}
                </td>
                <td title={`Original: ${row.powerRaw}`}>
                  {formatPower(row.powerW)}
                </td>
                <td>{electricalStateLabel(row.electricalState)}</td>
                <td>{row.deviceName}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function coverageGapText(coverage: ImportCoverage, timeZone?: string) {
  if (coverage.status !== "partial") return null;

  const gaps = [coverage.uncoveredBefore, coverage.uncoveredAfter]
    .filter((gap): gap is { start: string; end: string } => gap !== null)
    .map(
      (gap) =>
        `${formatDateTime(gap.start, timeZone)} — ${formatDateTime(
          gap.end,
          timeZone,
        )}`,
    );

  return gaps.join("; ");
}

export function ImportWorkflow({
  profileId,
  options,
  latestSources,
}: {
  profileId: string;
  options: ImportFormOptions;
  latestSources: LatestImportSource[];
}) {
  const router = useRouter();
  const [selection, setSelection] = useState<Selection>(emptySelection);
  const [stateSlot, setStateSlot] = useState<SourceSlot>(emptySourceSlot);
  const [powerSlot, setPowerSlot] = useState<SourceSlot>(emptySourceSlot);
  const [powerTimezone, setPowerTimezone] = useState("");
  const [coverageAcknowledged, setCoverageAcknowledged] = useState(false);
  const [operationalPreview, setOperationalPreview] = useState<ImportOperationalSummary | null>(null);
  const [projecting, setProjecting] = useState(false);
  const [confirming, setConfirming] = useState(false);
  const [sessionError, setSessionError] = useState<string | null>(null);
  const [confirmation, setConfirmation] =
    useState<ImportSessionConfirmation | null>(null);

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
  const stateControllers = controllers.filter(
    (controller) => controller.role === "state",
  );
  const powerControllers = controllers.filter(
    (controller) => controller.role === "power_telemetry",
  );
  const selectedTimeZone = options.locations.find(
    (location) => location.id === selection.locationId,
  )?.timeZone;
  const contextComplete = Object.values(selection).every(Boolean);
  const anyBusy = stateSlot.validating || powerSlot.validating || confirming || projecting;
  const stateFileStatus = sourceStatus(stateSlot);
  const powerFileStatus = sourceStatus(powerSlot);
  const statePreview =
    stateSlot.preview?.dataKind === "state_events" ? stateSlot.preview : null;
  const powerPreview =
    powerSlot.preview?.dataKind === "power_readings" ? powerSlot.preview : null;
  const coverage =
    statePreview && powerPreview
      ? compareImportPeriods(
          { start: statePreview.periodStart, end: statePreview.periodEnd },
          { start: powerPreview.periodStart, end: powerPreview.periodEnd },
        )
      : null;
  const aggregateStatus = aggregateImportSessionStatus({
    stateStatus: stateFileStatus,
    powerStatus: powerFileStatus,
    coverageStatus: coverage?.status,
    confirming,
    confirmed: confirmation !== null,
    failed: sessionError !== null && Boolean(statePreview && powerPreview),
  });
  const missingMessage = missingImportSourceMessage(
    stateFileStatus,
    powerFileStatus,
  );
  const latestStateSource = latestSources.find(
    (source) =>
      source.clientId === selection.clientId &&
      source.locationId === selection.locationId &&
      source.coldRoomId === selection.coldRoomId &&
      source.generatorId === selection.generatorId &&
      source.controllerId === stateSlot.controllerId,
  );
  const latestPowerSource = latestSources.find(
    (source) =>
      source.clientId === selection.clientId &&
      source.locationId === selection.locationId &&
      source.coldRoomId === selection.coldRoomId &&
      source.generatorId === selection.generatorId &&
      source.controllerId === powerSlot.controllerId,
  );

  function invalidateSession() {
    setOperationalPreview(null);
    setCoverageAcknowledged(false);
    setSessionError(null);
    setConfirmation(null);
  }

  function invalidateSlot(slot: SourceSlot): SourceSlot {
    return {
      ...slot,
      preview: null,
      error: null,
      confirmed: false,
    };
  }

  function replaceSelection(next: Selection) {
    setSelection(next);
    setStateSlot((current) => invalidateSlot(current));
    setPowerSlot((current) => invalidateSlot(current));
    invalidateSession();
  }

  function selectGenerator(generatorId: string) {
    const availableControllers = options.controllers.filter(
      (controller) =>
        controller.clientId === selection.clientId &&
        controller.generatorId === generatorId,
    );
    const defaultStateController = availableControllers.find(
      (controller) => controller.role === "state" && controller.isActive,
    );
    const defaultPowerController = availableControllers.find(
      (controller) =>
        controller.role === "power_telemetry" && controller.isActive,
    );

    setSelection({ ...selection, generatorId });
    setStateSlot((current) => ({
      ...invalidateSlot(current),
      controllerId: defaultStateController?.id ?? "",
    }));
    setPowerSlot((current) => ({
      ...invalidateSlot(current),
      controllerId: defaultPowerController?.id ?? "",
    }));
    invalidateSession();
  }

  function updateSourceController(source: SourceKey, controllerId: string) {
    const update = (current: SourceSlot) => ({
      ...invalidateSlot(current),
      controllerId,
    });
    if (source === "state") setStateSlot(update);
    else setPowerSlot(update);
    invalidateSession();
  }

  function validateFileSelection(file: File | null) {
    if (!file) return null;
    if (!file.name.toLocaleLowerCase("pt-BR").endsWith(".xlsx")) {
      return "Selecione um arquivo .xlsx.";
    }
    if (file.size === 0) return "O arquivo selecionado está vazio.";
    if (file.size > MAX_IMPORT_FILE_BYTES) {
      return "O arquivo excede o limite de 5 MB.";
    }
    return null;
  }

  function selectFile(source: SourceKey, file: File | null) {
    const update = (current: SourceSlot): SourceSlot => ({
      ...current,
      file,
      preview: null,
      error: validateFileSelection(file),
      confirmed: false,
    });
    if (source === "state") setStateSlot(update);
    else setPowerSlot(update);
    invalidateSession();
  }

  function importContext(controllerId: string): ImportContext {
    return { ...selection, controllerId };
  }

  async function uploadTemporaryFile(file: File) {
    const objectPath = `${profileId}/${crypto.randomUUID()}.xlsx`;
    const supabase = createClient();
    const { error } = await supabase.storage
      .from(IMPORT_BUCKET)
      .upload(objectPath, file, {
        contentType: XLSX_MIME_TYPE,
        upsert: false,
      });

    if (error) {
      throw new Error(
        "Não foi possível enviar o arquivo temporário. Tente novamente.",
      );
    }

    return objectPath;
  }

  async function removeTemporaryFiles(objectPaths: string[]) {
    if (objectPaths.length === 0) return;
    await createClient().storage.from(IMPORT_BUCKET).remove(objectPaths);
  }

  async function handlePreview(source: SourceKey) {
    const slot = source === "state" ? stateSlot : powerSlot;
    const setSlot = source === "state" ? setStateSlot : setPowerSlot;
    const expectedDataKind =
      source === "state" ? "state_events" : "power_readings";

    if (!contextComplete || !slot.controllerId || !slot.file) {
      setSlot((current) => ({
        ...current,
        error: "Selecione o contexto, o controlador e o arquivo deste campo.",
      }));
      return;
    }

    if (source === "power" && !powerTimezone) {
      setPowerSlot(current => ({ ...current, error: "Selecione o fuso horário do arquivo de potência." }));
      return;
    }

    setSlot((current) => ({
      ...current,
      validating: true,
      error: null,
      preview: null,
      confirmed: false,
    }));
    invalidateSession();
    let objectPath: string | null = null;

    try {
      objectPath = await uploadTemporaryFile(slot.file);
      const response = await previewXlsxImport({
        objectPath,
        fileName: slot.file.name,
        context: importContext(slot.controllerId),
        expectedDataKind,
        ...(source === "power" ? { sourceTimezone: powerTimezone } : {}),
      });

      if (response.status !== "preview") {
        setSlot((current) => ({
          ...current,
          preview: null,
          error:
            response.status === "error"
              ? response.message
              : "A validação retornou um resultado inesperado.",
        }));
        return;
      }

      setSlot((current) => ({
        ...current,
        preview: response.preview,
        error: null,
      }));
    } catch (error) {
      setSlot((current) => ({
        ...current,
        preview: null,
        error:
          error instanceof Error
            ? error.message
            : "A validação foi interrompida. Tente novamente.",
      }));
    } finally {
      if (objectPath) await removeTemporaryFiles([objectPath]);
      setSlot((current) => ({ ...current, validating: false }));
    }
  }

  async function handleConfirmation(previewOnly = false) {
    if (
      !stateSlot.file ||
      !powerSlot.file ||
      !statePreview ||
      !powerPreview ||
      !stateSlot.controllerId ||
      !powerSlot.controllerId ||
      !coverage ||
      coverage.status === "no_intersection" ||
      (!previewOnly && (coverage.status === "partial" && !coverageAcknowledged)) ||
      (!previewOnly && !operationalPreview)
    ) {
      return;
    }

    if (
      !previewOnly && !window.confirm(
        "Confirmar esta atualização conjunta de estado e potência?",
      )
    ) {
      return;
    }

    if (previewOnly) {
      setProjecting(true);
      setOperationalPreview(null);
    } else {
      setConfirming(true);
    }
    setSessionError(null);
    setConfirmation(null);
    const uploadedPaths: string[] = [];

    try {
      const uploads = await Promise.allSettled([
        uploadTemporaryFile(stateSlot.file),
        uploadTemporaryFile(powerSlot.file),
      ]);
      for (const upload of uploads) {
        if (upload.status === "fulfilled") uploadedPaths.push(upload.value);
      }
      const failedUpload = uploads.find(
        (upload): upload is PromiseRejectedResult =>
          upload.status === "rejected",
      );
      if (failedUpload) throw failedUpload.reason;

      const response = await (previewOnly ? previewImportSession : confirmImportSession)({
        context: selection,
        state: {
          objectPath: uploadedPaths[0],
          fileName: stateSlot.file.name,
          context: importContext(stateSlot.controllerId),
          expectedFileSha256: statePreview.fileSha256,
          expectedDataKind: "state_events",
        },
        power: {
          objectPath: uploadedPaths[1],
          fileName: powerSlot.file.name,
          context: importContext(powerSlot.controllerId),
          expectedFileSha256: powerPreview.fileSha256,
          expectedDataKind: "power_readings",
          sourceTimezone: powerTimezone,
          expectedSourceTimezone: powerPreview.sourceTimezone,
        },
        coverageWarningAcknowledged: coverageAcknowledged,
      });

      if (response.status === "error") {
        setOperationalPreview(null);
        setSessionError(response.message);
        return;
      }

      if (response.status === "preview") {
        setOperationalPreview(response.preview);
        return;
      }
      setOperationalPreview(response.confirmation.operationalSummary);
      setConfirmation(response.confirmation);
      setStateSlot((current) => ({ ...current, confirmed: true }));
      setPowerSlot((current) => ({ ...current, confirmed: true }));
      router.refresh();
    } catch (error) {
      setSessionError(
        error instanceof Error
          ? error.message
          : "A confirmação foi interrompida. Tente novamente.",
      );
    } finally {
      await removeTemporaryFiles(uploadedPaths);
      setConfirming(false);
      setProjecting(false);
    }
  }

  const confirmationDisabled =
    !operationalPreview ||
    !coverage ||
    coverage.status === "no_intersection" ||
    (coverage.status === "partial" && !coverageAcknowledged) ||
    !["valid", "already_imported", "confirmed"].includes(stateFileStatus) ||
    !["valid", "already_imported", "confirmed"].includes(powerFileStatus);

  return (
    <div className="import-workflow">
      <section className="import-panel" aria-labelledby="import-selection-title">
        <div className="section-title-row">
          <div>
            <p className="eyebrow">Etapa 1</p>
            <h2 id="import-selection-title">Contexto da atualização</h2>
          </div>
          <p>Cliente → Unidade → Câmara → Gerador</p>
        </div>

        <div className="import-form">
          <div className="import-selector-grid context-selector-grid">
            <label>
              Cliente
              <select
                disabled={anyBusy}
                onChange={(event) =>
                  replaceSelection({
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
                disabled={!selection.clientId || anyBusy}
                onChange={(event) =>
                  replaceSelection({
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
                disabled={!selection.locationId || anyBusy}
                onChange={(event) =>
                  replaceSelection({
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
                disabled={!selection.coldRoomId || anyBusy}
                onChange={(event) => selectGenerator(event.target.value)}
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
          </div>
        </div>
      </section>

      {selection.generatorId ? (
        <section aria-labelledby="import-sources-title">
          <div className="import-section-heading">
            <div>
              <p className="eyebrow">Etapa 2</p>
              <h2 id="import-sources-title">Arquivos complementares</h2>
            </div>
            <p>Dois XLSX independentes, de até 5 MB e 25.000 linhas cada.</p>
          </div>

          <div className="import-source-grid">
            <article
              className="import-source-card state-source-card"
              aria-labelledby="state-source-title"
            >
              <header className="import-source-header">
                <span className="source-number" aria-hidden="true">
                  01
                </span>
                <div>
                  <p className="source-kicker">Estado liga/desliga</p>
                  <h3 id="state-source-title">
                    Horários programados — Liga/desliga
                  </h3>
                  <p>Eventos Tempo, Operação e Acionado por.</p>
                </div>
              </header>

              <div className="import-source-body">
                <label className="source-controller-select">
                  Controlador de estado
                  <select
                    disabled={anyBusy}
                    onChange={(event) =>
                      updateSourceController("state", event.target.value)
                    }
                    value={stateSlot.controllerId}
                  >
                    <option value="">Selecione</option>
                    {stateControllers.map((controller) => (
                      <option key={controller.id} value={controller.id}>
                        {controllerOptionLabel(controller, selectedTimeZone)}
                      </option>
                    ))}
                  </select>
                </label>

                <LatestSourceSummary
                  source={latestStateSource}
                  timeZone={selectedTimeZone}
                />

                <label className="file-picker">
                  <span>Selecionar XLSX de horários</span>
                  <input
                    accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                    disabled={anyBusy}
                    onChange={(event) =>
                      selectFile("state", event.target.files?.[0] ?? null)
                    }
                    type="file"
                  />
                  <small>
                    {stateSlot.file
                      ? `${stateSlot.file.name} · ${formatFileSize(
                          stateSlot.file.size,
                        )}`
                      : "Cabeçalhos esperados: Tempo, Operação e Acionado por."}
                  </small>
                </label>

                <div className="source-status-row">
                  <span
                    className={`source-file-status ${stateFileStatus}`}
                    role="status"
                  >
                    {sourceStatusLabels[stateFileStatus]}
                  </span>
                  {statePreview ? (
                    <span>
                      {formatDateTime(
                        statePreview.periodStart,
                        statePreview.timeZone,
                      )}{" "}
                      —{" "}
                      {formatDateTime(
                        statePreview.periodEnd,
                        statePreview.timeZone,
                      )}
                    </span>
                  ) : null}
                </div>

                {stateSlot.error ? (
                  <p className="form-message error" role="alert">
                    {stateSlot.error}
                  </p>
                ) : null}

                <button
                  className="secondary-button source-validate-button"
                  disabled={
                    !contextComplete ||
                    !stateSlot.controllerId ||
                    !stateSlot.file ||
                    Boolean(validateFileSelection(stateSlot.file)) ||
                    anyBusy
                  }
                  onClick={() => handlePreview("state")}
                  type="button"
                >
                  {stateSlot.validating
                    ? "Validando horários..."
                    : "Validar arquivo de estado"}
                </button>

                {stateSlot.preview ? (
                  <StatePreview preview={stateSlot.preview} />
                ) : null}
              </div>
            </article>

            <article
              className="import-source-card power-source-card"
              aria-labelledby="power-source-title"
            >
              <header className="import-source-header">
                <span className="source-number" aria-hidden="true">
                  02
                </span>
                <div>
                  <p className="source-kicker">Telemetria elétrica</p>
                  <h3 id="power-source-title">Potência consumida</h3>
                  <p>Leituras técnicas de potência em watts.</p>
                </div>
              </header>

              <div className="import-source-body">
                <label className="source-controller-select">
                  Controlador de telemetria
                  <select
                    disabled={anyBusy}
                    onChange={(event) =>
                      updateSourceController("power", event.target.value)
                    }
                    value={powerSlot.controllerId}
                  >
                    <option value="">Selecione</option>
                    {powerControllers.map((controller) => (
                      <option key={controller.id} value={controller.id}>
                        {controllerOptionLabel(controller, selectedTimeZone)}
                      </option>
                    ))}
                  </select>
                </label>

                <LatestSourceSummary
                  source={latestPowerSource}
                  timeZone={selectedTimeZone}
                />
                <label>
                  Fuso horário do arquivo de potência
                  <select value={powerTimezone} disabled={anyBusy} required onChange={(event) => {
                    setPowerTimezone(event.target.value);
                    setPowerSlot(current => invalidateSlot(current));
                    invalidateSession();
                  }}>
                    <option value="">Selecione o fuso do XLSX</option>
                    {POWER_TIMEZONES.map(zone => <option key={zone} value={zone}>{zone}</option>)}
                  </select>
                </label>
                <p className="field-hint">Escolha UTC quando 23:00 no arquivo corresponder a 20:00 em Fortaleza. A prévia preserva o horário original e mostra o horário convertido.</p>
                <p className="field-hint">Ao reimportar com outro fuso, as leituras correspondentes passam a usar o horário corrigido. O registro anterior fica preservado para auditoria.</p>

                <label className="file-picker">
                  <span>Selecionar XLSX de potência</span>
                  <input
                    accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                    disabled={anyBusy}
                    onChange={(event) =>
                      selectFile("power", event.target.files?.[0] ?? null)
                    }
                    type="file"
                  />
                  <small>
                    {powerSlot.file
                      ? `${powerSlot.file.name} · ${formatFileSize(
                          powerSlot.file.size,
                        )}`
                      : "Formato técnico detectado pelos oito cabeçalhos e pelo Device ID."}
                  </small>
                </label>

                <div className="source-status-row">
                  <span
                    className={`source-file-status ${powerFileStatus}`}
                    role="status"
                  >
                    {sourceStatusLabels[powerFileStatus]}
                  </span>
                  {powerPreview ? (
                    <span>
                      {formatDateTime(
                        powerPreview.periodStart,
                        powerPreview.timeZone,
                      )}{" "}
                      —{" "}
                      {formatDateTime(
                        powerPreview.periodEnd,
                        powerPreview.timeZone,
                      )}
                    </span>
                  ) : null}
                </div>

                {powerSlot.error ? (
                  <p className="form-message error" role="alert">
                    {powerSlot.error}
                  </p>
                ) : null}

                <button
                  className="secondary-button source-validate-button"
                  disabled={
                    !contextComplete ||
                    !powerSlot.controllerId ||
                    !powerSlot.file ||
                    Boolean(validateFileSelection(powerSlot.file)) ||
                    anyBusy
                  }
                  onClick={() => handlePreview("power")}
                  type="button"
                >
                  {powerSlot.validating
                    ? "Validando potência..."
                    : "Validar arquivo de potência"}
                </button>

                {powerSlot.preview ? (
                  <PowerPreview preview={powerSlot.preview} />
                ) : null}
              </div>
            </article>
          </div>
        </section>
      ) : null}

      {selection.generatorId ? (
        <section
          className="import-panel session-compatibility-panel"
          aria-labelledby="session-compatibility-title"
        >
          <div className="section-title-row">
            <div>
              <p className="eyebrow">Etapa 3</p>
              <h2 id="session-compatibility-title">
                Compatibilidade da sessão
              </h2>
            </div>
            <span className={`session-status ${aggregateStatus}`} role="status">
              {aggregateStatus === "incomplete" && "Atualização incompleta"}
              {aggregateStatus === "validating" && "Validando fontes"}
              {aggregateStatus === "ready" && (operationalPreview ? "Pronta para confirmar" : "Avaliação pendente")}
              {aggregateStatus === "ready_with_warning" &&
                (operationalPreview ? "Pronta com aviso" : "Avaliação pendente")}
              {aggregateStatus === "confirming" && "Confirmando atualização"}
              {aggregateStatus === "confirmed" && "Atualização confirmada"}
              {aggregateStatus === "failed" && "Confirmação bloqueada"}
            </span>
          </div>

          <div className="session-compatibility-body">
            {statePreview && powerPreview && coverage?.status !== "no_intersection" ? (
              <>
                <button className="secondary-button" type="button" disabled={anyBusy}
                  onClick={() => handleConfirmation(true)}>
                  {projecting ? "Projetando avaliação..." : "Projetar avaliação operacional"}
                </button>
                {!operationalPreview ? <p role="status">Projete a avaliação operacional antes de confirmar.</p> : null}
              </>
            ) : null}
            {operationalPreview ? <ImportOperationalPreview summary={operationalPreview} /> : null}
            {sessionError ? <a href={`/admin/geradores/${selection.generatorId}`}>Consultar configuração nominal do gerador</a> : null}

            {missingMessage ? (
              <p className="session-guidance">{missingMessage}</p>
            ) : null}

            {statePreview && powerPreview ? (
              <dl className="session-period-grid">
                <div>
                  <dt>Período de estado</dt>
                  <dd>
                    {formatDateTime(statePreview.periodStart, selectedTimeZone)} —{" "}
                    {formatDateTime(statePreview.periodEnd, selectedTimeZone)}
                  </dd>
                </div>
                <div>
                  <dt>Período de potência</dt>
                  <dd>
                    {formatDateTime(powerPreview.periodStart, selectedTimeZone)} —{" "}
                    {formatDateTime(powerPreview.periodEnd, selectedTimeZone)}
                  </dd>
                </div>
                <div>
                  <dt>Compatibilidade</dt>
                  <dd>
                    {coverage?.status === "full" && "Cobertura completa"}
                    {coverage?.status === "partial" && "Cobertura parcial"}
                    {coverage?.status === "no_intersection" &&
                      "Sem interseção temporal"}
                  </dd>
                </div>
                <div>
                  <dt>Interseção</dt>
                  <dd>
                    {coverage?.intersectionStart
                      ? `${formatDateTime(
                          coverage.intersectionStart,
                          selectedTimeZone,
                        )} — ${formatDateTime(
                          coverage.intersectionEnd,
                          selectedTimeZone,
                        )}`
                      : "—"}
                  </dd>
                </div>
              </dl>
            ) : null}

            {coverage?.status === "partial" ? (
              <div className="coverage-warning" role="alert">
                <div>
                  <strong>Cobertura parcial de potência</strong>
                  <p>
                    Trecho do período de estado sem cobertura: {" "}
                    {coverageGapText(coverage, selectedTimeZone)}. Este aviso não
                    indica falha do equipamento nem ausência de aplicação.
                  </p>
                </div>
                <label>
                  <input
                    checked={coverageAcknowledged}
                    disabled={confirming}
                    onChange={(event) =>
                      setCoverageAcknowledged(event.target.checked)
                    }
                    type="checkbox"
                  />
                  Estou ciente da cobertura parcial e desejo confirmar.
                </label>
              </div>
            ) : null}

            {coverage?.status === "no_intersection" ? (
              <p className="form-message error" role="alert">
                Os períodos não possuem interseção. Selecione arquivos da mesma
                atualização operacional.
              </p>
            ) : null}

            {sessionError ? (
              <p className="form-message error" role="alert">
                {sessionError}
              </p>
            ) : null}

            {confirmation ? (
              <p className="form-message success" role="status">
                {confirmation.alreadyConfirmed
                  ? "Esta mesma sessão já havia sido confirmada. Nenhum lote, evento ou leitura foi duplicado."
                  : `Atualização confirmada: ${confirmation.stateBatch.insertedRows.toLocaleString(
                      "pt-BR",
                    )} evento(s) de estado e ${confirmation.powerBatch.insertedRows.toLocaleString(
                      "pt-BR",
                    )} leitura(s) de potência inseridos.`}
              </p>
            ) : null}
          </div>

          <div className="import-confirmation-bar">
            <p>
              Na confirmação, os dois arquivos serão enviados, validados e
              processados novamente dentro de uma única transação.
            </p>
            <button
              className="primary-button"
              disabled={confirmationDisabled || anyBusy}
              onClick={() => handleConfirmation()}
              type="button"
            >
              {confirming ? "Confirmando atualização..." : "Confirmar atualização"}
            </button>
          </div>
        </section>
      ) : null}
    </div>
  );
}

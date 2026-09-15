"use server";

import { revalidatePath } from "next/cache";

import { logOperationalFailure } from "@/lib/operations/log-failure";
import { requireMaster } from "@/lib/auth/profile";
import type { Json } from "@/lib/supabase/database.types";
import { createClient } from "@/lib/supabase/server";

import { IMPORT_BUCKET, MAX_IMPORT_FILE_BYTES } from "./constants";
import { validateImportContext } from "./context";
import { ImportValidationError, parseImportWorkbook } from "./parser";
import { isOperationalSummary, NOMINAL_PROFILE_REQUIRED_MESSAGE } from "./operational-summary";
import { compareImportPeriods } from "./session";
import type {
  ImportActionResult,
  ImportOperationalSummary,
  ImportSessionPreviewResult,
  ImportConfirmation,
  ImportConfirmationRequest,
  ImportContext,
  ImportSessionActionResult,
  ImportSessionConfirmation,
  ImportSessionConfirmationRequest,
  ImportUploadRequest,
  ParsedImportEvent,
  ParsedPowerReading,
} from "./types";

const uploadPathPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.xlsx$/i;
const sha256Pattern = /^[0-9a-f]{64}$/;

function errorResult(message: string): { status: "error"; message: string } {
  return { status: "error", message };
}

function isValidRequest(request: ImportUploadRequest, profileId: string) {
  return (
    typeof request === "object" &&
    request !== null &&
    uploadPathPattern.test(request.objectPath) &&
    request.objectPath.startsWith(`${profileId}/`) &&
    typeof request.fileName === "string" &&
    request.fileName.length > 0 &&
    request.fileName.length <= 255 &&
    request.fileName.toLocaleLowerCase("pt-BR").endsWith(".xlsx") &&
    typeof request.context === "object" &&
    request.context !== null &&
    (request.expectedDataKind === undefined ||
      request.expectedDataKind === "state_events" ||
      request.expectedDataKind === "power_readings")
  );
}

function persistedEvent(event: ParsedImportEvent): Json {
  return {
    occurred_at: event.occurred_at,
    occurred_at_raw: event.occurred_at_raw,
    operation: event.operation,
    operation_raw: event.operation_raw,
    source_original: event.source_original,
    source_normalized: event.source_normalized,
    source_classification: event.source_classification,
    fingerprint: event.fingerprint,
  };
}

function persistedPowerReading(reading: ParsedPowerReading): Json {
  return {
    occurred_at: reading.occurred_at,
    occurred_at_raw: reading.occurred_at_raw,
    power_w: reading.power_w,
    power_raw: reading.power_raw,
    device_name: reading.device_name,
    device_id: reading.device_id,
    device_id_normalized: reading.device_id_normalized,
    event_type: reading.event_type,
    event_name: reading.event_name,
    event_detail: reading.event_detail,
    request_from: reading.request_from,
    source_detail: reading.source_detail,
    fingerprint: reading.fingerprint,
  };
}

type StoredImportConfirmation = Json & {
  batch_id: string;
  already_confirmed: boolean;
  total_rows: number;
  inserted_rows: number;
  duplicate_rows: number;
  unknown_source_rows: number;
  period_start: string | null;
  period_end: string | null;
};

function isConfirmation(
  value: Json | undefined,
): value is StoredImportConfirmation {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value) &&
    typeof value.batch_id === "string" &&
    typeof value.already_confirmed === "boolean" &&
    typeof value.total_rows === "number" &&
    typeof value.inserted_rows === "number" &&
    typeof value.duplicate_rows === "number" &&
    typeof value.unknown_source_rows === "number" &&
    (typeof value.period_start === "string" || value.period_start === null) &&
    (typeof value.period_end === "string" || value.period_end === null)
  );
}

function importConfirmation(value: StoredImportConfirmation): ImportConfirmation {
  return {
    batchId: value.batch_id,
    alreadyConfirmed: value.already_confirmed,
    totalRows: value.total_rows,
    insertedRows: value.inserted_rows,
    duplicateRows: value.duplicate_rows,
    unknownSourceRows: value.unknown_source_rows,
    periodStart: value.period_start,
    periodEnd: value.period_end,
  };
}

function isSessionConfirmation(value: Json): value is Json & {
  operational_summary: ImportOperationalSummary;
  session_id: string;
  already_confirmed: boolean;
  coverage_status: "full" | "partial";
  coverage_warning_acknowledged: boolean;
  state_period_start: string;
  state_period_end: string;
  power_period_start: string;
  power_period_end: string;
  intersection_start: string;
  intersection_end: string;
  state_batch: StoredImportConfirmation;
  power_batch: StoredImportConfirmation;
} {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value) &&
    isOperationalSummary(value.operational_summary) &&
    typeof value.session_id === "string" &&
    typeof value.already_confirmed === "boolean" &&
    (value.coverage_status === "full" ||
      value.coverage_status === "partial") &&
    typeof value.coverage_warning_acknowledged === "boolean" &&
    typeof value.state_period_start === "string" &&
    typeof value.state_period_end === "string" &&
    typeof value.power_period_start === "string" &&
    typeof value.power_period_end === "string" &&
    typeof value.intersection_start === "string" &&
    typeof value.intersection_end === "string" &&
    isConfirmation(value.state_batch) &&
    isConfirmation(value.power_batch)
  );
}

function sameHierarchy(left: ImportContext, right: ImportContext) {
  return (
    left.clientId === right.clientId &&
    left.locationId === right.locationId &&
    left.coldRoomId === right.coldRoomId &&
    left.generatorId === right.generatorId
  );
}

async function loadValidatedUpload(
  request: ImportUploadRequest,
  profileId: string,
) {
  if (!isValidRequest(request, profileId)) {
    throw new ImportValidationError("O envio temporário do arquivo é inválido.");
  }

  const supabase = await createClient();

  try {
    const context = await validateImportContext(supabase, request.context);
    const [downloadResponse, mappingsResponse] = await Promise.all([
      supabase.storage.from(IMPORT_BUCKET).download(request.objectPath),
      supabase
        .from("source_mappings")
        .select("normalized_source, classification")
        .eq("is_active", true),
    ]);

    if (downloadResponse.error || !downloadResponse.data) {
      throw new ImportValidationError(
        "O arquivo temporário não foi encontrado. Selecione-o novamente.",
      );
    }

    if (mappingsResponse.error || !mappingsResponse.data) {
      throw new Error("Não foi possível carregar o mapeamento de origens.");
    }

    if (downloadResponse.data.size === 0) {
      throw new ImportValidationError("O arquivo selecionado está vazio.");
    }

    if (downloadResponse.data.size > MAX_IMPORT_FILE_BYTES) {
      throw new ImportValidationError("O arquivo excede o limite de 5 MB.");
    }

    const buffer = Buffer.from(await downloadResponse.data.arrayBuffer());
    const parsed = await parseImportWorkbook(
      buffer,
      context,
      mappingsResponse.data,
      request.expectedDataKind,
    );

    return { supabase, context, parsed };
  } finally {
    await supabase.storage.from(IMPORT_BUCKET).remove([request.objectPath]);
  }
}

export async function previewXlsxImport(
  request: ImportUploadRequest,
): Promise<ImportActionResult> {
  const profile = await requireMaster();

  try {
    const { supabase, context, parsed } = await loadValidatedUpload(
      request,
      profile.id,
    );
    const parsedRows =
      parsed.dataKind === "state_events" ? parsed.events : parsed.readings;
    const uniqueFingerprints = [
      ...new Set(parsedRows.map((row) => row.fingerprint)),
    ];
    const [fingerprintsResponse, existingBatchResponse] = await Promise.all([
      supabase.rpc(
        parsed.dataKind === "state_events"
          ? "existing_event_fingerprints"
          : "existing_power_fingerprints",
        { p_fingerprints: uniqueFingerprints },
      ),
      supabase
        .from("import_batches")
        .select("id")
        .eq("file_sha256", parsed.fileSha256)
        .eq("client_id", request.context.clientId)
        .eq("location_id", request.context.locationId)
        .eq("cold_room_id", request.context.coldRoomId)
        .eq("generator_id", request.context.generatorId)
        .eq("controller_id", request.context.controllerId)
        .eq("data_kind", parsed.dataKind)
        .eq("status", "confirmed")
        .maybeSingle(),
    ]);

    if (fingerprintsResponse.error || !fingerprintsResponse.data) {
      throw new Error("Não foi possível comparar os eventos existentes.");
    }
    if (existingBatchResponse.error) {
      throw new Error("Não foi possível verificar o histórico do arquivo.");
    }

    const existing = new Set(
      fingerprintsResponse.data.map((item) => item.fingerprint),
    );
    const occurrences = new Map<string, number>();
    parsedRows.forEach((row) => {
      occurrences.set(
        row.fingerprint,
        (occurrences.get(row.fingerprint) ?? 0) + 1,
      );
    });
    const repeatedFileRows = [...occurrences.values()].reduce(
      (total, count) => total + Math.max(0, count - 1),
      0,
    );

    const previewBase = {
      fileName: request.fileName,
      fileSha256: parsed.fileSha256,
      sheetName: parsed.sheetName,
      timeZone: context.timeZone,
      totalRows: parsed.totalRows,
      existingDuplicateRows: parsedRows.filter((row) =>
        existing.has(row.fingerprint),
      ).length,
      repeatedFileRows,
      periodStart: parsed.periodStart,
      periodEnd: parsed.periodEnd,
      alreadyImported: existingBatchResponse.data !== null,
      existingBatchId: existingBatchResponse.data?.id ?? null,
    };

    if (parsed.dataKind === "state_events") {
      return {
        status: "preview",
        preview: {
          ...previewBase,
          dataKind: parsed.dataKind,
          unknownSourceRows: parsed.unknownSourceRows,
          sample: parsed.sample.map((event) => ({
            rowNumber: event.rowNumber,
            occurredAt: event.occurred_at,
            occurredAtRaw: event.occurred_at_raw,
            operation: event.operation,
            operationRaw: event.operation_raw,
            sourceOriginal: event.source_original,
            sourceClassification: event.source_classification,
          })),
        },
      };
    }

    return {
      status: "preview",
      preview: {
        ...previewBase,
        dataKind: parsed.dataKind,
        deviceName: parsed.deviceName,
        deviceId: parsed.deviceId,
        minPowerW: parsed.minPowerW,
        maxPowerW: parsed.maxPowerW,
        onRows: parsed.onRows,
        offRows: parsed.offRows,
        hysteresisRows: parsed.hysteresisRows,
        invalidRows: parsed.invalidRows,
        sample: parsed.sample.map((reading) => ({
          rowNumber: reading.rowNumber,
          occurredAt: reading.occurred_at,
          occurredAtRaw: reading.occurred_at_raw,
          powerW: reading.power_w,
          powerRaw: reading.power_raw,
          electricalState: reading.electrical_state,
          deviceName: reading.device_name,
          deviceId: reading.device_id,
        })),
      },
    };
  } catch (error) {
    if (error instanceof ImportValidationError) {
      return errorResult(error.message);
    }

    logOperationalFailure("import_preview", error);
    return errorResult("Não foi possível validar o arquivo. Tente novamente.");
  }
}

export async function confirmXlsxImport(
  request: ImportConfirmationRequest,
): Promise<ImportActionResult> {
  const profile = await requireMaster();

  try {
    if (
      !request ||
      typeof request.expectedFileSha256 !== "string" ||
      !sha256Pattern.test(request.expectedFileSha256)
    ) {
      return errorResult("A prévia expirou. Valide o arquivo novamente.");
    }

    const { supabase, parsed } = await loadValidatedUpload(request, profile.id);

    if (parsed.fileSha256 !== request.expectedFileSha256) {
      return errorResult(
        "O arquivo mudou desde a prévia. Valide a versão atual antes de confirmar.",
      );
    }

    const rpcContext = {
      p_client_id: request.context.clientId,
      p_location_id: request.context.locationId,
      p_cold_room_id: request.context.coldRoomId,
      p_generator_id: request.context.generatorId,
      p_controller_id: request.context.controllerId,
      p_file_name: request.fileName,
      p_file_sha256: parsed.fileSha256,
    };
    const { data, error } =
      parsed.dataKind === "state_events"
        ? await supabase.rpc("confirm_xlsx_import", {
            ...rpcContext,
            p_events: parsed.events.map(persistedEvent),
          })
        : await supabase.rpc("confirm_power_xlsx_import", {
            ...rpcContext,
            p_readings: parsed.readings.map(persistedPowerReading),
          });

    if (error || !data || !isConfirmation(data)) {
      logOperationalFailure("import_confirmation", error);
      const administrativeMessage = "Não foi possível confirmar a importação.";
      const failedResult = await supabase.rpc(
        parsed.dataKind === "state_events"
          ? "record_failed_xlsx_import"
          : "record_failed_power_xlsx_import",
        { ...rpcContext, p_error_message: administrativeMessage },
      );

      if (failedResult.error) {
        logOperationalFailure("import_failure_record", failedResult.error);
      }
      throw new Error(administrativeMessage);
    }

    const confirmation = importConfirmation(data);

    revalidatePath("/admin/importacoes");
    return { status: "confirmed", confirmation };
  } catch (error) {
    if (error instanceof ImportValidationError) {
      return errorResult(error.message);
    }

    logOperationalFailure("import_confirmation", error);
    return errorResult(
      "Não foi possível confirmar a importação. Nenhum lote parcial foi mantido.",
    );
  }
}

async function processImportSession(
  request: ImportSessionConfirmationRequest,
  preview: boolean,
): Promise<ImportSessionActionResult | ImportSessionPreviewResult> {
  const profile = await requireMaster();

  try {
    if (
      !request ||
      !request.context ||
      !request.state ||
      !request.power ||
      !request.state.context ||
      !request.power.context ||
      !sameHierarchy(request.state.context, request.power.context) ||
      request.context.clientId !== request.state.context.clientId ||
      request.context.locationId !== request.state.context.locationId ||
      request.context.coldRoomId !== request.state.context.coldRoomId ||
      request.context.generatorId !== request.state.context.generatorId ||
      !sha256Pattern.test(request.state.expectedFileSha256) ||
      !sha256Pattern.test(request.power.expectedFileSha256)
    ) {
      return errorResult(
        "A sessão não corresponde às duas prévias atuais. Valide os arquivos novamente.",
      );
    }

    const [stateSettled, powerSettled] = await Promise.allSettled([
      loadValidatedUpload(
        { ...request.state, expectedDataKind: "state_events" },
        profile.id,
      ),
      loadValidatedUpload(
        { ...request.power, expectedDataKind: "power_readings" },
        profile.id,
      ),
    ]);

    if (stateSettled.status === "rejected") throw stateSettled.reason;
    if (powerSettled.status === "rejected") throw powerSettled.reason;

    const stateLoaded = stateSettled.value;
    const powerLoaded = powerSettled.value;
    const stateParsed = stateLoaded.parsed;
    const powerParsed = powerLoaded.parsed;

    if (
      stateParsed.dataKind !== "state_events" ||
      powerParsed.dataKind !== "power_readings"
    ) {
      throw new ImportValidationError(
        "Cada arquivo deve permanecer no campo correspondente ao seu formato.",
      );
    }

    if (
      stateParsed.fileSha256 !== request.state.expectedFileSha256 ||
      powerParsed.fileSha256 !== request.power.expectedFileSha256
    ) {
      return errorResult(
        "Um dos arquivos mudou desde a prévia. Valide as versões atuais novamente.",
      );
    }

    const coverage = compareImportPeriods(
      { start: stateParsed.periodStart, end: stateParsed.periodEnd },
      { start: powerParsed.periodStart, end: powerParsed.periodEnd },
    );

    if (coverage.status === "no_intersection") {
      return errorResult(
        "Os arquivos não possuem interseção temporal e não representam a mesma atualização operacional.",
      );
    }

    if (
      !preview && coverage.status === "partial" &&
      !request.coverageWarningAcknowledged
    ) {
      return errorResult(
        "A cobertura de potência é parcial. Confirme sua ciência antes de continuar.",
      );
    }

    const rpcArguments = {
      p_client_id: request.context.clientId,
      p_location_id: request.context.locationId,
      p_cold_room_id: request.context.coldRoomId,
      p_generator_id: request.context.generatorId,
      p_state_controller_id: request.state.context.controllerId,
      p_state_file_name: request.state.fileName,
      p_state_file_sha256: stateParsed.fileSha256,
      p_state_events: stateParsed.events.map(persistedEvent),
      p_power_controller_id: request.power.context.controllerId,
      p_power_file_name: request.power.fileName,
      p_power_file_sha256: powerParsed.fileSha256,
      p_power_readings: powerParsed.readings.map(persistedPowerReading),
    };
    const { data, error } = preview
      ? await stateLoaded.supabase.rpc("preview_import_session", rpcArguments)
      : await stateLoaded.supabase.rpc("confirm_import_session", {
          ...rpcArguments,
          p_coverage_warning_acknowledged: request.coverageWarningAcknowledged,
        });

    if (error) logOperationalFailure("session_processing", error);
    if (error?.code === "P1206") {
      return errorResult(NOMINAL_PROFILE_REQUIRED_MESSAGE);
    }
    if (preview) {
      if (error || !isOperationalSummary(data)) {
        return errorResult("Não foi possível projetar a avaliação. Valide os arquivos novamente.");
      }
      return { status: "preview", preview: data };
    }

    if (error || !data || !isSessionConfirmation(data)) {
      const administrativeMessage = "Não foi possível confirmar a sessão de importação.";
      const failedResult = await stateLoaded.supabase.rpc(
        "record_failed_import_session",
        {
          p_client_id: request.context.clientId,
          p_location_id: request.context.locationId,
          p_cold_room_id: request.context.coldRoomId,
          p_generator_id: request.context.generatorId,
          p_state_controller_id: request.state.context.controllerId,
          p_state_file_name: request.state.fileName,
          p_state_file_sha256: stateParsed.fileSha256,
          p_state_period_start: stateParsed.periodStart,
          p_state_period_end: stateParsed.periodEnd,
          p_power_controller_id: request.power.context.controllerId,
          p_power_file_name: request.power.fileName,
          p_power_file_sha256: powerParsed.fileSha256,
          p_power_period_start: powerParsed.periodStart,
          p_power_period_end: powerParsed.periodEnd,
          p_error_message: administrativeMessage,
        },
      );

      if (failedResult.error) {
        logOperationalFailure(
          "session_failure_record",
          failedResult.error,
        );
      }
      throw new Error(administrativeMessage);
    }

    const confirmation: ImportSessionConfirmation = {
      operationalSummary: data.operational_summary,
      sessionId: data.session_id,
      alreadyConfirmed: data.already_confirmed,
      coverageStatus: data.coverage_status,
      coverageWarningAcknowledged: data.coverage_warning_acknowledged,
      statePeriodStart: data.state_period_start,
      statePeriodEnd: data.state_period_end,
      powerPeriodStart: data.power_period_start,
      powerPeriodEnd: data.power_period_end,
      intersectionStart: data.intersection_start,
      intersectionEnd: data.intersection_end,
      stateBatch: importConfirmation(data.state_batch),
      powerBatch: importConfirmation(data.power_batch),
    };

    revalidatePath("/admin/importacoes");
    return { status: "confirmed", confirmation };
  } catch (error) {
    if (error instanceof ImportValidationError) {
      return errorResult(error.message);
    }

    logOperationalFailure("session_processing", error);
    return errorResult(
      "Não foi possível confirmar a atualização. Nenhum lote parcial foi mantido.",
    );
  }
}

export async function previewImportSession(request: ImportSessionConfirmationRequest): Promise<ImportSessionPreviewResult> {
  const result = await processImportSession(request, true);
  return result.status === "confirmed" ? errorResult("Resposta inesperada da prévia.") : result;
}

export async function confirmImportSession(request: ImportSessionConfirmationRequest): Promise<ImportSessionActionResult> {
  const result = await processImportSession(request, false);
  return result.status === "preview" ? errorResult("Resposta inesperada da confirmação.") : result;
}

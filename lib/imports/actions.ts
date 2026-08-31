"use server";

import { revalidatePath } from "next/cache";

import { requireMaster } from "@/lib/auth/profile";
import type { Json } from "@/lib/supabase/database.types";
import { createClient } from "@/lib/supabase/server";

import { IMPORT_BUCKET, MAX_IMPORT_FILE_BYTES } from "./constants";
import { validateImportContext } from "./context";
import { ImportValidationError, parseImportWorkbook } from "./parser";
import type {
  ImportActionResult,
  ImportConfirmation,
  ImportConfirmationRequest,
  ImportUploadRequest,
  ParsedImportEvent,
  ParsedPowerReading,
} from "./types";

const uploadPathPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.xlsx$/i;
const sha256Pattern = /^[0-9a-f]{64}$/;

function errorResult(message: string): ImportActionResult {
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
    request.context !== null
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

function isConfirmation(value: Json): value is Json & {
  batch_id: string;
  already_confirmed: boolean;
  total_rows: number;
  inserted_rows: number;
  duplicate_rows: number;
  unknown_source_rows: number;
  period_start: string | null;
  period_end: string | null;
} {
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
    const { data, error } = await supabase.rpc(
      parsed.dataKind === "state_events"
        ? "existing_event_fingerprints"
        : "existing_power_fingerprints",
      { p_fingerprints: uniqueFingerprints },
    );

    if (error || !data) {
      throw new Error("Não foi possível comparar os eventos existentes.");
    }

    const existing = new Set(data.map((item) => item.fingerprint));
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

    console.error("Falha ao gerar prévia XLSX", error);
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
      const administrativeMessage =
        error?.message ?? "Resposta inválida ao confirmar a importação.";
      const failedResult = await supabase.rpc(
        parsed.dataKind === "state_events"
          ? "record_failed_xlsx_import"
          : "record_failed_power_xlsx_import",
        { ...rpcContext, p_error_message: administrativeMessage },
      );

      if (failedResult.error) {
        console.error("Falha ao registrar importação malsucedida", failedResult.error);
      }
      throw new Error(administrativeMessage);
    }

    const confirmation: ImportConfirmation = {
      batchId: data.batch_id,
      alreadyConfirmed: data.already_confirmed,
      totalRows: data.total_rows,
      insertedRows: data.inserted_rows,
      duplicateRows: data.duplicate_rows,
      unknownSourceRows: data.unknown_source_rows,
      periodStart: data.period_start,
      periodEnd: data.period_end,
    };

    revalidatePath("/admin/importacoes");
    return { status: "confirmed", confirmation };
  } catch (error) {
    if (error instanceof ImportValidationError) {
      return errorResult(error.message);
    }

    console.error("Falha ao confirmar importação XLSX", error);
    return errorResult(
      "Não foi possível confirmar a importação. Nenhum lote parcial foi mantido.",
    );
  }
}

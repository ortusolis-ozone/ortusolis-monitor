import "server-only";

import { createHash } from "node:crypto";

import readXlsxFile, { type CellValue } from "read-excel-file/node";

import { IMPORT_PREVIEW_ROWS, MAX_IMPORT_ROWS } from "./constants";
import { isPowerTimezone, TIME_NORMALIZATION_VERSION } from "./timezone";
import type {
  ImportDataKind,
  ParsedImportEvent,
  ParsedPowerReading,
  ValidatedImportContext,
} from "./types";

type DateParts = {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
  millisecond: number;
};

type SourceMapping = {
  normalized_source: string;
  classification: string;
};

const stateHeaders = ["tempo", "operacao", "acionado por"] as const;
const powerHeaders = [
  "device name",
  "device id",
  "event type",
  "event name",
  "event detail",
  "request from",
  "source detail",
  "event time",
] as const;

export class ImportValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ImportValidationError";
  }
}

export function normalizeSource(value: string) {
  return value.trim().replace(/\s+/g, " ").toLocaleLowerCase("pt-BR");
}

function normalizeHeader(value: string) {
  return normalizeSource(value)
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function isNonEmptyCell(value: CellValue | null) {
  return value !== null && (typeof value !== "string" || value.trim() !== "");
}

function rawCellValue(value: CellValue | null) {
  if (value === null) return "";

  if (value instanceof Date) {
    const pad = (part: number, size = 2) => String(part).padStart(size, "0");
    const base = `${value.getUTCFullYear()}-${pad(value.getUTCMonth() + 1)}-${pad(value.getUTCDate())} ${pad(value.getUTCHours())}:${pad(value.getUTCMinutes())}:${pad(value.getUTCSeconds())}`;
    return value.getUTCMilliseconds() > 0
      ? `${base}:${pad(value.getUTCMilliseconds(), 3)}`
      : base;
  }

  return String(value);
}

function validCalendarParts(parts: DateParts) {
  const date = new Date(
    Date.UTC(
      parts.year,
      parts.month - 1,
      parts.day,
      parts.hour,
      parts.minute,
      parts.second,
      parts.millisecond,
    ),
  );

  return (
    parts.year >= 1900 &&
    parts.millisecond >= 0 &&
    parts.millisecond <= 999 &&
    date.getUTCFullYear() === parts.year &&
    date.getUTCMonth() === parts.month - 1 &&
    date.getUTCDate() === parts.day &&
    date.getUTCHours() === parts.hour &&
    date.getUTCMinutes() === parts.minute &&
    date.getUTCSeconds() === parts.second &&
    date.getUTCMilliseconds() === parts.millisecond
  );
}

function datePartsFromCell(value: CellValue | null): DateParts | null {
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return {
      year: value.getUTCFullYear(),
      month: value.getUTCMonth() + 1,
      day: value.getUTCDate(),
      hour: value.getUTCHours(),
      minute: value.getUTCMinutes(),
      second: value.getUTCSeconds(),
      millisecond: value.getUTCMilliseconds(),
    };
  }

  if (typeof value !== "string") return null;

  const normalized = value.trim();
  const yearFirst = normalized.match(
    /^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?:[ T]+(\d{1,2}):(\d{2})(?::(\d{2})(?:[.:](\d{1,3}))?)?)?$/,
  );
  const dayFirst = normalized.match(
    /^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})(?:[ T]+(\d{1,2}):(\d{2})(?::(\d{2})(?:[.:](\d{1,3}))?)?)?$/,
  );
  const match = yearFirst ?? dayFirst;

  if (!match) return null;

  const millisecond = Number((match[7] ?? "0").padEnd(3, "0"));
  const parts = yearFirst
    ? {
        year: Number(match[1]),
        month: Number(match[2]),
        day: Number(match[3]),
        hour: Number(match[4] ?? 0),
        minute: Number(match[5] ?? 0),
        second: Number(match[6] ?? 0),
        millisecond,
      }
    : {
        year: Number(match[3]),
        month: Number(match[2]),
        day: Number(match[1]),
        hour: Number(match[4] ?? 0),
        minute: Number(match[5] ?? 0),
        second: Number(match[6] ?? 0),
        millisecond,
      };

  return validCalendarParts(parts) ? parts : null;
}

function partsAtInstant(timestamp: number, timeZone: string): DateParts {
  const date = new Date(timestamp);
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  });
  const values = Object.fromEntries(
    formatter
      .formatToParts(date)
      .filter((part) => part.type !== "literal")
      .map((part) => [part.type, Number(part.value)]),
  );

  return {
    year: values.year,
    month: values.month,
    day: values.day,
    hour: values.hour,
    minute: values.minute,
    second: values.second,
    millisecond: date.getUTCMilliseconds(),
  };
}

function sameDateParts(left: DateParts, right: DateParts) {
  return (
    left.year === right.year &&
    left.month === right.month &&
    left.day === right.day &&
    left.hour === right.hour &&
    left.minute === right.minute &&
    left.second === right.second &&
    left.millisecond === right.millisecond
  );
}

function zonedDateTimeToIso(parts: DateParts, timeZone: string) {
  const wallTimestamp = Date.UTC(
    parts.year,
    parts.month - 1,
    parts.day,
    parts.hour,
    parts.minute,
    parts.second,
    parts.millisecond,
  );
  let candidate = wallTimestamp;

  for (let iteration = 0; iteration < 3; iteration += 1) {
    const represented = partsAtInstant(candidate, timeZone);
    const representedAsUtc = Date.UTC(
      represented.year,
      represented.month - 1,
      represented.day,
      represented.hour,
      represented.minute,
      represented.second,
      represented.millisecond,
    );
    candidate += wallTimestamp - representedAsUtc;
  }

  // Reject ambiguous wall clocks instead of silently choosing a DST occurrence.
  const ambiguous = [-3600000, 3600000].some(offset =>
    sameDateParts(partsAtInstant(candidate + offset, timeZone), parts));
  return !ambiguous && sameDateParts(partsAtInstant(candidate, timeZone), parts)
    ? new Date(candidate).toISOString()
    : null;
}

function parseOperation(value: CellValue | null) {
  const raw = rawCellValue(value);
  const normalized = normalizeHeader(raw);

  if (normalized === "ligar") return { normalized: "turn_on" as const, raw };
  if (normalized === "desligar") {
    return { normalized: "turn_off" as const, raw };
  }
  return null;
}

function parsePower(value: CellValue | null) {
  const raw = rawCellValue(value);
  const match = raw.match(/^\s*([+]?(?:\d+(?:[.,]\d+)?|[.,]\d+))\s*W\s*$/i);

  if (!match || (match[1].includes(".") && match[1].includes(","))) return null;

  const power = Number(match[1].replace(",", "."));
  return Number.isFinite(power) && power >= 0 ? { raw, power } : null;
}

export function parsePowerText(value: string) {
  return parsePower(value);
}

export function parseLocalDateTimeText(value: string, timeZone: string) {
  const parts = datePartsFromCell(value);
  return parts ? zonedDateTimeToIso(parts, timeZone) : null;
}

function fingerprint(parts: Array<string | number>) {
  return createHash("sha256").update(parts.join("\u001f")).digest("hex");
}

function fingerprintForEvent(
  context: ValidatedImportContext,
  event: Omit<ParsedImportEvent, "rowNumber" | "fingerprint">,
) {
  return fingerprint([
    context.controllerId,
    context.generatorId,
    event.occurred_at,
    event.operation,
    event.source_normalized,
  ]);
}

function fingerprintForPower(
  context: ValidatedImportContext,
  reading: Omit<
    ParsedPowerReading,
    "rowNumber" | "fingerprint" | "electrical_state"
  >,
) {
  return fingerprint([
    context.controllerId,
    context.generatorId,
    reading.occurred_at,
    reading.source_timezone,
    String(reading.normalization_version),
    reading.power_w.toFixed(3),
    reading.device_id_normalized,
    normalizeHeader(reading.event_type),
    normalizeHeader(reading.event_name),
  ]);
}

function validationMessage(errors: string[]) {
  const visible = errors.slice(0, 6);
  const remaining = errors.length - visible.length;
  return `${visible.join(" ")}${remaining > 0 ? ` Há mais ${remaining} erro(s).` : ""}`;
}

function headerMap(header: Array<CellValue | null>) {
  const indexes = new Map<string, number>();
  const duplicated = new Set<string>();

  header.forEach((cell, index) => {
    const normalized = normalizeHeader(rawCellValue(cell));
    if (!normalized) return;
    if (indexes.has(normalized)) duplicated.add(normalized);
    else indexes.set(normalized, index);
  });

  return { indexes, duplicated };
}

function includesHeaders(indexes: Map<string, number>, required: readonly string[]) {
  return required.every((requiredHeader) => indexes.has(requiredHeader));
}

function validateControllerRole(
  context: ValidatedImportContext,
  dataKind: ImportDataKind,
) {
  const compatible =
    (dataKind === "state_events" && context.controllerRole === "state") ||
    (dataKind === "power_readings" &&
      context.controllerRole === "power_telemetry");

  if (!compatible) {
    throw new ImportValidationError(
      dataKind === "power_readings"
        ? "O arquivo de potência exige um controlador de Telemetria de potência."
        : "O arquivo de liga/desliga exige um controlador de Estado liga/desliga.",
    );
  }
}

export function validateExpectedDataKind(
  actual: ImportDataKind,
  expected?: ImportDataKind,
) {
  if (!expected || actual === expected) return;

  throw new ImportValidationError(
    actual === "power_readings"
      ? "Este é um arquivo de potência. Selecione-o no campo Potência consumida."
      : "Este é um arquivo de liga/desliga. Selecione-o no campo Horários programados — Liga/desliga.",
  );
}

function periodFor(values: Array<{ occurred_at: string }>) {
  let periodStart = values[0].occurred_at;
  let periodEnd = periodStart;

  for (const value of values) {
    if (value.occurred_at < periodStart) periodStart = value.occurred_at;
    if (value.occurred_at > periodEnd) periodEnd = value.occurred_at;
  }

  return { periodStart, periodEnd };
}

export async function parseImportWorkbook(
  buffer: Buffer,
  context: ValidatedImportContext,
  sourceMappings: SourceMapping[],
  expectedDataKind?: ImportDataKind,
  sourceTimezone?: string,
) {
  let sheets;

  try {
    sheets = await readXlsxFile(buffer, { trim: false });
  } catch {
    throw new ImportValidationError(
      "Não foi possível ler o arquivo. Confirme que ele é um XLSX válido.",
    );
  }

  const candidates = sheets.flatMap((sheet) => {
    const headerIndex = sheet.data.findIndex((row) => row.some(isNonEmptyCell));
    if (headerIndex < 0) return [];

    const { indexes, duplicated } = headerMap(sheet.data[headerIndex]);
    const dataKind = includesHeaders(indexes, powerHeaders)
      ? ("power_readings" as const)
      : includesHeaders(indexes, stateHeaders)
        ? ("state_events" as const)
        : null;

    return dataKind
      ? [{ sheet, headerIndex, indexes, duplicated, dataKind }]
      : [];
  });
  const selected = candidates[0];

  if (!selected) {
    throw new ImportValidationError(
      "Formato não reconhecido. Use um XLSX de liga/desliga ou de telemetria de potência.",
    );
  }

  validateExpectedDataKind(selected.dataKind, expectedDataKind);
  validateControllerRole(context, selected.dataKind);
  const requiredHeaders =
    selected.dataKind === "power_readings" ? powerHeaders : stateHeaders;
  const duplicatedRequired = requiredHeaders.filter((header) =>
    selected.duplicated.has(header),
  );
  if (duplicatedRequired.length > 0) {
    throw new ImportValidationError(
      `Há cabeçalhos obrigatórios repetidos: ${duplicatedRequired.join(", ")}.`,
    );
  }

  const dataRows = selected.sheet.data
    .slice(selected.headerIndex + 1)
    .map((row, index) => ({
      row,
      rowNumber: selected.headerIndex + index + 2,
    }))
    .filter(({ row }) => row.some(isNonEmptyCell));

  if (dataRows.length === 0) {
    throw new ImportValidationError(
      selected.dataKind === "power_readings"
        ? "O arquivo não contém leituras de potência."
        : "O arquivo não contém linhas de eventos.",
    );
  }

  if (dataRows.length > MAX_IMPORT_ROWS) {
    throw new ImportValidationError(
      `O arquivo excede o limite de ${MAX_IMPORT_ROWS.toLocaleString("pt-BR")} linhas.`,
    );
  }

  const activatedAt = Date.parse(context.controllerActivatedAt);
  const deactivatedAt = context.controllerDeactivatedAt
    ? Date.parse(context.controllerDeactivatedAt)
    : null;
  const errors: string[] = [];

  if (selected.dataKind === "state_events") {
    const classifications = new Map<string, "programmed" | "test">(
      sourceMappings.map((mapping) => [
        normalizeSource(mapping.normalized_source),
        mapping.classification === "programmed" ? "programmed" : "test",
      ]),
    );
    const timeIndex = selected.indexes.get("tempo")!;
    const operationIndex = selected.indexes.get("operacao")!;
    const sourceIndex = selected.indexes.get("acionado por")!;
    const events: ParsedImportEvent[] = [];

    for (const { row, rowNumber } of dataRows) {
      const occurredAtRaw = rawCellValue(row[timeIndex] ?? null);
      const dateParts = datePartsFromCell(row[timeIndex] ?? null);
      const occurredAt = dateParts
        ? zonedDateTimeToIso(dateParts, context.timeZone)
        : null;
      const operation = parseOperation(row[operationIndex] ?? null);
      const sourceOriginal = rawCellValue(row[sourceIndex] ?? null);
      const sourceNormalized = normalizeSource(sourceOriginal);

      if (!occurredAt) errors.push(`Linha ${rowNumber}: data inválida em Tempo.`);
      if (!operation) {
        errors.push(`Linha ${rowNumber}: Operação deve ser Ligar ou Desligar.`);
      }
      if (!occurredAt || !operation) continue;

      const occurredAtTimestamp = Date.parse(occurredAt);
      if (
        occurredAtTimestamp < activatedAt ||
        (deactivatedAt !== null && occurredAtTimestamp >= deactivatedAt)
      ) {
        errors.push(
          `Linha ${rowNumber}: evento fora da vigência do controlador selecionado.`,
        );
        continue;
      }

      const sourceClassification: ParsedImportEvent["source_classification"] =
        classifications.get(sourceNormalized) ?? "unknown";
      const eventWithoutFingerprint = {
        occurred_at: occurredAt,
        occurred_at_raw: occurredAtRaw,
        operation: operation.normalized,
        operation_raw: operation.raw,
        source_original: sourceOriginal,
        source_normalized: sourceNormalized,
        source_classification: sourceClassification,
      };

      events.push({
        rowNumber,
        ...eventWithoutFingerprint,
        fingerprint: fingerprintForEvent(context, eventWithoutFingerprint),
      });
    }

    if (errors.length > 0) {
      throw new ImportValidationError(validationMessage(errors));
    }

    return {
      dataKind: "state_events" as const,
      fileSha256: createHash("sha256").update(buffer).digest("hex"),
      sheetName: selected.sheet.sheet,
      events,
      totalRows: events.length,
      unknownSourceRows: events.filter(
        (event) => event.source_classification === "unknown",
      ).length,
      ...periodFor(events),
      sample: events.slice(0, IMPORT_PREVIEW_ROWS),
    };
  }

  const indexes = selected.indexes;
  if (!isPowerTimezone(sourceTimezone)) {
    throw new ImportValidationError("Selecione o fuso horário do arquivo de potência: UTC ou America/Fortaleza.");
  }
  const eventTimeIndex = indexes.get("event time")!;
  const deviceNameIndex = indexes.get("device name")!;
  const deviceIdIndex = indexes.get("device id")!;
  const eventTypeIndex = indexes.get("event type")!;
  const eventNameIndex = indexes.get("event name")!;
  const eventDetailIndex = indexes.get("event detail")!;
  const requestFromIndex = indexes.get("request from")!;
  const sourceDetailIndex = indexes.get("source detail")!;
  const expectedDeviceId = context.externalDeviceIdNormalized;
  const onThreshold = context.powerOnThresholdW;
  const offThreshold = context.powerOffThresholdW;

  if (!expectedDeviceId || onThreshold === null || offThreshold === null) {
    throw new ImportValidationError(
      "O controlador de potência selecionado não possui configuração completa.",
    );
  }

  const readings: ParsedPowerReading[] = [];
  const deviceIds = new Set<string>();

  for (const { row, rowNumber } of dataRows) {
    const occurredAtRaw = rawCellValue(row[eventTimeIndex] ?? null);
    const dateParts = datePartsFromCell(row[eventTimeIndex] ?? null);
    const occurredAt = dateParts
      ? zonedDateTimeToIso(dateParts, sourceTimezone)
      : null;
    const deviceName = rawCellValue(row[deviceNameIndex] ?? null).trim();
    const deviceId = rawCellValue(row[deviceIdIndex] ?? null).trim();
    const deviceIdNormalized = normalizeSource(deviceId);
    const eventType = rawCellValue(row[eventTypeIndex] ?? null).trim();
    const eventName = rawCellValue(row[eventNameIndex] ?? null).trim();
    const eventDetail = rawCellValue(row[eventDetailIndex] ?? null).trim();
    const requestFrom = rawCellValue(row[requestFromIndex] ?? null);
    const sourceDetail = rawCellValue(row[sourceDetailIndex] ?? null);
    const parsedPower = parsePower(row[eventDetailIndex] ?? null);

    if (!occurredAt) {
      errors.push(`Linha ${rowNumber}: data inválida em Event Time.`);
    }
    if (!deviceName || !deviceId) {
      errors.push(`Linha ${rowNumber}: Device Name e Device ID são obrigatórios.`);
    }
    if (normalizeHeader(eventType) !== "report") {
      errors.push(`Linha ${rowNumber}: Event Type deve ser Report.`);
    }
    if (normalizeHeader(eventName) !== "power") {
      errors.push(`Linha ${rowNumber}: Event Name deve ser Power.`);
    }
    if (!parsedPower) {
      errors.push(
        `Linha ${rowNumber}: Event Detail deve conter potência não negativa em W.`,
      );
    }

    if (!occurredAt || !deviceName || !deviceId || !parsedPower) continue;

    deviceIds.add(deviceIdNormalized);
    if (deviceIdNormalized !== expectedDeviceId) {
      errors.push(
        `Linha ${rowNumber}: Device ID não corresponde ao controlador selecionado.`,
      );
      continue;
    }

    const occurredAtTimestamp = Date.parse(occurredAt);
    if (
      occurredAtTimestamp < activatedAt ||
      (deactivatedAt !== null && occurredAtTimestamp >= deactivatedAt)
    ) {
      errors.push(
        `Linha ${rowNumber}: leitura fora da vigência do controlador selecionado.`,
      );
      continue;
    }

    const electricalState =
      parsedPower.power >= onThreshold
        ? ("on" as const)
        : parsedPower.power <= offThreshold
          ? ("off" as const)
          : ("hysteresis" as const);
    const readingWithoutFingerprint = {
      source_timezone: sourceTimezone,
      normalization_version: TIME_NORMALIZATION_VERSION,
      occurred_at: occurredAt,
      occurred_at_raw: occurredAtRaw,
      power_w: parsedPower.power,
      power_raw: parsedPower.raw,
      device_name: deviceName,
      device_id: deviceId,
      device_id_normalized: deviceIdNormalized,
      event_type: eventType,
      event_name: eventName,
      event_detail: eventDetail,
      request_from: requestFrom,
      source_detail: sourceDetail,
    };

    readings.push({
      rowNumber,
      ...readingWithoutFingerprint,
      fingerprint: fingerprintForPower(context, readingWithoutFingerprint),
      electrical_state: electricalState,
    });
  }

  if (deviceIds.size > 1) errors.push("O arquivo contém mais de um Device ID.");
  if (errors.length > 0) {
    throw new ImportValidationError(validationMessage(errors));
  }

  return {
    dataKind: "power_readings" as const,
    sourceTimezone,
    rawPeriodStart: readings.reduce((a, b) => a.occurred_at < b.occurred_at ? a : b).occurred_at_raw,
    rawPeriodEnd: readings.reduce((a, b) => a.occurred_at > b.occurred_at ? a : b).occurred_at_raw,
    fileSha256: createHash("sha256").update(buffer).digest("hex"),
    sheetName: selected.sheet.sheet,
    readings,
    totalRows: readings.length,
    invalidRows: 0,
    deviceName: readings[0].device_name,
    deviceId: readings[0].device_id,
    minPowerW: Math.min(...readings.map((reading) => reading.power_w)),
    maxPowerW: Math.max(...readings.map((reading) => reading.power_w)),
    onRows: readings.filter((reading) => reading.electrical_state === "on").length,
    offRows: readings.filter((reading) => reading.electrical_state === "off").length,
    hysteresisRows: readings.filter(
      (reading) => reading.electrical_state === "hysteresis",
    ).length,
    ...periodFor(readings),
    sample: readings.slice(0, IMPORT_PREVIEW_ROWS),
  };
}

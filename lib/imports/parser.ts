import "server-only";

import { createHash } from "node:crypto";

import readXlsxFile, { type CellValue } from "read-excel-file/node";

import { IMPORT_PREVIEW_ROWS, MAX_IMPORT_ROWS } from "./constants";
import type {
  ParsedImportEvent,
  ValidatedImportContext,
} from "./types";

type DateParts = {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
};

type SourceMapping = {
  normalized_source: string;
  classification: string;
};

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

function normalizeOperation(value: string) {
  return normalizeHeader(value);
}

function isNonEmptyCell(value: CellValue | null) {
  return value !== null && (typeof value !== "string" || value.trim() !== "");
}

function rawCellValue(value: CellValue | null) {
  if (value === null) {
    return "";
  }

  if (value instanceof Date) {
    const pad = (part: number) => String(part).padStart(2, "0");
    return `${value.getUTCFullYear()}-${pad(value.getUTCMonth() + 1)}-${pad(value.getUTCDate())} ${pad(value.getUTCHours())}:${pad(value.getUTCMinutes())}:${pad(value.getUTCSeconds())}`;
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
    ),
  );

  return (
    parts.year >= 1900 &&
    date.getUTCFullYear() === parts.year &&
    date.getUTCMonth() === parts.month - 1 &&
    date.getUTCDate() === parts.day &&
    date.getUTCHours() === parts.hour &&
    date.getUTCMinutes() === parts.minute &&
    date.getUTCSeconds() === parts.second
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
    };
  }

  if (typeof value !== "string") {
    return null;
  }

  const normalized = value.trim();
  const yearFirst = normalized.match(
    /^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?:[ T]+(\d{1,2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?)?$/,
  );
  const dayFirst = normalized.match(
    /^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})(?:[ T]+(\d{1,2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?)?$/,
  );
  const match = yearFirst ?? dayFirst;

  if (!match) {
    return null;
  }

  const parts = yearFirst
    ? {
        year: Number(match[1]),
        month: Number(match[2]),
        day: Number(match[3]),
        hour: Number(match[4] ?? 0),
        minute: Number(match[5] ?? 0),
        second: Number(match[6] ?? 0),
      }
    : {
        year: Number(match[3]),
        month: Number(match[2]),
        day: Number(match[1]),
        hour: Number(match[4] ?? 0),
        minute: Number(match[5] ?? 0),
        second: Number(match[6] ?? 0),
      };

  return validCalendarParts(parts) ? parts : null;
}

function partsAtInstant(timestamp: number, timeZone: string): DateParts {
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
      .formatToParts(new Date(timestamp))
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
  };
}

function sameDateParts(left: DateParts, right: DateParts) {
  return (
    left.year === right.year &&
    left.month === right.month &&
    left.day === right.day &&
    left.hour === right.hour &&
    left.minute === right.minute &&
    left.second === right.second
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
    );
    candidate += wallTimestamp - representedAsUtc;
  }

  return sameDateParts(partsAtInstant(candidate, timeZone), parts)
    ? new Date(candidate).toISOString()
    : null;
}

function parseOperation(value: CellValue | null) {
  const raw = rawCellValue(value);
  const normalized = normalizeOperation(raw);

  if (normalized === "ligar") {
    return { normalized: "turn_on" as const, raw };
  }

  if (normalized === "desligar") {
    return { normalized: "turn_off" as const, raw };
  }

  return null;
}

function fingerprintForEvent(
  context: ValidatedImportContext,
  event: Omit<ParsedImportEvent, "rowNumber" | "fingerprint">,
) {
  return createHash("sha256")
    .update(
      [
        context.controllerId,
        context.generatorId,
        event.occurred_at,
        event.operation,
        event.source_normalized,
      ].join("\u001f"),
    )
    .digest("hex");
}

function validationMessage(errors: string[]) {
  const visible = errors.slice(0, 6);
  const remaining = errors.length - visible.length;
  return `${visible.join(" ")}${remaining > 0 ? ` Há mais ${remaining} erro(s).` : ""}`;
}

export async function parseImportWorkbook(
  buffer: Buffer,
  context: ValidatedImportContext,
  sourceMappings: SourceMapping[],
) {
  let sheets;

  try {
    sheets = await readXlsxFile(buffer, { trim: false });
  } catch {
    throw new ImportValidationError(
      "Não foi possível ler o arquivo. Confirme que ele é um XLSX válido.",
    );
  }

  const selectedSheet = sheets.find((sheet) =>
    sheet.data.some((row) => row.some(isNonEmptyCell)),
  );

  if (!selectedSheet) {
    throw new ImportValidationError("O arquivo não contém nenhuma aba preenchida.");
  }

  const headerIndex = selectedSheet.data.findIndex((row) =>
    row.some(isNonEmptyCell),
  );
  const header = selectedSheet.data[headerIndex];
  const requiredHeaders = ["tempo", "operacao", "acionado por"] as const;
  const headerIndexes = new Map<string, number>();
  const duplicatedHeaders = new Set<string>();

  header.forEach((cell, index) => {
    const normalized = normalizeHeader(rawCellValue(cell));
    if (requiredHeaders.includes(normalized as (typeof requiredHeaders)[number])) {
      if (headerIndexes.has(normalized)) {
        duplicatedHeaders.add(normalized);
      } else {
        headerIndexes.set(normalized, index);
      }
    }
  });

  const missingHeaders = requiredHeaders.filter(
    (required) => !headerIndexes.has(required),
  );
  if (missingHeaders.length > 0) {
    throw new ImportValidationError(
      `Cabeçalho obrigatório ausente: ${missingHeaders.join(", ")}.`,
    );
  }

  if (duplicatedHeaders.size > 0) {
    throw new ImportValidationError(
      `Há cabeçalhos obrigatórios repetidos: ${[...duplicatedHeaders].join(", ")}.`,
    );
  }

  const dataRows = selectedSheet.data
    .slice(headerIndex + 1)
    .map((row, index) => ({ row, rowNumber: headerIndex + index + 2 }))
    .filter(({ row }) => row.some(isNonEmptyCell));

  if (dataRows.length === 0) {
    throw new ImportValidationError("O arquivo não contém linhas de eventos.");
  }

  if (dataRows.length > MAX_IMPORT_ROWS) {
    throw new ImportValidationError(
      `O arquivo excede o limite de ${MAX_IMPORT_ROWS.toLocaleString("pt-BR")} linhas.`,
    );
  }

  const classifications = new Map<string, "programmed" | "test">(
    sourceMappings.map((mapping) => [
      normalizeSource(mapping.normalized_source),
      mapping.classification === "programmed" ? "programmed" : "test",
    ]),
  );
  const timeIndex = headerIndexes.get("tempo")!;
  const operationIndex = headerIndexes.get("operacao")!;
  const sourceIndex = headerIndexes.get("acionado por")!;
  const activatedAt = Date.parse(context.controllerActivatedAt);
  const deactivatedAt = context.controllerDeactivatedAt
    ? Date.parse(context.controllerDeactivatedAt)
    : null;
  const errors: string[] = [];
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

    if (!occurredAt) {
      errors.push(`Linha ${rowNumber}: data inválida em Tempo.`);
    }

    if (!operation) {
      errors.push(`Linha ${rowNumber}: Operação deve ser Ligar ou Desligar.`);
    }

    if (!occurredAt || !operation) {
      continue;
    }

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

  let periodStart = events[0].occurred_at;
  let periodEnd = periodStart;

  for (const event of events) {
    if (event.occurred_at < periodStart) periodStart = event.occurred_at;
    if (event.occurred_at > periodEnd) periodEnd = event.occurred_at;
  }

  return {
    fileSha256: createHash("sha256").update(buffer).digest("hex"),
    sheetName: selectedSheet.sheet,
    events,
    totalRows: events.length,
    unknownSourceRows: events.filter(
      (event) => event.source_classification === "unknown",
    ).length,
    periodStart,
    periodEnd,
    sample: events.slice(0, IMPORT_PREVIEW_ROWS),
  };
}

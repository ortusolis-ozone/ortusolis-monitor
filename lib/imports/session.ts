import type {
  ImportSessionUiStatus,
  ImportSourceStatus,
} from "./types";

export type ImportCoverage =
  | {
      status: "no_intersection";
      intersectionStart: null;
      intersectionEnd: null;
      uncoveredBefore: null;
      uncoveredAfter: null;
    }
  | {
      status: "full" | "partial";
      intersectionStart: string;
      intersectionEnd: string;
      uncoveredBefore: { start: string; end: string } | null;
      uncoveredAfter: { start: string; end: string } | null;
    };

const readySourceStatuses = new Set<ImportSourceStatus>([
  "valid",
  "already_imported",
  "confirmed",
]);

export function compareImportPeriods(
  statePeriod: { start: string; end: string },
  powerPeriod: { start: string; end: string },
): ImportCoverage {
  const stateStart = Date.parse(statePeriod.start);
  const stateEnd = Date.parse(statePeriod.end);
  const powerStart = Date.parse(powerPeriod.start);
  const powerEnd = Date.parse(powerPeriod.end);

  if (
    !Number.isFinite(stateStart) ||
    !Number.isFinite(stateEnd) ||
    !Number.isFinite(powerStart) ||
    !Number.isFinite(powerEnd) ||
    stateEnd < stateStart ||
    powerEnd < powerStart
  ) {
    throw new Error("Os períodos da importação são inválidos.");
  }

  if (powerEnd < stateStart || stateEnd < powerStart) {
    return {
      status: "no_intersection",
      intersectionStart: null,
      intersectionEnd: null,
      uncoveredBefore: null,
      uncoveredAfter: null,
    };
  }

  const intersectionStart = Math.max(stateStart, powerStart);
  const intersectionEnd = Math.min(stateEnd, powerEnd);
  const uncoveredBefore =
    powerStart > stateStart
      ? {
          start: new Date(stateStart).toISOString(),
          end: new Date(Math.min(powerStart, stateEnd)).toISOString(),
        }
      : null;
  const uncoveredAfter =
    powerEnd < stateEnd
      ? {
          start: new Date(Math.max(powerEnd, stateStart)).toISOString(),
          end: new Date(stateEnd).toISOString(),
        }
      : null;

  return {
    status: uncoveredBefore || uncoveredAfter ? "partial" : "full",
    intersectionStart: new Date(intersectionStart).toISOString(),
    intersectionEnd: new Date(intersectionEnd).toISOString(),
    uncoveredBefore,
    uncoveredAfter,
  };
}

export function aggregateImportSessionStatus({
  stateStatus,
  powerStatus,
  coverageStatus,
  confirming = false,
  confirmed = false,
  failed = false,
}: {
  stateStatus: ImportSourceStatus;
  powerStatus: ImportSourceStatus;
  coverageStatus?: ImportCoverage["status"];
  confirming?: boolean;
  confirmed?: boolean;
  failed?: boolean;
}): ImportSessionUiStatus {
  if (confirming) return "confirming";
  if (confirmed) return "confirmed";
  if (failed || coverageStatus === "no_intersection") return "failed";
  if (stateStatus === "validating" || powerStatus === "validating") {
    return "validating";
  }
  if (
    !readySourceStatuses.has(stateStatus) ||
    !readySourceStatuses.has(powerStatus)
  ) {
    return "incomplete";
  }

  return coverageStatus === "partial" ? "ready_with_warning" : "ready";
}

export function missingImportSourceMessage(
  stateStatus: ImportSourceStatus,
  powerStatus: ImportSourceStatus,
) {
  const stateReady = readySourceStatuses.has(stateStatus);
  const powerReady = readySourceStatuses.has(powerStatus);

  if (!stateReady && !powerReady) {
    return "Faltam os arquivos de estado e de potência para concluir esta atualização.";
  }
  if (!stateReady) {
    return "Falta o arquivo de estado para concluir esta atualização.";
  }
  if (!powerReady) {
    return "Falta o arquivo de potência para concluir esta atualização.";
  }

  return null;
}
